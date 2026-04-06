output "nlb_public_ip" {
  description = "The public IP address of the cluster network load balancer"
  value       = module.network.nlb_public_ip
}

