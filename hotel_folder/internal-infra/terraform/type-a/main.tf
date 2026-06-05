# Type-A Internal: Cloud-Native Edition（先端・自律型）
# Verified Access・Bedrock KB・Service Catalog 等はアカウント設定・証明書が必要なため
# 段階的に追加する。ここでは「閉域 VPC + PrivateLink 基盤」を Terraform 化。

terraform {
  # use_lockfile（S3 ネイティブステートロック）は Terraform 1.10 以降の機能。
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "YOUR-TERRAFORM-STATE-BUCKET"
    key          = "internal-infra/type-a/terraform.tfstate"
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
