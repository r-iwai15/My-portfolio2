module "sentinel" {
  source = "../modules/sentinel"

  region                     = var.region
  account_id                 = data.aws_caller_identity.current.account_id
  kms_key_arn                = aws_kms_key.main.arn
  waf_ipset_arn              = aws_wafv2_ip_set.sentinel_blacklist.arn
  waf_ipset_id               = aws_wafv2_ip_set.sentinel_blacklist.id
  waf_ipset_name             = aws_wafv2_ip_set.sentinel_blacklist.name
  cognito_user_pool_arn      = aws_cognito_user_pool.hotel.arn
  cognito_user_pool_id       = aws_cognito_user_pool.hotel.id
  chatbot_log_group_name     = module.chatbot_log_group.name
  chatbot_log_group_arn      = module.chatbot_log_group.arn
  sentinel_lambda_zip_path   = var.sentinel_lambda_zip_path
  sentinel_release_zip_path  = var.sentinel_release_zip_path
  dummy_sentinel_zip_path    = data.archive_file.dummy_sentinel.output_path
  dummy_sentinel_source_hash = data.archive_file.dummy_sentinel.output_base64sha256
  name_prefix                = "hotel"
}
