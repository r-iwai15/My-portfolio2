variable "region" {
  type        = string
  description = "AWS region for Type-B Enterprise internal footprint."
  default     = "ap-northeast-1"
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix (e.g. corp-internal-type-b)."
  default     = "corp-internal-type-b"
}

variable "vpc_cidr" {
  type        = string
  description = "Placeholder workload VPC CIDR (expand to TGW hub-spoke in production)."
  default     = "10.3.0.0/16"
}
