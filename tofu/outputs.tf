output "node_ips" {
  value = [for node in libvirt_domain.k8s_nodes : node.network_interface[0].addresses[0]]
}