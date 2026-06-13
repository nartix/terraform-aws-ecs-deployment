# Terraform ECS Edge Stack

This stack deploys the production-style edge architecture for Edgeforge:

- AWS VPC with public NAT subnets and private ECS subnets
- ECS on EC2 with an On-Demand baseline capacity provider and a Spot capacity provider
- AWS Cloud Map private DNS with app tasks registered as `<app>.ecs.internal`
- One ECS service per app using `awsvpc`, Cloud Map `A` records, and service autoscaling
- Edge ECS service running `haproxy` and `cloudflared` in the same task
- Cloudflare Tunnel, proxied DNS record, tunnel ingress config, and an AWS Secrets Manager tunnel token
- CloudWatch log groups for app, HAProxy, and cloudflared logs

The public request path is:

```text
User
  -> Cloudflare DNS/WAF/Access
  -> Cloudflare Tunnel
  -> cloudflared container
  -> localhost:8080
  -> HAProxy container
  -> host-based HAProxy backend
  -> <app>.ecs.internal:<port> through Cloud Map DNS
  -> app-specific ECS tasks
```

## What This Does Not Create

You must provide these pieces separately:

- The application container image
- The ECR repository or other registry that stores the app image
- The ECR repository or other registry that stores the HAProxy image
- The application database, such as RDS Postgres
- Database credentials/secrets
- CI/CD for rebuilding and redeploying app images
- The Terraform/OpenTofu remote state bucket and lock table, if you choose remote state

## Directory Layout

```text
terraform/
  envs/prod/                 # Production stack entrypoint
  modules/network/           # VPC, subnets, NAT, security groups
  modules/ecs-cluster/       # ECS cluster, EC2 ASGs, capacity providers
  modules/cloud-map/         # Private DNS namespace and app service discovery
  modules/ecs-app-service/   # App task definition, service, autoscaling
  modules/edge-proxy/        # cloudflared + HAProxy ECS service
  modules/cloudflare-tunnel/ # Cloudflare Tunnel, DNS record, token secret
  modules/observability/     # CloudWatch log groups
  images/haproxy/            # HAProxy image and DNS-discovery config
```

## Prerequisites

Install these locally:

- Docker and Docker Compose
- Make
- AWS CLI v2
- OpenTofu or Terraform

The Makefile defaults to OpenTofu:

```bash
make terraform-plan
```

For production changes where you want to apply the exact plan you reviewed:

```bash
make terraform-plan-save
make terraform-apply-plan
```

Saved plans default to `TF_PLAN=tfplan`; override it with something like `TF_PLAN=prod.tfplan` if you want a different filename. Plan files can contain sensitive values, so `tfplan` and `*.tfplan` are ignored by Git.

Use Terraform instead with:

```bash
make terraform-plan TF=terraform
```

Configure AWS credentials before running the stack:

```bash
aws sts get-caller-identity
```

The AWS identity needs permission to manage VPC, EC2, Auto Scaling, ECS, IAM, CloudWatch Logs, Secrets Manager, AWS Cloud Map, Route 53 private DNS, Application Auto Scaling, and SSM parameter reads.

## Cloudflare Setup

Your domain must already be active in Cloudflare.

Create a Cloudflare API token and export it before running Terraform/OpenTofu:

```bash
export CLOUDFLARE_API_TOKEN=...
```

The token needs enough access to:

- Read the account/zone
- Create and manage Cloudflare Tunnels
- Create and manage DNS records for every zone listed in `apps[*].hostnames[*].zone_id`

Find the Cloudflare account ID and each zone ID, then put them in `terraform.tfvars`.

```hcl
cloudflare_account_id = "..."

apps = {
  api = {
    image = "<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-api:latest"
    port  = 8080

    hostnames = [
      {
        hostname = "api.example.com"
        zone_id  = "..."
      },
      {
        hostname = "api.otherdomain.com"
        zone_id  = "..."
      }
    ]
  }
}
```

