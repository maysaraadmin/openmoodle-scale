terraform {
  required_version = ">= 1.6.0"
  required_providers {
    libvirt = { source = "dmacvicar/libvirt", version = "~> 0.7.0" }
  }
}

variable "cluster_name" { type = string, default = "openmoodle-prod" }
variable "node_count" { type = number, default = 3 }
variable "node_memory" { type = number, default = 16384 }
variable "node_vcpu" { type = number, default = 4 }

resource "libvirt_volume" "os_image" {
  name   = "ubuntu-2204-${var.cluster_name}"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
  pool   = "default"
}

resource "libvirt_domain" "k8s_nodes" {
  count  = var.node_count
  name   = "${var.cluster_name}-node-${count.index}"
  memory = var.node_memory
  vcpu   = var.node_vcpu
  disk { volume_id = libvirt_volume.os_image.id }
  network_interface { network_name = "default", wait_for_lease = true }
}