variable "name" {
  type        = string
  description = "Unique name for the worker pool"
}

# Azure

variable "location" {
  type        = string
  description = "Must be set to the Azure location of cluster"
}

variable "resource_group_name" {
  type        = string
  description = "Must be set to the resource group name of cluster"
}

variable "subnet_id" {
  type        = string
  description = "Must be set to the `worker_subnet_id` output by cluster"
}

variable "security_group_id" {
  type        = string
  description = "Must be set to the `worker_security_group_id` output by cluster"
}

variable "backend_address_pool_ids" {
  type = object({
    ipv4 = list(string)
    ipv6 = list(string)
  })
  description = "Must be set to the `backend_address_pool_ids` output by cluster"
}

# instances

variable "worker_count" {
  type        = number
  description = "Number of instances"
  default     = 1
}

variable "vm_type" {
  type        = string
  description = "Machine type for instances (see `az vm list-skus --location centralus`)"
  default     = "Standard_D2as_v5"
}

variable "os_image" {
  type        = string
  description = "Channel for a Container Linux derivative (flatcar-stable, flatcar-beta, flatcar-alpha)"
  default     = "flatcar-stable"

  validation {
    condition     = contains(["flatcar-stable", "flatcar-beta", "flatcar-alpha"], var.os_image)
    error_message = "The os_image must be flatcar-stable, flatcar-beta, or flatcar-alpha."
  }
}

variable "disk_type" {
  type        = string
  description = "Type of managed disk"
  default     = "Standard_LRS"
}

variable "disk_size" {
  type        = number
  description = "Size of the managed disk in GB"
  default     = 30
}

variable "ephemeral_disk" {
  type        = bool
  description = "Use ephemeral local disk instead of managed disk (requires vm_type with local storage)"
  default     = false
}

variable "priority" {
  type        = string
  description = "Set priority to Spot to use reduced cost surplus capacity, with the tradeoff that instances can be evicted at any time."
  default     = "Regular"
}

variable "snippets" {
  type        = list(string)
  description = "Container Linux Config snippets"
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

variable "azure_authorized_key" {
  type        = string
  description = "Optionally, pass a dummy RSA key to satisfy Azure validations (then use an ed25519 key set above)"
  default     = ""
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

variable "arch" {
  type        = string
  description = "Container architecture (amd64 or arm64)"
  default     = "amd64"

  validation {
    condition     = var.arch == "amd64" || var.arch == "arm64"
    error_message = "The arch must be amd64 or arm64."
  }
}
