# Workers AutoScaling Group
resource "aws_autoscaling_group" "workers" {
  name = "${var.name}-worker"

  # count
  desired_capacity          = var.worker_count
  min_size                  = var.worker_count
  max_size                  = var.worker_count + 2
  default_cooldown          = 30
  health_check_grace_period = 30

  # network
  vpc_zone_identifier = var.subnet_ids

  # launch template
  # two possible declaration constructs depending on multi-instance or not

  # launch template declaration for single instance type
  dynamic "launch_template" {
    for_each = var.instance_type_list != null ? toset([]) : toset([1])
    content {
      id      = aws_launch_template.worker.id
      version = aws_launch_template.worker.latest_version
    }
  }

  # launch template declaration for multi-instance type
  dynamic "mixed_instances_policy" {
    for_each = var.instance_type_list == null ? toset([]) : toset([1])
    content {
      launch_template {
        launch_template_specification {
          launch_template_id = aws_launch_template.worker.id
          version = aws_launch_template.worker.latest_version
        }
      }
    }
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
  image_id           = var.arch == "arm64" ? data.aws_ami.fedora-coreos-arm[0].image_id : data.aws_ami.fedora-coreos.image_id
  instance_type      = var.instance_type_list == null ? var.instance_type : null

  dynamic "instance_requirements" {
    for_each = var.instance_type_list == null ? toset([]) : toset([1])
    content {
      vcpu_count {
        min = 2
      }
      memory_mib {
        min = 4096
      }

      allowed_instance_types = var.instance_type_list
    }
  }

  user_data = sensitive(base64encode(local.worker_ignition_rendered_b64zipped))

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
    # Do not ignore image_id - when we do a daily `terraform apply` we want the
    # image_id to update as FCOS AMIs are updated.
    # ignore_changes        = [image_id]
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

locals {
  worker_ignition_rendered_b64zipped = jsonencode(
    {
      "ignition": {
        "version": "3.4.0",
        "config": {
          "replace": {
              "compression": "gzip"
              "source": "data:;base64,${base64gzip(data.ct_config.worker-ignition.rendered)}"
            }
        }
      }
    }
  )
}

# Worker Ignition config
data "ct_config" "worker-ignition" {
  content  = templatefile("${path.module}/butane/worker.yaml", {
    kubeconfig             = indent(10, var.kubeconfig)
    ssh_authorized_key     = var.ssh_authorized_key
    cluster_dns_service_ip = cidrhost(var.service_cidr, 10)
    cluster_domain_suffix  = var.cluster_domain_suffix
    node_labels            = join(",", var.node_labels)
    node_taints            = join(",", var.node_taints)
  })
  strict   = true
  snippets = var.snippets
}