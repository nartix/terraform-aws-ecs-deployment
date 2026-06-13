data "aws_ssm_parameter" "ecs_optimized_ami" {
  count = var.ecs_optimized_ami_id == "" ? 1 : 0

  name = var.ecs_optimized_ami_ssm_parameter
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

locals {
  ecs_ami_id = var.ecs_optimized_ami_id != "" ? var.ecs_optimized_ami_id : data.aws_ssm_parameter.ecs_optimized_ami[0].value

  user_data = <<-EOT
#!/bin/bash
cat <<'EOF' >> /etc/ecs/ecs.config
ECS_CLUSTER=${aws_ecs_cluster.this.name}
ECS_ENABLE_CONTAINER_METADATA=true
ECS_ENABLE_AWSLOGS_EXECUTIONROLE_OVERRIDE=true
EOF
EOT

  capacity_provider_names = compact(concat(
    var.enable_on_demand_capacity ? [aws_ecs_capacity_provider.on_demand[0].name] : [],
    var.enable_spot_capacity ? [aws_ecs_capacity_provider.spot[0].name] : []
  ))

  default_capacity_provider_strategy = concat(
    var.enable_on_demand_capacity ? [
      {
        capacity_provider = aws_ecs_capacity_provider.on_demand[0].name
        base              = var.on_demand_strategy_base
        weight            = var.on_demand_strategy_weight
      }
    ] : [],
    var.enable_spot_capacity ? [
      {
        capacity_provider = aws_ecs_capacity_provider.spot[0].name
        base              = var.enable_on_demand_capacity ? 0 : var.spot_strategy_base
        weight            = var.spot_strategy_weight
      }
    ] : []
  )
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"

  setting {
    name  = "containerInsights"
    value = var.enable_container_insights ? "enabled" : "disabled"
  }

  tags = var.tags
}

resource "aws_iam_role" "ecs_instance" {
  name               = "${var.name}-ecs-instance-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = var.tags
}

resource "aws_iam_role_policy_attachment" "ecs_instance" {
  role       = aws_iam_role.ecs_instance.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_iam_instance_profile" "ecs" {
  name = "${var.name}-ecs-instance-profile"
  role = aws_iam_role.ecs_instance.name

  tags = var.tags
}

resource "aws_launch_template" "ecs" {
  name_prefix   = "${var.name}-ecs-"
  image_id      = local.ecs_ami_id
  instance_type = var.on_demand_instance_type
  key_name      = var.ssh_key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ecs.name
  }

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  monitoring {
    enabled = true
  }

  vpc_security_group_ids = [var.container_instance_security_group_id]
  user_data              = base64encode(local.user_data)

  tag_specifications {
    resource_type = "instance"

    tags = merge(var.tags, {
      Name = "${var.name}-ecs-instance"
    })
  }

  tag_specifications {
    resource_type = "volume"

    tags = merge(var.tags, {
      Name = "${var.name}-ecs-volume"
    })
  }

  tags = var.tags
}

resource "aws_autoscaling_group" "on_demand" {
  count = var.enable_on_demand_capacity ? 1 : 0

  name                      = "${var.name}-ondemand-asg"
  min_size                  = var.on_demand_min_size
  desired_capacity          = var.on_demand_desired_capacity
  max_size                  = var.on_demand_max_size
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  protect_from_scale_in     = true
  wait_for_capacity_timeout = "10m"

  launch_template {
    id      = aws_launch_template.ecs.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-ondemand-ecs"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_autoscaling_group" "spot" {
  count = var.enable_spot_capacity ? 1 : 0

  name                      = "${var.name}-spot-asg"
  min_size                  = var.spot_min_size
  desired_capacity          = var.spot_desired_capacity
  max_size                  = var.spot_max_size
  vpc_zone_identifier       = var.private_subnet_ids
  health_check_type         = "EC2"
  protect_from_scale_in     = true
  wait_for_capacity_timeout = "10m"

  mixed_instances_policy {
    instances_distribution {
      on_demand_percentage_above_base_capacity = 0
      spot_allocation_strategy                 = "price-capacity-optimized"
    }

    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.ecs.id
        version            = "$Latest"
      }

      dynamic "override" {
        for_each = var.spot_instance_types

        content {
          instance_type = override.value
        }
      }
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.name}-spot-ecs"
    propagate_at_launch = true
  }

  tag {
    key                 = "AmazonECSManaged"
    value               = "true"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = var.tags

    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}

resource "aws_ecs_capacity_provider" "on_demand" {
  count = var.enable_on_demand_capacity ? 1 : 0

  name = "${var.name}-ondemand"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.on_demand[0].arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.capacity_provider_target_capacity
      minimum_scaling_step_size = var.capacity_provider_minimum_scaling_step_size
      maximum_scaling_step_size = var.capacity_provider_maximum_scaling_step_size
    }
  }

  tags = var.tags
}

resource "aws_ecs_capacity_provider" "spot" {
  count = var.enable_spot_capacity ? 1 : 0

  name = "${var.name}-spot"

  auto_scaling_group_provider {
    auto_scaling_group_arn         = aws_autoscaling_group.spot[0].arn
    managed_termination_protection = "ENABLED"

    managed_scaling {
      status                    = "ENABLED"
      target_capacity           = var.capacity_provider_target_capacity
      minimum_scaling_step_size = var.capacity_provider_minimum_scaling_step_size
      maximum_scaling_step_size = var.capacity_provider_maximum_scaling_step_size
    }
  }

  tags = var.tags
}

resource "aws_ecs_cluster_capacity_providers" "this" {
  cluster_name = aws_ecs_cluster.this.name

  capacity_providers = local.capacity_provider_names

  dynamic "default_capacity_provider_strategy" {
    for_each = local.default_capacity_provider_strategy

    content {
      capacity_provider = default_capacity_provider_strategy.value.capacity_provider
      base              = default_capacity_provider_strategy.value.base
      weight            = default_capacity_provider_strategy.value.weight
    }
  }
}
