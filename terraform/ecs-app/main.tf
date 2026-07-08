locals {
  name = var.project_name

  cluster_name = "${local.name}-cluster"
  service_name = "${local.name}-svc"

  frontend_log_group = "/ecs/${local.name}/frontend"
  api_log_group      = "/ecs/${local.name}/api"

  frontend_image = "${data.aws_ecr_repository.frontend.repository_url}:${var.frontend_image_tag}"
  api_image      = "${data.aws_ecr_repository.api.repository_url}:${var.api_image_tag}"
}

data "aws_route53_zone" "this" {
  name = var.hosted_zone_name
}

# ECR repositories are created out-of-band (see terraform/ecr) and pushed to
# BEFORE this stack is applied, so the ECS tasks have images to pull on first
# deploy. This stack only references them.
data "aws_ecr_repository" "frontend" {
  name = "${local.name}/frontend"
}

data "aws_ecr_repository" "api" {
  name = "${local.name}/api"
}

# ------------------------------------------------------------------------ VPC
module "vpc" {
  source = "./modules/vpc"

  name                 = local.name
  cidr_block           = var.vpc_cidr
  azs                  = var.azs
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  single_nat_gateway   = var.single_nat_gateway
}

# ------------------------------------------------------------------------ RDS
module "rds" {
  source = "./modules/rds"

  name                = local.name
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = module.vpc.private_subnet_ids
  instance_class      = var.db_instance_class
  multi_az            = var.db_multi_az
  deletion_protection = var.db_deletion_protection
}

# ------------------------------------------------------------------------ IAM
module "iam" {
  source = "./modules/iam"

  name                        = local.name
  db_secret_arn               = module.rds.db_secret_arn
  ecr_repository_arns         = [data.aws_ecr_repository.frontend.arn, data.aws_ecr_repository.api.arn]
  github_org                  = var.github_org
  github_repo                 = var.github_repo
  create_github_oidc_provider = var.create_github_oidc_provider
}

# ------------------------------------------------------------------------ ALB
module "alb" {
  source = "./modules/alb"

  name              = local.name
  vpc_id            = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnet_ids
  domain_name       = var.domain_name
  hosted_zone_id    = data.aws_route53_zone.this.zone_id
}

# ----------------------------------------------------------------- CloudWatch
module "cloudwatch" {
  source = "./modules/cloudwatch"

  name             = local.name
  log_group_names  = [local.frontend_log_group, local.api_log_group]
  ecs_cluster_name = local.cluster_name
  ecs_service_name = local.service_name
  alb_arn_suffix   = module.alb.alb_arn_suffix
  alarm_actions    = var.alarm_actions
}

# ------------------------------------------------------------------------ ECS
module "ecs" {
  source = "./modules/ecs"

  name         = local.name
  cluster_name = local.cluster_name
  service_name = local.service_name

  vpc_id                = module.vpc.vpc_id
  private_subnet_ids    = module.vpc.private_subnet_ids
  alb_security_group_id = module.alb.security_group_id
  blue_target_group_arn = module.alb.blue_target_group_arn

  execution_role_arn = module.iam.task_execution_role_arn
  task_role_arn      = module.iam.task_role_arn

  frontend_image     = local.frontend_image
  api_image          = local.api_image
  frontend_log_group = local.frontend_log_group
  api_log_group      = local.api_log_group

  db_secret_arn = module.rds.db_secret_arn

  environment   = var.environment
  cpu           = var.task_cpu
  memory        = var.task_memory
  desired_count = var.desired_count
  min_capacity  = var.min_capacity
  max_capacity  = var.max_capacity

  # Ensure log groups exist before the service tries to write to them.
  depends_on = [module.cloudwatch]
}

# Allow the ECS tasks to reach RDS on 5432 (added here to avoid a module cycle).
resource "aws_vpc_security_group_ingress_rule" "ecs_to_rds" {
  security_group_id            = module.rds.security_group_id
  referenced_security_group_id = module.ecs.task_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"
  description                  = "PostgreSQL from ECS tasks"
}

# ----------------------------------------------------------------- CodeDeploy
module "codedeploy" {
  source = "./modules/codedeploy"

  name                    = local.name
  service_role_arn        = module.iam.codedeploy_role_arn
  ecs_cluster_name        = module.ecs.cluster_name
  ecs_service_name        = module.ecs.service_name
  prod_listener_arn       = module.alb.https_listener_arn
  blue_target_group_name  = module.alb.blue_target_group_name
  green_target_group_name = module.alb.green_target_group_name
}

# ------------------------------------------------------------------- Route53
module "route53" {
  source = "./modules/route53"

  hosted_zone_id = data.aws_route53_zone.this.zone_id
  record_name    = var.domain_name
  alb_dns_name   = module.alb.alb_dns_name
  alb_zone_id    = module.alb.alb_zone_id
}
