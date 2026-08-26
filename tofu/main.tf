terraform {
  required_version = ">= 1.6.0"
  required_providers {
    libvirt = { source = "dmacvicar/libvirt", version = "~> 0.7.0" }
    random  = { source = "hashicorp/random", version = "~> 3.5.0" }
  }
}

variable "cluster_name" { type = string, default = "openmoodle-prod" }
variable "node_count" { type = number, default = 3 }
variable "node_memory" { type = number, default = 16384 }
variable "node_vcpu" { type = number, default = 4 }
variable "ssh_public_key_path" { type = string, default = "~/.ssh/id_ed25519.pub" }
variable "libvirt_pool" { type = string, default = "default" }
variable "libvirt_network" { type = string, default = "default" }
variable "cluster_ip_base" { type = string, default = "192.168.122" }
variable "pod_cidr" { type = string, default = "10.244.0.0/16" }
variable "join_token" { type = string, default = "" }
variable "kubernetes_version" { type = string, default = "1.30" }

resource "random_password" "join_token" {
  length  = 22
  upper   = false
  lower   = true
  numeric = true
  special = false
}

locals {
  cp_ip = "${var.cluster_ip_base}.10"
  effective_join_token = var.join_token != "" ? var.join_token : format("%s.%s", substr(random_password.join_token.result, 0, 6), substr(random_password.join_token.result, 6, 16))
  user_data = [
    for i in range(var.node_count) : templatefile("${path.module}/cloud-init.yaml", {
      hostname       = "${var.cluster_name}-node-${i}"
      ssh_key        = file(var.ssh_public_key_path)
      role           = i == 0 ? "control-plane" : "worker"
      cp_ip          = local.cp_ip
      node_ip        = "${var.cluster_ip_base}.${10 + i}"
      pod_cidr       = var.pod_cidr
      kubernetes_version = var.kubernetes_version
      join_token     = local.effective_join_token
    })
  ]
}

resource "libvirt_volume" "os_image" {
  count  = var.node_count
  name   = "ubuntu-2204-${var.cluster_name}-${count.index}"
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
    volume_id = libvirt_volume.os_image[count.index].id
  }

  network_interface {
    network_name  = var.libvirt_network
    addresses     = ["${var.cluster_ip_base}.${10 + count.index}"]
    wait_for_lease = true
  }

  cloudinit = libvirt_cloudinit_disk.common[count.index].id
}

output "node_ips" {
  value = [for node in libvirt_domain.k8s_nodes : node.network_interface[0].addresses[0]]
}

output "control_plane_ip" {
  value = local.cp_ip
}
