variable "name" {
  description = "Name prefix for CodeDeploy resources"
  type        = string
}

variable "service_role_arn" {
  description = "CodeDeploy service role ARN"
  type        = string
}

variable "ecs_cluster_name" {
  description = "ECS cluster name"
  type        = string
}

variable "ecs_service_name" {
  description = "ECS service name"
  type        = string
}

variable "prod_listener_arn" {
  description = "Production ALB listener ARN (443)"
  type        = string
}

variable "blue_target_group_name" {
  description = "Blue target group name"
  type        = string
}

variable "green_target_group_name" {
  description = "Green target group name"
  type        = string
}

variable "deployment_config_name" {
  description = "CodeDeploy deployment configuration"
  type        = string
  default     = "CodeDeployDefault.ECSAllAtOnce"
}

variable "termination_wait_minutes" {
  description = "Minutes to keep the old (blue) task set before terminating"
  type        = number
  default     = 5
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
