variable "name" {
  description = "Name prefix for IAM resources"
  type        = string
}

variable "db_secret_arn" {
  description = "ARN of the RDS credentials secret the execution role may read"
  type        = string
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
