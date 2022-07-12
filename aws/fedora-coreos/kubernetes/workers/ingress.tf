# Target groups of instances for use with load balancers


resource "aws_lb_target_group" "workers-http" {
  name        = "${var.name}-workers-http"
  vpc_id      = var.vpc_id
  target_type = "instance"

  protocol = "TCP"
  port     = var.target_group_http_port

  # HTTP health check for ingress
  health_check {
    protocol = "HTTP"
    port     = var.target_group_health_port
    path     = var.target_group_health_uri_path

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }
}

resource "aws_lb_target_group" "workers-https" {
  name        = "${var.name}-workers-https"
  vpc_id      = var.vpc_id
  target_type = "instance"

  protocol = "TCP"
  port     = var.target_group_http_port

  # HTTP health check for ingress
  health_check {
    protocol = "HTTP"
    port     = var.target_group_health_port
    path     = var.target_group_health_uri_path

    # NLBs required to use same healthy and unhealthy thresholds
    healthy_threshold   = 3
    unhealthy_threshold = 3

    # Interval between health checks required to be 10 or 30
    interval = 10
  }
}

