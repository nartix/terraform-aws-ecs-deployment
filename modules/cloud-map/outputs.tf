output "namespace_id" {
  description = "Cloud Map private DNS namespace ID."
  value       = aws_service_discovery_private_dns_namespace.this.id
}

output "namespace_name" {
  description = "Cloud Map private DNS namespace name."
  value       = aws_service_discovery_private_dns_namespace.this.name
}

output "app_service_arns" {
  description = "Cloud Map service ARNs keyed by app name."
  value       = { for name, service in aws_service_discovery_service.apps : name => service.arn }
}

output "app_dns_names" {
  description = "DNS names HAProxy resolves for app tasks, keyed by app name."
  value = {
    for name, service in aws_service_discovery_service.apps :
    name => "${service.name}.${aws_service_discovery_private_dns_namespace.this.name}"
  }
}
