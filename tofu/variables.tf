variable "cluster_name" {
  description = "Name prefix for libvirt resources"
  type        = string
  default     = "openmoodle-prod"
}

variable "node_count" {
  description = "Number of Kubernetes nodes"
  type        = number
  default     = 3
}

variable "node_memory" {
  description = "Memory per node in MB"
  type        = number
  default     = 16384
}

variable "node_vcpu" {
  description = "vCPUs per node"
  type        = number
  default     = 4
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key for cloud-init injection"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "libvirt_pool" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}
