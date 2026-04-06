output "nlb_backend_set_name_kubectl" {
  description = "The name of the network load balancer backend set for kubectl"
  value       = oci_network_load_balancer_backend_set.backend_kubectl.name
}

output "nlb_backend_set_name_talosctl" {
  description = "The name of the network load balancer backend set for talosctl"
  value       = oci_network_load_balancer_backend_set.backend_talosctl.name
}

output "nlb_id" {
  description = "The resource ID of the cluster network load balancer"
  value       = oci_network_load_balancer_network_load_balancer.cluster_nlb.id
}

output "nlb_public_ip" {
  description = "The public IP address of the cluster network load balancer"
  value       = oci_network_load_balancer_network_load_balancer.cluster_nlb.ip_addresses[0].ip_address
}

output "subnet_private_id" {
  description = "The ID of the private subnet within the rfc1918_cidr_block"
  value       = oci_core_subnet.private_subnet.id
}

output "subnet_private_nsgs" {
  description = "The Network Security Groups for public subnet members"
  value = [
    oci_core_security_list.allow_all_egress.id,
    oci_core_security_list.subnet_private_security_list.id,
  ]
}

output "subnet_public_nsgs" {
  description = "The Network Security Groups for public subnet members"
  value       = [oci_core_security_list.subnet_public_security_list.id]
}

