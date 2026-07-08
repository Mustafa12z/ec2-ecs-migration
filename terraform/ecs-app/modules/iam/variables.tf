variable "name" {
  description = "Name prefix for IAM resources"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the RDS credentials secret the execution role may read"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the CI/CD role may push to"
  type        = list(string)
}

variable "github_org" {
  description = "GitHub org/user that owns the repo (for OIDC trust)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repository name (for OIDC trust)"
  type        = string
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider (set false if it already exists in the account)"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
