variable "ssh_key_path" {
  description = "SSH private key used by infrastructure modules"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "control_plane_ip" {
  description = "Address of the Kubernetes control plane"
  type        = string
  default     = "192.168.122.10"
}