variable "name" {
  description = "Name prefix / task family"
  type        = string
}

variable "cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "service_name" {
  description = "ECS service name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnets for the tasks"
  type        = list(string)
}

variable "alb_security_group_id" {
  description = "ALB security group ID (ingress source for nginx)"
  type        = string
}

variable "blue_target_group_arn" {
  description = "Initial (blue) target group ARN for the service"
  type        = string
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN"
  type        = string
}

variable "task_role_arn" {
  description = "ECS task role ARN"
  type        = string
}

variable "frontend_image" {
  description = "Full image URI for the nginx frontend container"
  type        = string
}

variable "api_image" {
  description = "Full image URI for the Flask api container"
  type        = string
}

variable "frontend_port" {
  description = "Port nginx listens on"
  type        = number
  default     = 80
}

variable "api_port" {
  description = "Port Flask/Gunicorn listens on"
  type        = number
  default     = 5000
}

variable "frontend_log_group" {
  description = "CloudWatch log group for the frontend container"
  type        = string
}

variable "api_log_group" {
  description = "CloudWatch log group for the api container"
  type        = string
}

variable "db_secret_arn" {
  description = "Secrets Manager ARN with DB credentials (JSON keys injected as env)"
  type        = string
}

variable "app_name" {
  description = "APP_NAME env for the api"
  type        = string
  default     = "legacy-api"
}

variable "app_version" {
  description = "APP_VERSION env for the api"
  type        = string
  default     = "2.0.0"
}

variable "environment" {
  description = "ENVIRONMENT env for the api"
  type        = string
  default     = "production"
}

variable "cpu" {
  description = "Task CPU units"
  type        = number
  default     = 512
}

variable "memory" {
  description = "Task memory (MiB)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Initial desired task count"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Autoscaling minimum tasks"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Autoscaling maximum tasks"
  type        = number
  default     = 6
}

variable "cpu_target_value" {
  description = "Target average CPU % for autoscaling"
  type        = number
  default     = 60
}

variable "health_check_grace_period" {
  description = "Seconds to ignore ALB health checks after task start"
  type        = number
  default     = 60
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