Every hostname gets a Cloudflare DNS record that points to the same tunnel. HAProxy routes requests to the right ECS service by the `Host` header.

## Terraform State

For quick testing, you can use local state. Do not commit `terraform.tfstate`; it is ignored by `.gitignore`.

For production, use encrypted remote state because Terraform state can contain sensitive values, including the Cloudflare tunnel token read from Cloudflare.

The template is:

```text
terraform/envs/prod/backend.tf.example
```

To use it:

```bash
cp terraform/envs/prod/backend.tf.example terraform/envs/prod/backend.tf
```

Edit the bucket and DynamoDB table names:

```hcl
terraform {
  backend "s3" {
    bucket         = "your-terraform-state-bucket"
    key            = "edgeforge/prod.tfstate"
    region         = "us-east-2"
    dynamodb_table = "your-terraform-locks-table"
    encrypt        = true
  }
}
```

Create the S3 bucket and DynamoDB lock table before `terraform-init`. Example:

```bash
aws s3api create-bucket \
  --bucket your-terraform-state-bucket \
  --region us-east-2 \
  --create-bucket-configuration LocationConstraint=us-east-2

aws s3api put-bucket-versioning \
  --bucket your-terraform-state-bucket \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket your-terraform-state-bucket \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

aws dynamodb create-table \
  --table-name your-terraform-locks-table \
  --billing-mode PAY_PER_REQUEST \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH
```

## Container Images

This Terraform stack expects image repositories/images to already exist.

Create ECR repositories if you do not already have them:

```bash
aws ecr create-repository --repository-name edgeforge-api --region us-east-2
aws ecr create-repository --repository-name edgeforge-dashboard --region us-east-2
aws ecr create-repository --repository-name edgeforge-haproxy --region us-east-2
```

Log Docker into ECR:

```bash
aws ecr get-login-password --region us-east-2 \
  | docker login --username AWS --password-stdin < account_id > .dkr.ecr.us-east-2.amazonaws.com
```

Build and push the HAProxy image:

```bash
make haproxy-edge-build IMAGE= < account_id > .dkr.ecr.us-east-2.amazonaws.com/edgeforge-haproxy:latest
docker push < account_id > .dkr.ecr.us-east-2.amazonaws.com/edgeforge-haproxy:latest
```

Build and push your app image using the app repo's normal build process. The final image must be reachable by ECS, for example:

```text
<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-api:latest
```

Each app defaults to:

- It listens on port `8080`
- It has a health endpoint at `/health`
- It has `curl` installed for the default ECS container health check

If an image does not have `curl`, set a custom command for that app in `terraform.tfvars`:

```hcl
apps = {
  api = {
    image = "<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-api:latest"
    port  = 8080

    health_check_command = [
      "CMD-SHELL",
      "wget -q -O- http://localhost:8080/health || exit 1"
    ]

    hostnames = [
      {
        hostname = "api.example.com"
        zone_id  = "..."
      }
    ]
  }
}
```

## Required Terraform Variables

Create the real tfvars file:

```bash
cp terraform/envs/prod/terraform.tfvars.example terraform/envs/prod/terraform.tfvars
```

At minimum, set:

```hcl
name       = "edgeforge"
aws_region = "us-east-2"

cloudflare_account_id = "..."

haproxy_image = "<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-haproxy:latest"

apps = {
  api = {
    image = "<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-api:latest"
    port  = 8080

    hostnames = [
      {
        hostname = "api.example.com"
        zone_id  = "..."
      },
      {
        hostname = "api.otherdomain.com"
        zone_id  = "..."
      }
    ]
  }

  dashboard = {
    image             = "<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-dashboard:latest"
    port              = 3000
    desired_count     = 2
    backend_slots     = 4
    health_check_path = "/health"

    hostnames = [
      {
        hostname = "dashboard.example.com"
        zone_id  = "..."
      }
    ]
  }
}

tags = {
  Environment = "prod"
  Owner       = "edgeforge"
}
```

