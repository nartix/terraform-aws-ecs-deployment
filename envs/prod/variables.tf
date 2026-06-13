variable "name" {
  description = "Name prefix for all resources."
  type        = string
  default     = "edgeforge"
}

variable "aws_region" {
  description = "AWS region for the ECS stack."
  type        = string
  default     = "us-east-2"
}

variable "tags" {
  description = "Additional tags applied to supported resources."
  type        = map(string)
  default     = {}
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.80.0.0/16"
}

variable "availability_zones" {
  description = "Optional explicit availability zones."
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Number of availability zones to use when availability_zones is empty."
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "Optional public subnet CIDRs."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "Optional private subnet CIDRs."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Whether private subnets should have outbound internet through NAT."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway instead of one per AZ."
  type        = bool
  default     = true
}

variable "route53_resolver_ip" {
  description = "Route 53 Resolver IP reachable from the VPC."
  type        = string
  default     = "169.254.169.253"
}

variable "app_egress_cidr_blocks" {
  description = "CIDR blocks app tasks may reach. Narrow this to internal dependency ranges when known."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "enable_container_insights" {
  description = "Whether to enable ECS Container Insights."
  type        = bool
  default     = true
}

variable "ecs_optimized_ami_id" {
  description = "Optional ECS optimized AMI ID override."
  type        = string
  default     = ""
}

variable "ecs_optimized_ami_ssm_parameter" {
  description = "SSM parameter for the ECS optimized AMI ID."
  type        = string
  default     = "/aws/service/ecs/optimized-ami/amazon-linux-2/recommended/image_id"
}

variable "ssh_key_name" {
  description = "Optional EC2 key pair name for break-glass SSH access."
  type        = string
  default     = null
}

variable "enable_on_demand_capacity" {
  description = "Whether to create an On-Demand ECS capacity provider."
  type        = bool
  default     = true
}

variable "on_demand_instance_type" {
  description = "Instance type for On-Demand ECS capacity."
  type        = string
  default     = "t3.small"
}

variable "on_demand_min_size" {
  description = "Minimum On-Demand ECS container instances."
  type        = number
  default     = 1
}

variable "on_demand_desired_capacity" {
  description = "Desired On-Demand ECS container instances."
  type        = number
  default     = 1
}

variable "on_demand_max_size" {
  description = "Maximum On-Demand ECS container instances."
  type        = number
  default     = 2
}

variable "enable_spot_capacity" {
  description = "Whether to create a Spot ECS capacity provider."
  type        = bool
  default     = true
}

variable "spot_instance_types" {
  description = "x86_64 instance types for the Spot mixed instances policy."
  type        = list(string)
  default     = ["t3a.small", "t3.small", "t3a.medium"]
}

variable "spot_min_size" {
  description = "Minimum Spot ECS container instances."
  type        = number
  default     = 1
}

variable "spot_desired_capacity" {
  description = "Desired Spot ECS container instances."
  type        = number
  default     = 2
}

variable "spot_max_size" {
  description = "Maximum Spot ECS container instances."
  type        = number
  default     = 6
}

variable "capacity_provider_target_capacity" {
  description = "ECS managed scaling target capacity percentage."
  type        = number
  default     = 80
}

variable "on_demand_service_base" {
  description = "App/edge service capacity provider base for On-Demand."
  type        = number
  default     = 1
}

variable "on_demand_service_weight" {
  description = "App/edge service capacity provider weight for On-Demand."
  type        = number
  default     = 1
}

variable "spot_service_base" {
  description = "App/edge service capacity provider base for Spot when On-Demand is disabled."
  type        = number
  default     = 0
}

variable "spot_service_weight" {
  description = "App/edge service capacity provider weight for Spot."
  type        = number
  default     = 4
}

variable "cloud_map_namespace" {
  description = "Private DNS namespace for ECS service discovery."
  type        = string
  default     = "ecs.internal"
}

variable "cloud_map_dns_ttl" {
  description = "Cloud Map DNS TTL in seconds."
  type        = number
  default     = 10
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days."
  type        = number
  default     = 30
}

variable "log_kms_key_id" {
  description = "Optional KMS key ID or ARN for log group encryption."
  type        = string
  default     = null
}

variable "apps" {
  description = "Applications hosted behind Edgeforge, keyed by short app name."
  type = map(object({
    image                         = string
    port                          = optional(number, 8080)
    container_name                = optional(string)
    cpu                           = optional(number, 256)
    memory                        = optional(number, 512)
    desired_count                 = optional(number, 2)
    backend_slots                 = optional(number)
    environment                   = optional(map(string), {})
    secrets                       = optional(list(object({ name = string, value_from = string })), [])
    secret_arns                   = optional(list(string), [])
    task_policy_json              = optional(string)
    health_check_path             = optional(string, "/health")
    health_check_command          = optional(list(string))
    enable_container_health_check = optional(bool, true)
    enable_autoscaling            = optional(bool, true)
    autoscaling_min_capacity      = optional(number, 2)
    autoscaling_max_capacity      = optional(number, 10)
    autoscaling_cpu_target        = optional(number, 60)
    autoscaling_memory_target     = optional(number)

    hostnames = list(object({
      hostname = string
      zone_id  = string
    }))
  }))

  validation {
    condition     = length(var.apps) > 0
    error_message = "At least one app must be configured."
  }

  validation {
    condition     = alltrue([for app_name, app in var.apps : can(regex("^[a-z][a-z0-9]*$", app_name))])
    error_message = "App names must start with a lowercase letter and contain only lowercase letters and numbers."
  }

  validation {
    condition     = alltrue([for app_name, app in var.apps : length(app.hostnames) > 0])
    error_message = "Every app must define at least one hostname."
  }

  validation {
    condition     = alltrue([for app_name, app in var.apps : app.port > 0 && app.port <= 65535])
    error_message = "Every app port must be between 1 and 65535."
  }

  validation {
    condition = alltrue([
      for app_name, app in var.apps :
      app.backend_slots == null ? true : app.backend_slots > 0 && floor(app.backend_slots) == app.backend_slots
    ])
    error_message = "App backend_slots must be a positive whole number when provided."
  }

  validation {
    condition     = length(flatten([for app_name, app in var.apps : [for hostname in app.hostnames : hostname.hostname]])) == length(distinct(flatten([for app_name, app in var.apps : [for hostname in app.hostnames : hostname.hostname]])))
    error_message = "Hostnames must be unique across all apps."
  }
}

variable "haproxy_image" {
  description = "HAProxy image to run in the edge proxy task."
  type        = string
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

variable "cloudflared_image" {
  description = "cloudflared image to run in the edge proxy task."
  type        = string
  default     = "cloudflare/cloudflared:latest"
}

variable "edge_cpu" {
  description = "Edge task CPU units."
  type        = number
  default     = 256
}

variable "edge_memory" {
  description = "Edge task memory in MiB."
  type        = number
  default     = 512
}

variable "edge_desired_count" {
  description = "Desired edge proxy task count."
  type        = number
  default     = 1
}

variable "edge_port" {
  description = "HAProxy frontend port inside the edge task."
  type        = number
  default     = 8080
}

variable "edge_task_policy_json" {
  description = "Optional inline policy JSON for the edge task role."
  type        = string
  default     = null
}

variable "enable_execute_command" {
  description = "Whether to enable ECS Exec for app and edge tasks."
  type        = bool
  default     = false
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "cloudflare_tunnel_token_secret_name" {
  description = "Optional Secrets Manager name for the Cloudflare tunnel token."
  type        = string
  default     = null
}
