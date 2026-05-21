variable "project" {
  description = "Project name"
  type        = string
  default     = "petclinic"
}

variable "environment" {
  description = "Environment name (dev or prod)"
  type        = string
}

variable "service_names" {
  description = "List of service names — one ECR repository is created per service"
  type        = list(string)
}

variable "image_tag_mutability" {
  description = "Tag mutability setting: MUTABLE for dev, IMMUTABLE for prod"
  type        = string
  default     = "MUTABLE"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
