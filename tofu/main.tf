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
variable "ssh_public_key_path" { type = string, default = "~/.ssh/id_ed25519.pub" }
variable "libvirt_pool" { type = string, default = "default" }

locals {
  user_data = [
    for i in range(var.node_count) : templatefile("${path.module}/cloud-init.yaml", {
      hostname = "${var.cluster_name}-node-${i}"
      ssh_key  = file(var.ssh_public_key_path)
    })
  ]
}

resource "libvirt_volume" "os_image" {
  name   = "ubuntu-2204-${var.cluster_name}"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
  pool   = var.libvirt_pool
}

resource "libvirt_cloudinit_disk" "common" {
  count     = var.node_count
  name      = "cloud-init-${var.cluster_name}-${count.index}"
  pool      = var.libvirt_pool
  user_data = local.user_data[count.index]
}

resource "libvirt_domain" "k8s_nodes" {
  count  = var.node_count
  name   = "${var.cluster_name}-node-${count.index}"
  memory = var.node_memory
  vcpu   = var.node_vcpu

  disk {
    volume_id = libvirt_volume.os_image.id
  }

  network_interface {
    network_name  = "default"
    wait_for_lease = true
  }

  cloudinit = libvirt_cloudinit_disk.common[count.index].id
}

output "node_ips" {
  value = [for node in libvirt_domain.k8s_nodes : node.network_interface[0].addresses[0]]
}

output "control_plane_ip" {
  value = libvirt_domain.k8s_nodes[0].network_interface[0].addresses[0]
}
