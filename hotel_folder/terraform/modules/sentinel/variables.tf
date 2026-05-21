variable "region" {
  type = string
}

variable "account_id" {
  type = string
}

variable "kms_key_arn" {
  type = string
}

variable "waf_ipset_arn" {
  type = string
}

variable "waf_ipset_id" {
  type = string
}

variable "waf_ipset_name" {
  type = string
}

variable "cognito_user_pool_arn" {
  type = string
}

variable "cognito_user_pool_id" {
  type = string
}

variable "chatbot_log_group_name" {
  type = string
}

variable "chatbot_log_group_arn" {
  type = string
}

variable "sentinel_lambda_zip_path" {
  type = string
}

variable "sentinel_release_zip_path" {
  type = string
}

variable "dummy_sentinel_zip_path" {
  type = string
}

variable "dummy_sentinel_source_hash" {
  type = string
}

variable "name_prefix" {
  type    = string
  default = "hotel"
}
