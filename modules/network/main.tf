data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  selected_azs = length(var.availability_zones) > 0 ? var.availability_zones : slice(data.aws_availability_zones.available.names, 0, var.az_count)

  app_ports_by_key = {
    for port in var.app_ports : tostring(port) => port
  }

  public_subnet_cidrs = length(var.public_subnet_cidrs) > 0 ? var.public_subnet_cidrs : [
    for index in range(length(local.selected_azs)) : cidrsubnet(var.vpc_cidr, 8, index)
  ]

  private_subnet_cidrs = length(var.private_subnet_cidrs) > 0 ? var.private_subnet_cidrs : [
    for index in range(length(local.selected_azs)) : cidrsubnet(var.vpc_cidr, 8, index + 10)
  ]

  nat_gateway_count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(local.selected_azs)) : 0
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name}-vpc"
  })
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-igw"
  })
}

resource "aws_subnet" "public" {
  count = length(local.selected_azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.public_subnet_cidrs[count.index]
  availability_zone       = local.selected_azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-public-${local.selected_azs[count.index]}"
    Tier = "public"
  })
}

resource "aws_subnet" "private" {
  count = length(local.selected_azs)

  vpc_id                  = aws_vpc.this.id
  cidr_block              = local.private_subnet_cidrs[count.index]
  availability_zone       = local.selected_azs[count.index]
  map_public_ip_on_launch = false

  tags = merge(var.tags, {
    Name = "${var.name}-private-${local.selected_azs[count.index]}"
    Tier = "private"
  })
}

resource "aws_eip" "nat" {
  count = local.nat_gateway_count

  domain = "vpc"

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })
}

resource "aws_nat_gateway" "this" {
  count = local.nat_gateway_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = aws_subnet.public[var.single_nat_gateway ? 0 : count.index].id

  tags = merge(var.tags, {
    Name = "${var.name}-nat-${count.index + 1}"
  })

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = merge(var.tags, {
    Name = "${var.name}-public-rt"
  })
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = var.enable_nat_gateway && !var.single_nat_gateway ? length(local.selected_azs) : 1

  vpc_id = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []

    content {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = aws_nat_gateway.this[var.single_nat_gateway ? 0 : count.index].id
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name}-private-rt-${count.index + 1}"
  })
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private[var.enable_nat_gateway && !var.single_nat_gateway ? count.index : 0].id
}

resource "aws_security_group" "ecs_instances" {
  name        = "${var.name}-ecs-instances"
  description = "ECS container instances with no public ingress"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-ecs-instances-sg"
  })
}

resource "aws_security_group" "edge_tasks" {
  name        = "${var.name}-edge-tasks"
  description = "Edge proxy tasks; no inbound traffic, outbound only"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-edge-tasks-sg"
  })
}

resource "aws_security_group" "app_tasks" {
  name        = "${var.name}-app-tasks"
  description = "Application tasks reachable only from edge proxy tasks"
  vpc_id      = aws_vpc.this.id

  tags = merge(var.tags, {
    Name = "${var.name}-app-tasks-sg"
  })
}

resource "aws_security_group_rule" "ecs_instances_egress_all" {
  description       = "Allow container instances to reach ECS, ECR, CloudWatch, and package mirrors"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.ecs_instances.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "edge_https_egress" {
  description       = "cloudflared HTTPS and AWS API egress"
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.edge_tasks.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "edge_quic_egress" {
  description       = "cloudflared QUIC egress"
  type              = "egress"
  from_port         = 7844
  to_port           = 7844
  protocol          = "udp"
  security_group_id = aws_security_group.edge_tasks.id
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "edge_dns_udp_egress" {
  description       = "Route 53 Resolver UDP"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "udp"
  security_group_id = aws_security_group.edge_tasks.id
  cidr_blocks       = ["${var.route53_resolver_ip}/32"]
}

resource "aws_security_group_rule" "edge_dns_tcp_egress" {
  description       = "Route 53 Resolver TCP"
  type              = "egress"
  from_port         = 53
  to_port           = 53
  protocol          = "tcp"
  security_group_id = aws_security_group.edge_tasks.id
  cidr_blocks       = ["${var.route53_resolver_ip}/32"]
}

resource "aws_security_group_rule" "app_egress" {
  count = length(var.app_egress_cidr_blocks) > 0 ? 1 : 0

  description       = "Application outbound dependencies"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  security_group_id = aws_security_group.app_tasks.id
  cidr_blocks       = var.app_egress_cidr_blocks
}

resource "aws_security_group_rule" "edge_to_app" {
  for_each = local.app_ports_by_key

  description              = "HAProxy to app tasks"
  type                     = "egress"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  security_group_id        = aws_security_group.edge_tasks.id
  source_security_group_id = aws_security_group.app_tasks.id
}

resource "aws_security_group_rule" "app_from_edge" {
  for_each = local.app_ports_by_key

  description              = "App traffic from edge proxy"
  type                     = "ingress"
  from_port                = each.value
  to_port                  = each.value
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app_tasks.id
  source_security_group_id = aws_security_group.edge_tasks.id
}
