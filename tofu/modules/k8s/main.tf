variable "control_plane_ip" { type = string }
variable "ssh_key_path" { type = string }

resource "null_resource" "k8s_control_plane" {
  connection {
    type        = "ssh"
    host        = var.control_plane_ip
    user        = "ubuntu"
    private_key = file(var.ssh_key_path)
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt-get update",
      "sudo apt-get install -y containerd kubelet kubeadm kubectl",
    ]
  }
}