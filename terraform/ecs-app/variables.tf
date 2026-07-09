variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-2"
}

variable "project_name" {
  description = "Project name / resource prefix"
  type        = string
  default     = "legacy-api"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "production"
}

variable "tags" {
  description = "Extra tags applied to all resources"
  type        = map(string)
  default     = {}
}

# --------------------------------------------------------------------- Network
variable "vpc_cidr" {
  description = "CIDR for the ECS VPC (kept distinct from the legacy EC2 VPC)"
  type        = string
  default     = "10.1.0.0/16"
}

variable "azs" {
  description = "Availability zones"
  type        = list(string)
  default     = ["eu-west-2a", "eu-west-2b"]
}

variable "public_subnet_cidrs" {
  description = "Public subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.1.0.0/24", "10.1.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "Private subnet CIDRs (one per AZ)"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.11.0/24"]
}

variable "single_nat_gateway" {
  description = "Use one NAT gateway (cheaper) vs one per AZ (HA)"
  type        = bool
  default     = true
}

# ------------------------------------------------------------------- DNS / TLS
variable "domain_name" {
  description = "FQDN the app is served at, e.g. app.example.com"
  type        = string
}

variable "hosted_zone_name" {
  description = "Route53 hosted zone name, e.g. example.com"
  type        = string
}

# -------------------------------------------------------------------- Images
variable "frontend_image_tag" {
  description = "Tag of the frontend image to run"
  type        = string
  default     = "latest"
}

variable "api_image_tag" {
  description = "Tag of the api image to run"
  type        = string
  default     = "latest"
}

# ------------------------------------------------------------------ Compute
variable "task_cpu" {
  description = "Fargate task CPU units"
  type        = number
  default     = 512
}

variable "task_memory" {
  description = "Fargate task memory (MiB)"
  type        = number
  default     = 1024
}

variable "desired_count" {
  description = "Initial task count"
  type        = number
  default     = 2
}

variable "min_capacity" {
  description = "Autoscaling minimum"
  type        = number
  default     = 2
}

variable "max_capacity" {
  description = "Autoscaling maximum"
  type        = number
  default     = 6
}

# ---------------------------------------------------------------------- RDS
variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_multi_az" {
  description = "Enable RDS Multi-AZ"
  type        = bool
  default     = false
}

variable "db_deletion_protection" {
  description = "Protect the DB from deletion"
  type        = bool
  default     = false
}

# ------------------------------------------------------------------- Alarms
variable "alarm_actions" {
  description = "ARNs (e.g. SNS topic) notified when alarms fire"
  type        = list(string)
  default     = []
}
