output "application_name" {
  description = "CodeDeploy application name"
  value       = aws_codedeploy_app.this.name
}

output "deployment_group_name" {
  description = "CodeDeploy deployment group name"
  value       = aws_codedeploy_deployment_group.this.deployment_group_name
}
