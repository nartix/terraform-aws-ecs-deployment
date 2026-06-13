resource "aws_service_discovery_private_dns_namespace" "this" {
  name        = var.namespace_name
  description = "Private ECS service discovery namespace for ${var.name}"
  vpc         = var.vpc_id

  tags = var.tags
}

resource "aws_service_discovery_service" "apps" {
  for_each = var.app_names

  name = each.value

  dns_config {
    namespace_id   = aws_service_discovery_private_dns_namespace.this.id
    routing_policy = "MULTIVALUE"

    dns_records {
      type = "A"
      ttl  = var.dns_ttl
    }
  }

  # health_check_custom_config {}

  tags = var.tags
}
