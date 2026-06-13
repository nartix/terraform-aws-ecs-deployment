variable "name" {
  description = "Name prefix for ECS resources."
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs where ECS container instances should run."
  type        = list(string)
}

variable "container_instance_security_group_id" {
  description = "Security group ID for ECS container instances."
  type        = string
}

variable "ecs_optimized_ami_id" {
  description = "Optional ECS optimized AMI ID. When empty, the latest Amazon Linux 2 ECS optimized x86_64 AMI from SSM is used."
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

variable "enable_container_insights" {
  description = "Whether to enable ECS Container Insights."
  type        = bool
  default     = true
}

variable "enable_on_demand_capacity" {
  description = "Whether to create an On-Demand capacity provider."
  type        = bool
  default     = true
}

variable "on_demand_instance_type" {
  description = "Instance type for the On-Demand Auto Scaling group and launch template default."
  type        = string
  default     = "t3.small"
}

variable "on_demand_min_size" {
  description = "Minimum On-Demand container instances."
  type        = number
  default     = 1
}

variable "on_demand_desired_capacity" {
  description = "Desired On-Demand container instances."
  type        = number
  default     = 1
}

variable "on_demand_max_size" {
  description = "Maximum On-Demand container instances."
  type        = number
  default     = 2
}

variable "enable_spot_capacity" {
  description = "Whether to create a Spot capacity provider."
  type        = bool
  default     = true
}

variable "spot_instance_types" {
  description = "x86_64 instance types for the Spot mixed instances policy."
  type        = list(string)
  default     = ["t3a.small", "t3.small", "t3a.medium"]
}

variable "spot_min_size" {
  description = "Minimum Spot container instances."
  type        = number
  default     = 1
}

variable "spot_desired_capacity" {
  description = "Desired Spot container instances."
  type        = number
  default     = 2
}

variable "spot_max_size" {
  description = "Maximum Spot container instances."
  type        = number
  default     = 6
}

variable "capacity_provider_target_capacity" {
  description = "ECS managed scaling target capacity percentage."
  type        = number
  default     = 80
}

variable "capacity_provider_minimum_scaling_step_size" {
  description = "Minimum scaling step size for ECS managed scaling."
  type        = number
  default     = 1
}

variable "capacity_provider_maximum_scaling_step_size" {
  description = "Maximum scaling step size for ECS managed scaling."
  type        = number
  default     = 4
}

variable "on_demand_strategy_base" {
  description = "Default capacity provider base for On-Demand capacity."
  type        = number
  default     = 1
}

variable "on_demand_strategy_weight" {
  description = "Default capacity provider weight for On-Demand capacity."
  type        = number
  default     = 1
}

variable "spot_strategy_base" {
  description = "Default capacity provider base for Spot capacity."
  type        = number
  default     = 0
}

variable "spot_strategy_weight" {
  description = "Default capacity provider weight for Spot capacity."
  type        = number
  default     = 4
}

variable "tags" {
  description = "Tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}
