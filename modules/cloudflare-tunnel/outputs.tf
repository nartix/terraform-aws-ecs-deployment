output "tunnel_id" {
  description = "Cloudflare Tunnel ID."
  value       = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

output "public_hostnames" {
  description = "Public hostnames routed by the tunnel."
  value       = [for item in var.hostnames : item.hostname]
}

output "dns_record_ids" {
  description = "Cloudflare DNS record IDs keyed by hostname."
  value       = { for hostname, record in cloudflare_dns_record.this : hostname => record.id }
}

output "tunnel_token_secret_arn" {
  description = "Secrets Manager ARN containing the Cloudflare tunnel token."
  value       = aws_secretsmanager_secret.tunnel_token.arn
}
