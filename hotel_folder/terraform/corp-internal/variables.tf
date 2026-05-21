variable "region" {
  type        = string
  description = "AWS region for corporate internal infrastructure."
  default     = "ap-northeast-1"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for resource names (e.g. hotel-corp-internal)."
  default     = "hotel-corp-internal"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR for the internal-only VPC (distinct from customer-facing stacks)."
  default     = "10.1.0.0/16"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Two private subnet CIDRs in different AZs (no direct internet egress by default)."
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}
