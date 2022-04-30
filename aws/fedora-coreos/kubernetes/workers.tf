module "workers" {
  source = "./workers"
  name   = var.cluster_name

  # AWS
  vpc_id                       = data.aws_vpc.network.id
  subnet_ids                   = data.aws_subnets.subnets.ids
  security_groups              = [aws_security_group.worker.id]
  worker_count                 = var.worker_count
  instance_type                = var.worker_type
  os_stream                    = var.os_stream
  arch                         = var.arch
  disk_size                    = var.disk_size
  spot_price                   = var.worker_price
  target_groups                = var.worker_target_groups
  target_group_http_port       = var.worker_nlb_target_http_port
  target_group_https_port      = var.worker_nlb_target_https_port
  target_group_health_port     = var.worker_nlb_target_health_port
  target_group_health_uri_path = var.worker_nlb_target_health_uri_path
  instance_profile             = var.instance_profile

  # configuration
  kubeconfig            = module.bootstrap.kubeconfig-kubelet
  ssh_authorized_key    = var.ssh_authorized_key
  service_cidr          = var.service_cidr
  cluster_domain_suffix = var.cluster_domain_suffix
  snippets              = var.worker_snippets
  node_labels           = var.worker_node_labels
  node_tags             = var.additional_node_tags
}

