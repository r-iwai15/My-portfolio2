# =====================================================
# Hotel Reservation Platform - Type-A: Ultimate Security Edition
# =====================================================

terraform {
  # moved ブロック（1.1+）と本番用 S3 backend の use_lockfile（1.10+）を使用するため。
  required_version = ">= 1.10.0"

  # 本番 S3: terraform init -reconfigure -backend-config=backends/s3.hcl
  backend "local" {
    path = ".state/terraform.tfstate"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

