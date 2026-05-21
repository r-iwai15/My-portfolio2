# Type-B Internal: Enterprise Edition（伝統・統制型）
# 完全なマルチアカウント（管理/セキュリティ/ワークロード）・Transit Gateway・
# AD Connector は既存ディレクトリと事前条件が必要なため、本ディレクトリでは
# 検証可能な「基盤のたたき」を Terraform 化し、残りは段階的に追加する。

terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket       = "YOUR-TERRAFORM-STATE-BUCKET"
    key          = "internal-infra/type-b/terraform.tfstate"
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
