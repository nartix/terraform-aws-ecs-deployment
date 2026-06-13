output "cluster_id" {
  description = "ECS cluster ID."
  value       = aws_ecs_cluster.this.id
}

output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ECS cluster ARN."
  value       = aws_ecs_cluster.this.arn
}

output "on_demand_capacity_provider_name" {
  description = "On-Demand capacity provider name, when enabled."
  value       = var.enable_on_demand_capacity ? aws_ecs_capacity_provider.on_demand[0].name : null
}

output "spot_capacity_provider_name" {
  description = "Spot capacity provider name, when enabled."
  value       = var.enable_spot_capacity ? aws_ecs_capacity_provider.spot[0].name : null
}

output "capacity_provider_names" {
  description = "Capacity provider names attached to the cluster."
  value       = local.capacity_provider_names
}

output "ecs_instance_role_arn" {
  description = "IAM role ARN used by ECS container instances."
  value       = aws_iam_role.ecs_instance.arn
}
