variable "region" {
  type        = string
  description = "AWS region for Type-A Cloud-Native internal footprint."
  default     = "ap-northeast-1"
}

variable "name_prefix" {
  type        = string
  description = "Resource name prefix."
  default     = "corp-internal-type-a"
}

variable "vpc_cidr" {
  type        = string
  description = "Private-only VPC (NO IGW). Verified Access attaches in full design."
  default     = "10.4.0.0/16"
}
