variable "name" {
  description = "Namespace/prefix for repositories (e.g. legacy-api)"
  type        = string
}

variable "repository_names" {
  description = "Short names of repositories to create (e.g. [\"frontend\", \"api\"])"
  type        = list(string)
}

variable "max_image_count" {
  description = "Number of tagged images to retain per repository"
  type        = number
  default     = 10
}

variable "force_delete" {
  description = "Allow Terraform to delete repositories that still contain images"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags"
  type        = map(string)
  default     = {}
}
