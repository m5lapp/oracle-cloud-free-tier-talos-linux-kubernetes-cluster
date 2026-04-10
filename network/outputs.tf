output "nlb_backend_set_name_kubectl" {
  description = "The name of the network load balancer backend set for kubectl"
  value       = oci_network_load_balancer_backend_set.backend_kubectl.name
}

output "nlb_backend_set_name_talosctl" {
  description = "The name of the network load balancer backend set for talosctl"
  value       = oci_network_load_balancer_backend_set.backend_talosctl.name
}

output "nlb_backend_sets_additional" {
  description = "Additional network load balancer backend sets for ingress"
  value = tomap({
    for key, value in oci_network_load_balancer_backend_set.backend_additional :
    key => tomap({
      backend_port     = value.health_checker[0].port
      backend_set_name = value.name
    })
  })
}

output "nlb_id" {
  description = "The resource ID of the cluster network load balancer"
  value       = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
}

output "nlb_public_ip" {
  description = "The public IP address of the cluster network load balancer"
  value       = oci_network_load_balancer_network_load_balancer.cluster_nlb.ip_addresses[0].ip_address
}

output "nsg_control_plane_id" {
  description = "The Network Security Group for cluster control plane nodes"
  value       = oci_core_network_security_group.nsg_control_plane.id
}

output "nsg_worker_id" {
  description = "The Network Security Group for cluster worker nodes"
  value       = oci_core_network_security_group.nsg_worker.id
}

output "subnet_private_id" {
  description = "The ID of the private subnet within the rfc1918_cidr_block"
  value       = oci_core_subnet.private_subnet.id
}

