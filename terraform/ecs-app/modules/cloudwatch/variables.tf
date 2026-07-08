variable "name" {
  description = "Name prefix for CloudWatch resources"
  type        = string
}

variable "log_group_names" {
  description = "CloudWatch log group names to create"
  type        = list(string)
}

variable "retention_in_days" {
  description = "Log retention in days"
  type        = number
  default     = 30
}

variable "ecs_cluster_name" {
  description = "ECS cluster name (for alarm dimensions)"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name (for alarm dimensions)"
  type        = string
}

variable "alb_arn_suffix" {
  description = "ALB ARN suffix (for alarm dimensions)"
  type        = string
}

variable "cpu_threshold" {
  description = "CPU utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "memory_threshold" {
  description = "Memory utilization alarm threshold (%)"
  type        = number
  default     = 80
}

variable "alb_5xx_threshold" {
  description = "Target 5xx count alarm threshold (per minute)"
  type        = number
  default     = 10
}

variable "alarm_actions" {
  description = "ARNs to notify on alarm (e.g. SNS topic)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
