output "service_name" {
  description = "App ECS service name."
  value       = aws_ecs_service.this.name
}

output "service_arn" {
  description = "App ECS service ARN."
  value       = aws_ecs_service.this.id
}

output "task_definition_arn" {
  description = "App task definition ARN."
  value       = aws_ecs_task_definition.this.arn
}

output "task_role_arn" {
  description = "App task role ARN."
  value       = aws_iam_role.task.arn
}

output "execution_role_arn" {
  description = "App task execution role ARN."
  value       = aws_iam_role.execution.arn
}
