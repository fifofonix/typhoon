variable "name" {
  type        = string
  description = "Unique name for the worker pool"
}

# AWS

variable "vpc_id" {
  type        = string
  description = "Must be set to `vpc_id` output by cluster"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Must be set to `subnet_ids` output by cluster"
}

variable "security_groups" {
  type        = list(string)
  description = "Must be set to `worker_security_groups` output by cluster"
}

variable "privacy_status" {
  type        = string
  # Cluster default for typhoon project is public which cascades to default workers ASG.
  # However, if additional worker ASGs are created we make them private by default.
  default     = "private"
  description = "Whether workers are publicly facing at all."
  validation {
    condition     = contains(["public", "private"], var.privacy_status)
    error_message = "The privacy_status option must be either 'private' or 'public'."
  }
}

variable "instance_profile" {
  type        = string
  description = "AWS instance profile (optional)."
  default     = null
}

# instances

variable "worker_count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
  default     = "t3.small"
}

variable "instance_type_list" {
  type        = list(string)
  description = "EC2 instance type list"
  default     = null
}

variable "os_stream" {
  type        = string
  description = "Fedora CoreOS image stream for instances (e.g. stable, testing, next)"
  default     = "stable"

  validation {
    condition     = contains(["stable", "testing", "next"], var.os_stream)
    error_message = "The os_stream must be stable, testing, or next."
  }
}

variable "disk_size" {
  type        = number
  description = "Size of the EBS volume in GB"
  default     = 30
}

variable "disk_type" {
  type        = string
  description = "Type of the EBS volume (e.g. standard, gp2, gp3, io1)"
  default     = "gp3"
}

variable "disk_iops" {
  type        = number
  description = "IOPS of the EBS volume (required for io1)"
  default     = 0
}

variable "spot_price" {
  type        = number
  description = "Spot price in USD for worker instances or 0 to use on-demand instances"
  default     = 0
}

variable "cpu_credits" {
  type        = string
  description = "CPU burst credits mode (if applicable)"
  default     = null
}

variable "target_groups" {
  type        = list(string)
  description = "Additional target group ARNs to which instances should be added"
  default     = []
}

variable "target_group_http_port" {
  type        = number
  default     = 80
  description = "Target group http port."
}

variable "target_group_https_port" {
  type        = number
  default     = 443
  description = "Target group https port."
}

variable "target_group_health_port" {
  type        = number
  default     = 10254
  description = "Target group's instance health check port."
}

variable "target_group_health_uri_path" {
  type        = string
  default     = "/healthz"
  description = "Target group's instance health check port."
}

variable "snippets" {
  type        = list(string)
  description = "Butane snippets"
  default     = []
}

# configuration

variable "kubeconfig" {
  type        = string
  description = "Must be set to `kubeconfig` output by cluster"
}

variable "ssh_authorized_key" {
  type        = string
  description = "SSH public key for user 'core'"
}

variable "service_cidr" {
  type        = string
  description = <<EOD
CIDR IPv4 range to assign Kubernetes services.
The 1st IP will be reserved for kube_apiserver, the 10th IP will be reserved for coredns.
EOD
  default     = "10.3.0.0/16"
}

variable "node_labels" {
  type        = list(string)
  description = "List of initial node labels"
  default     = []
}

variable "node_taints" {
  type        = list(string)
  description = "List of initial node taints"
  default     = []
}

variable "node_tags" {
  type        = map(any)
  description = "Map of additional node tags"
  default     = {}
}

# advanced

variable "arch" {
  type        = string
  description = "Container architecture (amd64 or arm64)"
  default     = "amd64"
  validation {
    condition     = contains(["amd64", "arm64"], var.arch)
    error_message = "The arch must be amd64 or arm64."
  }
}
