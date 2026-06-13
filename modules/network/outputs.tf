output "vpc_id" {
  description = "VPC ID."
  value       = aws_vpc.this.id
}

output "vpc_cidr_block" {
  description = "VPC CIDR block."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Public subnet IDs."
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "Private subnet IDs."
  value       = aws_subnet.private[*].id
}

output "ecs_instance_security_group_id" {
  description = "Security group ID for ECS container instances."
  value       = aws_security_group.ecs_instances.id
}

output "edge_task_security_group_id" {
  description = "Security group ID for edge proxy tasks."
  value       = aws_security_group.edge_tasks.id
}

output "app_task_security_group_id" {
  description = "Security group ID for app tasks."
  value       = aws_security_group.app_tasks.id
}
