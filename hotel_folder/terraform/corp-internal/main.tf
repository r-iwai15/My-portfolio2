# =====================================================
# Corporate internal infrastructure (separate state from type-a)
# Session Manager / private VPC endpoints / internal artifact bucket
# =====================================================

terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket       = "YOUR-TERRAFORM-STATE-BUCKET"
    key          = "hotel-corp-internal/terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
