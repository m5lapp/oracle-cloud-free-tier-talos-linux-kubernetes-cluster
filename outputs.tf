output "nat_gateway_ip" {
  description = "The public IP address associated with the NAT gateway"
  value       = module.network.nat_gateway_ip
}

output "nlb_public_ip" {
  description = "The public IP address of the cluster network load balancer"
  value       = module.network.nlb_public_ip
}