App map keys become ECS service names, Cloud Map DNS names, and HAProxy backend names. Use short lowercase alphanumeric names such as `api`, `dashboard`, or `blog1`.

Common optional settings:

```hcl
vpc_cidr = "10.80.0.0/16"
az_count = 2

edge_desired_count = 2
edge_port          = 8080
haproxy_backend_slots = 20

on_demand_desired_capacity = 1
spot_desired_capacity      = 2
```

Per-app optional settings live inside each app block:

If `backend_slots` is `null` or omitted for an app, that app uses the global `haproxy_backend_slots` value.

```hcl
apps = {
  api = {
    image                         = "..."
    port                          = 8080
    desired_count                 = 2
    cpu                           = 256
    memory                        = 512
    health_check_path             = "/health"
    backend_slots                 = null
    enable_container_health_check = true
    enable_autoscaling            = true
    autoscaling_min_capacity      = 2
    autoscaling_max_capacity      = 10
    autoscaling_cpu_target        = 60
    autoscaling_memory_target     = null
    environment                   = {}
    secrets                       = []
    secret_arns                   = []

    hostnames = [
      {
        hostname = "api.example.com"
        zone_id  = "..."
      }
    ]
  }
}
```

## Database Setup

This stack does not create a database yet.

For a production app, use one of these approaches:

- Point the app at an existing database that is reachable from this VPC
- Create the database in a separate Terraform stack after this stack creates the VPC outputs, then apply this stack again with DB variables
- Add an RDS module to this stack before using it for a DB-dependent production app

If your app cannot boot without a database, do not apply the final app service configuration until the database endpoint, security group rules, and secrets exist.

Recommended setup:

- Create the DB in private subnets in the same VPC, or in a peered/private network reachable from the ECS app tasks
- Put DB credentials in AWS Secrets Manager
- Allow DB inbound traffic from the app task security group only
- Pass non-secret DB settings through each app's `environment`
- Pass secret DB settings through each app's `secrets` and `secret_arns`

Example `terraform.tfvars`:

```hcl
apps = {
  api = {
    image = "<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-api:latest"
    port  = 8080

    environment = {
      NODE_ENV = "production"
      DB_HOST  = "edgeforge-prod.xxxxxx.us-east-2.rds.amazonaws.com"
      DB_PORT  = "5432"
      DB_NAME  = "app"
    }

    secrets = [
      {
        name       = "DATABASE_URL"
        value_from = "arn:aws:secretsmanager:us-east-2:<account_id>:secret:prod/edgeforge/api/database-url"
      }
    ]

    secret_arns = [
      "arn:aws:secretsmanager:us-east-2:<account_id>:secret:prod/edgeforge/api/database-url-*"
    ]

    hostnames = [
      {
        hostname = "api.example.com"
        zone_id  = "..."
      }
    ]
  }
}
```

If the app only needs discrete secrets:

```hcl
apps = {
  api = {
    image = "..."
    port  = 8080

    secrets = [
      {
        name       = "DB_PASSWORD"
        value_from = "arn:aws:secretsmanager:us-east-2:<account_id>:secret:prod/edgeforge/api/db-password"
      }
    ]

    secret_arns = [
      "arn:aws:secretsmanager:us-east-2:<account_id>:secret:prod/edgeforge/api/db-password-*"
    ]

    hostnames = [
      {
        hostname = "api.example.com"
        zone_id  = "..."
      }
    ]
  }
}
```

By default, app task egress is open because app dependencies are project-specific:

```hcl
app_egress_cidr_blocks = ["0.0.0.0/0"]
```

After the DB/cache/private dependencies are known, narrow it:

```hcl
app_egress_cidr_blocks = ["10.80.0.0/16"]
```

## Cloudflare Tunnel Token

You do not manually create or paste the Cloudflare tunnel token.

Terraform will:

1. Create the Cloudflare Tunnel
2. Read the tunnel token from Cloudflare
3. Store it in AWS Secrets Manager
4. Grant the edge ECS execution role permission to read it
5. Inject it into the `cloudflared` container as `TUNNEL_TOKEN`

