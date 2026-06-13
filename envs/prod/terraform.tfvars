name       = "edgeforge"
aws_region = "us-east-2"

cloudflare_account_id = "d588be34f302b0c423e8be7bd51bc38f"

haproxy_backend_slots = 20
haproxy_image         = "155097172472.dkr.ecr.us-east-2.amazonaws.com/edgeforge-haproxy:latest"

spot_instance_types = [
  "t2.micro",
  "t2.small",
  "t3.micro",
  "t3.small",
  "t3a.micro",
  "t3a.small",
  "t3a.medium"
]

on_demand_instance_type    = "t3a.micro"
on_demand_min_size         = 1
on_demand_desired_capacity = 1
on_demand_max_size         = 1

spot_min_size         = 1
spot_desired_capacity = 1
spot_max_size         = 1

capacity_provider_target_capacity = 100

apps = {
  # expressjs = {
  #   image             = "155097172472.dkr.ecr.us-east-2.amazonaws.com/edgeforge-expressjs:latest"
  #   port              = 5000
  #   health_check_path = "/"

  #   hostnames = [
  #     {
  #       hostname = "expressjs.ferozfaiz.com"
  #       zone_id  = "08bc6bb40eb2711644a67a869f246285"
  #     },
  #     {
  #       hostname = "expressjs.iamdb.net"
  #       zone_id  = "52b52a193bb63779fc18ab6871d8869b"
  #     }
  #   ]
  # }

  reactjs = {
    image                    = "155097172472.dkr.ecr.us-east-2.amazonaws.com/portfolio-reactjs:v1.0.0-17fc7762"
    port                     = 80
    health_check_path        = "/"
    desired_count            = 1
    autoscaling_min_capacity = 1
    autoscaling_max_capacity = 1
    memory                   = 256

    hostnames = [
      # {
      #   hostname = "reactjs.ferozfaiz.com"
      #   zone_id  = "08bc6bb40eb2711644a67a869f246285"
      # },
      {
        hostname = "reactjs-staging.iamdb.net"
        zone_id  = "52b52a193bb63779fc18ab6871d8869b"
      }
    ]
  }
}

tags = {
  Environment = "prod"
  Owner       = "edgeforge"
}

# For production, narrow this once the app's dependencies are known.
app_egress_cidr_blocks = ["0.0.0.0/0"]
