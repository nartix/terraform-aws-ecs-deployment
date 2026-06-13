variable "name" {
  description = "Name prefix for the app ECS resources."
  type        = string
}

variable "app_name" {
  description = "Short app name used in ECS service names and log stream prefixes."
  type        = string
  default     = "app"
}

variable "cluster_id" {
  description = "ECS cluster ID."
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name."
  type        = string
}

variable "capacity_provider_strategy" {
  description = "Capacity provider strategy blocks for the ECS service."
  type = list(object({
    capacity_provider = string
    weight            = number
    base              = number
  }))
  default = []
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for app tasks."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for app tasks."
  type        = list(string)
}

variable "service_discovery_registry_arn" {
  description = "Cloud Map service ARN for automatic app task registration."
  type        = string
}

variable "aws_region" {
  description = "AWS region used by the awslogs driver."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for app logs."
  type        = string
}

variable "app_image" {
  description = "Container image for the application."
  type        = string
}

variable "container_name" {
  description = "Application container name."
  type        = string
  default     = null
  nullable    = true
}

variable "container_port" {
  description = "Application container port."
  type        = number
  default     = 8080
}

variable "cpu" {
  description = "Task CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Task memory in MiB."
  type        = number
  default     = 512
}

variable "desired_count" {
  description = "Desired number of app tasks."
  type        = number
  default     = 2
}

variable "environment" {
  description = "Plain environment variables for the app container."
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Secrets Manager or SSM parameters exposed to the app container."
  type = list(object({
    name       = string
    value_from = string
  }))
  default = []
}

variable "secret_arns" {
  description = "Secret ARNs the task execution role may read for container secrets."
  type        = list(string)
  default     = []
}

variable "task_policy_json" {
  description = "Optional inline policy JSON for the app task role."
  type        = string
  default     = null
}

variable "health_check_path" {
  description = "HTTP health check path inside the app container."
  type        = string
  default     = "/health"
}

variable "health_check_command" {
  description = "Optional full ECS health check command. Defaults to curl against health_check_path."
  type        = list(string)
  default     = null
  nullable    = true
}

variable "enable_container_health_check" {
  description = "Whether to include an ECS container health check."
  type        = bool
  default     = true
}

variable "health_check_interval" {
  description = "Container health check interval in seconds."
  type        = number
  default     = 15
}

variable "health_check_timeout" {
  description = "Container health check timeout in seconds."
  type        = number
  default     = 5
}

variable "health_check_retries" {
  description = "Container health check retries."
  type        = number
  default     = 3
}

variable "health_check_start_period" {
  description = "Container health check start period in seconds."
  type        = number
  default     = 30
}

variable "deployment_minimum_healthy_percent" {
  description = "Minimum healthy percent during deployments."
  type        = number
  default     = 100
}

variable "deployment_maximum_percent" {
  description = "Maximum percent during deployments."
  type        = number
  default     = 200
}

variable "enable_execute_command" {
  description = "Whether to enable ECS Exec for app tasks."
  type        = bool
  default     = false
}

variable "enable_autoscaling" {
  description = "Whether to enable Application Auto Scaling for the app service."
  type        = bool
  default     = true
}

variable "autoscaling_min_capacity" {
  description = "Minimum app task count for autoscaling."
  type        = number
  default     = 2
}

variable "autoscaling_max_capacity" {
  description = "Maximum app task count for autoscaling."
  type        = number
  default     = 10
}

variable "autoscaling_cpu_target" {
  description = "Target average CPU utilization percentage. Set null to disable CPU policy."
  type        = number
  default     = 60
  nullable    = true
}

variable "autoscaling_memory_target" {
  description = "Target average memory utilization percentage. Set null to disable memory policy."
  type        = number
  default     = null
  nullable    = true
}

variable "tags" {
  description = "Tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}
