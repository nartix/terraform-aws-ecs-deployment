locals {
  secret_name = var.secret_name == null ? "/ecs/${var.name}/cloudflare-tunnel-token" : var.secret_name

  hostnames_by_name = {
    for item in var.hostnames : item.hostname => item
  }
}

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  account_id = var.cloudflare_account_id
  name       = "${var.name}-edge"
  config_src = "cloudflare"
}

data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id
}

resource "cloudflare_dns_record" "this" {
  for_each = local.hostnames_by_name

  zone_id = each.value.zone_id
  name    = each.value.hostname
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this.id}.cfargotunnel.com"
  type    = "CNAME"
  ttl     = 1
  proxied = true
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this.id

  config = {
    ingress = concat(
      [
        for item in var.hostnames : {
          hostname = item.hostname
          service  = var.tunnel_service
        }
      ],
      [
        {
          hostname = null
          service  = "http_status:404"
        }
      ]
    )
  }
}

resource "aws_secretsmanager_secret" "tunnel_token" {
  name                    = local.secret_name
  recovery_window_in_days = var.secret_recovery_window_in_days

  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "tunnel_token" {
  secret_id     = aws_secretsmanager_secret.tunnel_token.id
  secret_string = data.cloudflare_zero_trust_tunnel_cloudflared_token.this.token
}
