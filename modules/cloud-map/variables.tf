variable "name" {
  description = "Name prefix for Cloud Map resources."
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the private DNS namespace."
  type        = string
}

variable "namespace_name" {
  description = "Private DNS namespace for ECS service discovery."
  type        = string
  default     = "ecs.internal"
}

variable "app_names" {
  description = "Cloud Map service names for applications."
  type        = set(string)
  default     = ["app"]
}

variable "dns_ttl" {
  description = "Cloud Map DNS record TTL."
  type        = number
  default     = 10
}

variable "tags" {
  description = "Tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}
