output "repository_urls" {
  description = "Map of short name => repository URL (docker push targets)"
  value       = module.ecr.repository_urls
}

output "repository_arns" {
  description = "List of repository ARNs"
  value       = module.ecr.repository_arns
}
