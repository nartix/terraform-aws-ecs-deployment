variable "name" {
  description = "Name prefix for network resources."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "availability_zones" {
  description = "Optional explicit availability zones. When empty, the first az_count available zones are used."
  type        = list(string)
  default     = []
}

variable "az_count" {
  description = "Number of availability zones to use when availability_zones is empty."
  type        = number
  default     = 2
}

variable "public_subnet_cidrs" {
  description = "Optional public subnet CIDRs. Must match the selected AZ count when set."
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "Optional private subnet CIDRs. Must match the selected AZ count when set."
  type        = list(string)
  default     = []
}

variable "enable_nat_gateway" {
  description = "Whether private subnets should route outbound internet traffic through NAT."
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway for all private subnets instead of one per AZ."
  type        = bool
  default     = true
}

variable "app_ports" {
  description = "Application container ports exposed to the edge proxy."
  type        = set(number)
  default     = [8080]
}

variable "route53_resolver_ip" {
  description = "Route 53 Resolver IP reachable from the VPC."
  type        = string
  default     = "169.254.169.253"
}

variable "app_egress_cidr_blocks" {
  description = "CIDR blocks app tasks may reach. Narrow this to DB/cache/internal ranges for production."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "tags" {
  description = "Tags to apply to all supported resources."
  type        = map(string)
  default     = {}
}
