# Workers AutoScaling Group
resource "aws_autoscaling_group" "workers" {
  name = "${var.name}-worker ${aws_launch_template.worker.name}"

  # count
  desired_capacity          = var.worker_count
  min_size                  = var.worker_count
  max_size                  = var.worker_count + 2
  default_cooldown          = 30
  health_check_grace_period = 30

  # network
  vpc_zone_identifier = var.subnet_ids

  # template
  launch_template {
    id      = aws_launch_template.worker.id
    version = aws_launch_template.worker.latest_version
  }

  # target groups to which instances should be added
  target_group_arns = flatten([
    aws_lb_target_group.workers-http.id,
    aws_lb_target_group.workers-https.id,
    var.target_groups,
  ])

  instance_refresh {
    strategy = "Rolling"
    preferences {
      instance_warmup        = 120
      min_healthy_percentage = 90
    }
  }

  lifecycle {
    # override the default destroy and replace update behavior
    create_before_destroy = true
  }

  # Waiting for instance creation delays adding the ASG to state. If instances
  # can't be created (e.g. spot price too low), the ASG will be orphaned.
  # Orphaned ASGs escape cleanup, can't be updated, and keep bidding if spot is
  # used. Disable wait to avoid issues and align with other clouds.
  wait_for_capacity_timeout = "0"

  tag {
    key                 = "Name"
    value               = "${var.name}-worker"
    propagate_at_launch = true
  }

}

data "aws_iam_instance_profile" "controller_profile" {
  count = var.instance_profile == null ? 0: 1
  name  = var.instance_profile
}

# Worker template
resource "aws_launch_template" "worker" {
  image_id          = var.arch == "arm64" ? data.aws_ami.fedora-coreos-arm[0].image_id : data.aws_ami.fedora-coreos.image_id
  instance_type     = var.instance_type

  user_data = sensitive(base64gzip(data.ct_config.worker-ignition.rendered))

  iam_instance_profile {
    name =  var.instance_profile == null ? "" : data.aws_iam_instance_profile.controller_profile[0].name
  }

  monitoring {
    enabled = false
  }

  # storage
  ebs_optimized = true

  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = var.disk_type
      volume_size           = var.disk_size
      iops                  = var.disk_iops
      encrypted             = true
      delete_on_termination = true
    }
  }
  # network
  vpc_security_group_ids = var.security_groups

  # metadata
  metadata_options {
    http_tokens = "optional"
  }

  # spot
  dynamic "instance_market_options" {
    for_each = var.spot_price == 0 ? toset([]) : toset([1])
    content {
      market_type = "spot"
      spot_options {
        instance_interruption_behavior = "terminate"
        max_price                      = var.spot_price
        spot_instance_type             = "one-time"
      }
    }
  }

  lifecycle {
    // Override the default destroy and replace update behavior
    create_before_destroy = true
    ignore_changes        = [image_id]
  }

  tag_specifications {
    resource_type = "instance"

    tags = merge(
      data.aws_default_tags.current.tags,
      var.node_tags,
    { Name = "${var.name}-worker" })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(
      data.aws_default_tags.current.tags,
      var.node_tags,
    { Name = "${var.name}-worker" })
  }
}

data "aws_default_tags" "current" {}

# Worker Ignition config
data "ct_config" "worker-ignition" {
  content  = data.template_file.worker-config.rendered
  strict   = true
  snippets = var.snippets
}

# Worker Fedora CoreOS config
data "template_file" "worker-config" {
  template = file("${path.module}/butane/worker.yaml")

  vars = {
    kubeconfig             = indent(10, var.kubeconfig)
    ssh_authorized_key     = var.ssh_authorized_key
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
    node_labels            = join(",", var.node_labels)
    node_taints            = join(",", var.node_taints)
  }
}
