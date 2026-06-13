variable "name" {
  description = "Name prefix for edge proxy ECS resources."
  type        = string
}

variable "cluster_id" {
  description = "ECS cluster ID."
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
  description = "Private subnet IDs for edge tasks."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs for edge tasks."
  type        = list(string)
}

variable "aws_region" {
  description = "AWS region used by the awslogs driver."
  type        = string
}

variable "log_group_name" {
  description = "CloudWatch log group name for edge logs."
  type        = string
}

variable "haproxy_image" {
  description = "HAProxy image containing the DNS-discovery config template."
  type        = string
}

variable "cloudflared_image" {
  description = "cloudflared container image."
  type        = string
  default     = "cloudflare/cloudflared:latest"
}

variable "cloudflare_tunnel_token_secret_arn" {
  description = "Secrets Manager secret ARN containing the Cloudflare tunnel token."
  type        = string
}

variable "apps" {
  description = "HAProxy backend definitions keyed by app name."
  type = map(object({
    dns_name          = string
    port              = number
    backend_slots     = number
    health_check_path = string
    hostnames         = list(string)
  }))
}

variable "haproxy_port" {
  description = "HAProxy frontend port inside the edge task."
  type        = number
  default     = 8080
}

variable "haproxy_backend_slots" {
  description = "Default maximum DNS-discovered backend slots for HAProxy server-template."
  type        = number
  default     = 20

  validation {
    condition     = var.haproxy_backend_slots > 0 && floor(var.haproxy_backend_slots) == var.haproxy_backend_slots
    error_message = "haproxy_backend_slots must be a positive whole number."
  }
}

variable "route53_resolver_ip" {
  description = "Route 53 Resolver IP reachable from the VPC."
  type        = string
  default     = "169.254.169.253"
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
  description = "Desired number of edge proxy tasks."
  type        = number
  default     = 2
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
  description = "Whether to enable ECS Exec for edge tasks."
  type        = bool
  default     = false
}

variable "task_policy_json" {
  description = "Optional inline policy JSON for the edge task role."
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}
