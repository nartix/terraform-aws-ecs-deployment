variable "name" {
  description = "Name prefix for Cloudflare Tunnel resources."
  type        = string
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID."
  type        = string
}

variable "hostnames" {
  description = "Public hostnames routed through the Cloudflare Tunnel."
  type = list(object({
    hostname = string
    zone_id  = string
  }))
}

variable "tunnel_service" {
  description = "Service URL cloudflared forwards to inside the edge task."
  type        = string
  default     = "http://localhost:8080"
}

variable "secret_name" {
  description = "AWS Secrets Manager secret name for the Cloudflare tunnel token."
  type        = string
  default     = null
}

variable "secret_recovery_window_in_days" {
  description = "Recovery window for deleting the tunnel token secret."
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to AWS resources."
  type        = map(string)
  default     = {}
}
