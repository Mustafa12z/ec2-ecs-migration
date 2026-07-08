output "repository_urls" {
  description = "Map of short name => repository URL"
  value       = { for k, v in aws_ecr_repository.this : k => v.repository_url }
}

output "repository_arns" {
  description = "List of repository ARNs"
  value       = [for v in aws_ecr_repository.this : v.arn]
}
