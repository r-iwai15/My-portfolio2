# State migration: root resources -> child modules (Terraform 1.1+)
# Run `terraform plan` after upgrade; expect no destroy/recreate if state matches.

moved {
  from = aws_vpc.main
  to   = module.vpc.aws_vpc.main
}

moved {
  from = aws_internet_gateway.gw
  to   = module.vpc.aws_internet_gateway.gw
}

moved {
  from = aws_subnet.public_1a
  to   = module.vpc.aws_subnet.public_1a
}

moved {
  from = aws_subnet.public_1c
  to   = module.vpc.aws_subnet.public_1c
}

moved {
  from = aws_eip.nat_1a
  to   = module.vpc.aws_eip.nat_1a
}

moved {
  from = aws_nat_gateway.nat_1a
  to   = module.vpc.aws_nat_gateway.nat_1a
}

moved {
  from = aws_subnet.app_1a
  to   = module.vpc.aws_subnet.app_1a
}

moved {
  from = aws_subnet.app_1c
  to   = module.vpc.aws_subnet.app_1c
}

moved {
  from = aws_subnet.db_1a
  to   = module.vpc.aws_subnet.db_1a
}

moved {
  from = aws_subnet.db_1c
  to   = module.vpc.aws_subnet.db_1c
}

moved {
  from = aws_subnet.lambda_1a
  to   = module.vpc.aws_subnet.lambda_1a
}

moved {
  from = aws_subnet.lambda_1c
  to   = module.vpc.aws_subnet.lambda_1c
}

moved {
  from = aws_subnet.llm_1a
  to   = module.vpc.aws_subnet.llm_1a
}

moved {
  from = aws_route_table.public
  to   = module.vpc.aws_route_table.public
}

moved {
  from = aws_route_table.private
  to   = module.vpc.aws_route_table.private
}

moved {
  from = aws_route_table_association.llm_a
  to   = module.vpc.aws_route_table_association.llm_a
}

moved {
  from = aws_route_table_association.pub_a
  to   = module.vpc.aws_route_table_association.pub_a
}

moved {
  from = aws_route_table_association.pub_c
  to   = module.vpc.aws_route_table_association.pub_c
}

moved {
  from = aws_route_table_association.app_a
  to   = module.vpc.aws_route_table_association.app_a
}

moved {
  from = aws_route_table_association.app_c
  to   = module.vpc.aws_route_table_association.app_c
}

moved {
  from = aws_route_table_association.db_a
  to   = module.vpc.aws_route_table_association.db_a
}

moved {
  from = aws_route_table_association.db_c
  to   = module.vpc.aws_route_table_association.db_c
}

moved {
  from = aws_route_table_association.lam_a
  to   = module.vpc.aws_route_table_association.lam_a
}

moved {
  from = aws_route_table_association.lam_c
  to   = module.vpc.aws_route_table_association.lam_c
}

moved {
  from = aws_dynamodb_table.blocked_ips
  to   = module.sentinel.aws_dynamodb_table.blocked_ips
}

moved {
  from = aws_iam_role.sentinel_executioner
  to   = module.sentinel.aws_iam_role.sentinel_executioner
}

moved {
  from = aws_iam_role_policy.sentinel_permissions
  to   = module.sentinel.aws_iam_role_policy.sentinel_permissions
}

moved {
  from = aws_lambda_function.sentinel_executioner
  to   = module.sentinel.aws_lambda_function.sentinel_executioner
}

moved {
  from = aws_lambda_permission.allow_cloudwatch_sentinel
  to   = module.sentinel.aws_lambda_permission.allow_cloudwatch_sentinel
}

moved {
  from = aws_cloudwatch_log_subscription_filter.sentinel_trigger
  to   = module.sentinel.aws_cloudwatch_log_subscription_filter.sentinel_trigger
}

moved {
  from = aws_lambda_function.sentinel_release
  to   = module.sentinel.aws_lambda_function.sentinel_release
}

moved {
  from = aws_cloudwatch_event_rule.sentinel_release_schedule
  to   = module.sentinel.aws_cloudwatch_event_rule.sentinel_release_schedule
}

moved {
  from = aws_cloudwatch_event_target.sentinel_release_target
  to   = module.sentinel.aws_cloudwatch_event_target.sentinel_release_target
}

moved {
  from = aws_lambda_permission.allow_eventbridge_release
  to   = module.sentinel.aws_lambda_permission.allow_eventbridge_release
}
