data "aws_iam_policy_document" "task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "execution_secrets" {
  statement {
    actions = ["secretsmanager:GetSecretValue"]

    resources = [var.cloudflare_tunnel_token_secret_arn]
  }
}

locals {
  haproxy_config = templatefile("${path.module}/haproxy.cfg.tftpl", {
    apps                = var.apps
    frontend_port       = var.haproxy_port
    route53_resolver_ip = var.route53_resolver_ip
    sorted_app_names    = sort(keys(var.apps))
  })

  haproxy_container = {
    name      = "haproxy"
    image     = var.haproxy_image
    essential = true

    portMappings = [
      {
        containerPort = var.haproxy_port
        hostPort      = var.haproxy_port
        protocol      = "tcp"
      }
    ]

    environment = [
      {
        name  = "HAPROXY_CONFIG_B64"
        value = base64encode(local.haproxy_config)
      },
      {
        name  = "HAPROXY_FRONTEND_PORT"
        value = tostring(var.haproxy_port)
      },
      {
        name  = "HAPROXY_BACKEND_SLOTS"
        value = tostring(var.haproxy_backend_slots)
      },
      {
        name  = "ROUTE53_RESOLVER_IP"
        value = var.route53_resolver_ip
      }
    ]

    healthCheck = {
      command = [
        "CMD-SHELL",
        "wget -q -O- http://localhost:${var.haproxy_port}/_edge_health || exit 1"
      ]
      interval    = 15
      timeout     = 5
      retries     = 3
      startPeriod = 15
    }

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "haproxy"
      }
    }
  }

  cloudflared_container = {
    name      = "cloudflared"
    image     = var.cloudflared_image
    essential = true
    command   = ["tunnel", "--no-autoupdate", "run"]

    dependsOn = [
      {
        containerName = "haproxy"
        condition     = "START"
      }
    ]

    secrets = [
      {
        name      = "TUNNEL_TOKEN"
        valueFrom = var.cloudflare_tunnel_token_secret_arn
      }
    ]

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = var.log_group_name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = "cloudflared"
      }
    }
  }
}

resource "aws_iam_role" "execution" {
  name               = "${var.name}-edge-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "execution" {
  role       = aws_iam_role.execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "execution_secrets" {
  name   = "${var.name}-edge-execution-secrets"
  role   = aws_iam_role.execution.id
  policy = data.aws_iam_policy_document.execution_secrets.json
}

resource "aws_iam_role" "task" {
  name               = "${var.name}-edge-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "task_inline" {
  count = var.task_policy_json == null ? 0 : 1

  name   = "${var.name}-edge-task-policy"
  role   = aws_iam_role.task.id
  policy = var.task_policy_json
}

resource "aws_ecs_task_definition" "this" {
  family                   = "${var.name}-edge"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  container_definitions = jsonencode([
    local.haproxy_container,
    local.cloudflared_container
  ])

  tags = var.tags
}

resource "aws_ecs_service" "this" {
  name            = "${var.name}-edge"
  cluster         = var.cluster_id
  task_definition = aws_ecs_task_definition.this.arn
  desired_count   = var.desired_count

  enable_execute_command = var.enable_execute_command

  dynamic "capacity_provider_strategy" {
    for_each = var.capacity_provider_strategy

    content {
      capacity_provider = capacity_provider_strategy.value.capacity_provider
      weight            = capacity_provider_strategy.value.weight
      base              = capacity_provider_strategy.value.base
    }
  }

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  deployment_minimum_healthy_percent = var.deployment_minimum_healthy_percent
  deployment_maximum_percent         = var.deployment_maximum_percent

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.execution,
    aws_iam_role_policy.execution_secrets
  ]

  timeouts {
    delete = "60m"
  }
}