The default secret name is:

```text
/ecs/<name>/cloudflare-tunnel-token
```

Override it if needed:

```hcl
cloudflare_tunnel_token_secret_name = "/ecs/edgeforge/prod/cloudflare-tunnel-token"
```

## Deploy

From the repo root:

```bash
make terraform-init
make terraform-plan
make terraform-apply
```

For a stricter reviewed-plan deploy:

```bash
make terraform-init
make terraform-plan-save
make terraform-apply-plan
```

With Terraform instead of OpenTofu:

```bash
make terraform-init TF=terraform
make terraform-plan TF=terraform
make terraform-apply TF=terraform
```

If the plan looks right, apply it.

## Post-Deploy Checks

Check the Terraform outputs:

```bash
cd terraform/envs/prod
tofu output
```

Check ECS:

```bash
aws ecs list-services --cluster edgeforge-cluster --region us-east-2
aws ecs describe-services \
  --cluster edgeforge-cluster \
  --services edgeforge-api edgeforge-dashboard edgeforge-edge \
  --region us-east-2
```

Check Cloud Map DNS from inside the VPC if you have a test instance or ECS Exec:

```bash
dig api.ecs.internal
dig dashboard.ecs.internal
```

Check logs:

```bash
aws logs tail /ecs/edgeforge/app --follow --region us-east-2
aws logs tail /ecs/edgeforge/edge --follow --region us-east-2
```

Check the public hostname:

```bash
curl -I https://api.example.com
curl -I https://dashboard.example.com
```

## Troubleshooting

If app tasks do not become healthy:

- Confirm the app listens on its configured `apps.<name>.port`
- Confirm the health endpoint exists
- Confirm the app image has the binary used by `health_check_command`
- Check `/ecs/edgeforge/app` logs with the app's log stream prefix

If edge tasks do not become healthy:

- Confirm the HAProxy image was pushed and `haproxy_image` is correct
- Check `/ecs/edgeforge/edge` logs for HAProxy and cloudflared
- Confirm the Cloudflare token secret exists
- Confirm each private app DNS name resolves inside the VPC

If Cloudflare shows tunnel errors:

- Confirm `CLOUDFLARE_API_TOKEN` had permission to create the tunnel and DNS record
- Confirm the edge service has running `cloudflared` tasks
- Confirm the DNS record points at `<tunnel_id>.cfargotunnel.com`

If ECS cannot pull images:

- Confirm the image URI and tag exist
- Confirm private subnets have NAT egress or equivalent VPC endpoints
- Confirm the ECS task execution role has the standard execution policy

If tasks cannot connect to the database:

- Confirm the DB is reachable from the ECS app subnets
- Confirm the DB security group allows inbound from the app task security group
- Confirm secret ARNs are listed in the app's `secret_arns`
- Confirm the application received the expected env vars and secrets

## Cost Notes

This stack creates billable resources:

- EC2 container instances
- NAT Gateway and NAT data processing
- CloudWatch Logs storage
- AWS Secrets Manager secret
- Cloud Map namespace/service
- Cloudflare paid features if enabled separately

For cheaper testing, reduce counts in `terraform.tfvars`:

```hcl
on_demand_desired_capacity = 1
spot_desired_capacity      = 0
edge_desired_count         = 1
enable_spot_capacity       = false

apps = {
  api = {
    image         = "<account_id>.dkr.ecr.us-east-2.amazonaws.com/edgeforge-api:latest"
    desired_count = 1

    hostnames = [
      {
        hostname = "api.example.com"
        zone_id  = "..."
      }
    ]
  }
}
```

Do not use a single task or no On-Demand capacity for production availability.

## Destroy

To tear down the stack:

```bash
make terraform-destroy
```

Destroying the stack removes the ECS services, Cloudflare Tunnel/DNS record, VPC resources, and the tunnel token secret. It does not delete app images, external databases, or manually created state backend resources.
