locals {
  common_tags = merge({
    Project   = var.name
    ManagedBy = "terraform"
  }, var.tags)

  service_capacity_provider_strategy = concat(
    var.enable_on_demand_capacity ? [
      {
        capacity_provider = module.ecs_cluster.on_demand_capacity_provider_name
        base              = var.on_demand_service_base
        weight            = var.on_demand_service_weight
      }
    ] : [],
    var.enable_spot_capacity ? [
      {
        capacity_provider = module.ecs_cluster.spot_capacity_provider_name
        base              = var.enable_on_demand_capacity ? 0 : var.spot_service_base
        weight            = var.spot_service_weight
      }
    ] : []
  )

  app_ports = toset([
    for app in values(var.apps) : app.port
  ])

  public_hostnames = flatten([
    for app_name, app in var.apps : [
      for hostname in app.hostnames : {
        app_name = app_name
        hostname = hostname.hostname
        zone_id  = hostname.zone_id
      }
    ]
  ])

  haproxy_apps = {
    for app_name, app in var.apps : app_name => {
      dns_name          = module.cloud_map.app_dns_names[app_name]
      port              = app.port
      backend_slots     = coalesce(app.backend_slots, var.haproxy_backend_slots)
      health_check_path = app.health_check_path
      hostnames         = [for hostname in app.hostnames : hostname.hostname]
    }
  }
}

module "network" {
  source = "../../modules/network"

  name                   = var.name
  vpc_cidr               = var.vpc_cidr
  availability_zones     = var.availability_zones
  az_count               = var.az_count
  public_subnet_cidrs    = var.public_subnet_cidrs
  private_subnet_cidrs   = var.private_subnet_cidrs
  enable_nat_gateway     = var.enable_nat_gateway
  single_nat_gateway     = var.single_nat_gateway
  app_ports              = local.app_ports
  route53_resolver_ip    = var.route53_resolver_ip
  app_egress_cidr_blocks = var.app_egress_cidr_blocks
  tags                   = local.common_tags
}

module "observability" {
  source = "../../modules/observability"

  name               = var.name
  log_retention_days = var.log_retention_days
  kms_key_id         = var.log_kms_key_id
  tags               = local.common_tags
}

module "ecs_cluster" {
  source = "../../modules/ecs-cluster"

  name                                 = var.name
  private_subnet_ids                   = module.network.private_subnet_ids
  container_instance_security_group_id = module.network.ecs_instance_security_group_id
  ecs_optimized_ami_id                 = var.ecs_optimized_ami_id
  ecs_optimized_ami_ssm_parameter      = var.ecs_optimized_ami_ssm_parameter
  ssh_key_name                         = var.ssh_key_name
  enable_container_insights            = var.enable_container_insights
  enable_on_demand_capacity            = var.enable_on_demand_capacity
  on_demand_instance_type              = var.on_demand_instance_type
  on_demand_min_size                   = var.on_demand_min_size
  on_demand_desired_capacity           = var.on_demand_desired_capacity
  on_demand_max_size                   = var.on_demand_max_size
  enable_spot_capacity                 = var.enable_spot_capacity
  spot_instance_types                  = var.spot_instance_types
  spot_min_size                        = var.spot_min_size
  spot_desired_capacity                = var.spot_desired_capacity
  spot_max_size                        = var.spot_max_size
  capacity_provider_target_capacity    = var.capacity_provider_target_capacity
  on_demand_strategy_base              = var.on_demand_service_base
  on_demand_strategy_weight            = var.on_demand_service_weight
  spot_strategy_base                   = var.spot_service_base
  spot_strategy_weight                 = var.spot_service_weight
  tags                                 = local.common_tags
}

module "cloud_map" {
  source = "../../modules/cloud-map"

  name           = var.name
  vpc_id         = module.network.vpc_id
  namespace_name = var.cloud_map_namespace
  app_names      = toset(keys(var.apps))
  dns_ttl        = var.cloud_map_dns_ttl
  tags           = local.common_tags
}

module "cloudflare_tunnel" {
  source = "../../modules/cloudflare-tunnel"

  name                  = var.name
  cloudflare_account_id = var.cloudflare_account_id
  hostnames = [
    for item in local.public_hostnames : {
      hostname = item.hostname
      zone_id  = item.zone_id
    }
  ]
  tunnel_service                 = "http://localhost:${var.edge_port}"
  secret_name                    = var.cloudflare_tunnel_token_secret_name
  secret_recovery_window_in_days = 7
  tags                           = local.common_tags
}

module "app_service" {
  for_each = var.apps

  source = "../../modules/ecs-app-service"

  name                           = var.name
  app_name                       = each.key
  cluster_id                     = module.ecs_cluster.cluster_id
  cluster_name                   = module.ecs_cluster.cluster_name
  capacity_provider_strategy     = local.service_capacity_provider_strategy
  private_subnet_ids             = module.network.private_subnet_ids
  security_group_ids             = [module.network.app_task_security_group_id]
  service_discovery_registry_arn = module.cloud_map.app_service_arns[each.key]
  aws_region                     = var.aws_region
  log_group_name                 = module.observability.app_log_group_name
  app_image                      = each.value.image
  container_name                 = each.value.container_name
  container_port                 = each.value.port
  cpu                            = each.value.cpu
  memory                         = each.value.memory
  desired_count                  = each.value.desired_count
  environment                    = each.value.environment
  secrets                        = each.value.secrets
  secret_arns                    = each.value.secret_arns
  task_policy_json               = each.value.task_policy_json
  health_check_path              = each.value.health_check_path
  health_check_command           = each.value.health_check_command
  enable_container_health_check  = each.value.enable_container_health_check
  enable_execute_command         = var.enable_execute_command
  enable_autoscaling             = each.value.enable_autoscaling
  autoscaling_min_capacity       = each.value.autoscaling_min_capacity
  autoscaling_max_capacity       = each.value.autoscaling_max_capacity
  autoscaling_cpu_target         = each.value.autoscaling_cpu_target
  autoscaling_memory_target      = each.value.autoscaling_memory_target
  tags                           = local.common_tags
}

module "edge_proxy" {
  source = "../../modules/edge-proxy"

  depends_on = [module.cloudflare_tunnel]

  name                               = var.name
  cluster_id                         = module.ecs_cluster.cluster_id
  capacity_provider_strategy         = local.service_capacity_provider_strategy
  private_subnet_ids                 = module.network.private_subnet_ids
  security_group_ids                 = [module.network.edge_task_security_group_id]
  aws_region                         = var.aws_region
  log_group_name                     = module.observability.edge_log_group_name
  haproxy_image                      = var.haproxy_image
  cloudflared_image                  = var.cloudflared_image
  cloudflare_tunnel_token_secret_arn = module.cloudflare_tunnel.tunnel_token_secret_arn
  apps                               = local.haproxy_apps
  haproxy_port                       = var.edge_port
  haproxy_backend_slots              = var.haproxy_backend_slots
  route53_resolver_ip                = var.route53_resolver_ip
  cpu                                = var.edge_cpu
  memory                             = var.edge_memory
  desired_count                      = var.edge_desired_count
  enable_execute_command             = var.enable_execute_command
  task_policy_json                   = var.edge_task_policy_json
  tags                               = local.common_tags
}
