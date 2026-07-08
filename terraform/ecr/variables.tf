variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name / repository namespace (must match the ecs-app stack)"
  type        = string
  default     = "legacy-api"
}

variable "repository_names" {
  description = "Short repository names to create"
  type        = list(string)
  default     = ["frontend", "api"]
}

variable "max_image_count" {
  description = "Number of tagged images to retain per repository"
  type        = number
  default     = 10
}

variable "tags" {
  description = "Extra tags"
  type        = map(string)
  default     = {}
}
