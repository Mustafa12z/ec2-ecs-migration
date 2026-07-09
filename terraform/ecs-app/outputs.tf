output "app_url" {
  description = "Public application URL"
  value       = "https://${var.domain_name}"
}

output "alb_dns_name" {
  description = "ALB DNS name"
  value       = module.alb.alb_dns_name
}

output "ecr_repository_urls" {
  description = "ECR repository URLs (push targets for CI)"
  value = {
    frontend = data.aws_ecr_repository.frontend.repository_url
    api      = data.aws_ecr_repository.api.repository_url
  }
}

output "ecs_cluster_name" {
  description = "ECS cluster name"
  value       = module.ecs.cluster_name
}

output "ecs_service_name" {
  description = "ECS service name"
  value       = module.ecs.service_name
}

output "codedeploy_application_name" {
  description = "CodeDeploy application name"
  value       = module.codedeploy.application_name
}

output "codedeploy_deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = module.codedeploy.deployment_group_name
}

# The GitHub OIDC provider + "legacy-api-github-actions" role are bootstrapped
# and managed manually via the AWS CLI (see MIGRATION.md), not by this stack.

output "db_endpoint" {
  description = "RDS endpoint"
  value       = module.rds.endpoint
}

output "db_secret_arn" {
  description = "Secrets Manager ARN with DB credentials"
  value       = module.rds.db_secret_arn
}
