output "public_hostnames" {
  description = "Public hostnames routed through Cloudflare Tunnel."
  value       = module.cloudflare_tunnel.public_hostnames
}

output "cloudflare_tunnel_id" {
  description = "Cloudflare Tunnel ID."
  value       = module.cloudflare_tunnel.tunnel_id
}

output "cloudflare_tunnel_token_secret_arn" {
  description = "Secrets Manager ARN containing the Cloudflare tunnel token."
  value       = module.cloudflare_tunnel.tunnel_token_secret_arn
}

output "cloudflare_dns_record_ids" {
  description = "Cloudflare DNS record IDs keyed by hostname."
  value       = module.cloudflare_tunnel.dns_record_ids
}

output "ecs_cluster_name" {
  description = "ECS cluster name."
  value       = module.ecs_cluster.cluster_name
}

output "capacity_provider_names" {
  description = "Capacity providers attached to the ECS cluster."
  value       = module.ecs_cluster.capacity_provider_names
}

output "app_dns_names" {
  description = "Private Cloud Map DNS names for app tasks."
  value       = module.cloud_map.app_dns_names
}

output "app_service_names" {
  description = "App ECS service names keyed by app name."
  value       = { for app_name, service in module.app_service : app_name => service.service_name }
}

output "edge_service_name" {
  description = "Edge ECS service name."
  value       = module.edge_proxy.service_name
}

output "vpc_id" {
  description = "VPC ID."
  value       = module.network.vpc_id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = module.network.private_subnet_ids
}

output "security_group_ids" {
  description = "Security group IDs for ECS instances, edge tasks, and app tasks."
  value = {
    ecs_instances = module.network.ecs_instance_security_group_id
    edge_tasks    = module.network.edge_task_security_group_id
    app_tasks     = module.network.app_task_security_group_id
  }
}
