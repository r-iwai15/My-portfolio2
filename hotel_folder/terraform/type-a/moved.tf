moved {
  from = aws_vpc.main
  to   = module.vpc.aws_vpc.main
}

moved {
  from = aws_subnet.private_a
  to   = module.vpc.aws_subnet.private_a
}

moved {
  from = aws_subnet.private_c
  to   = module.vpc.aws_subnet.private_c
}

moved {
  from = aws_security_group.lambda_sg
  to   = module.vpc.aws_security_group.lambda_sg
}

moved {
  from = aws_route_table.private
  to   = module.vpc.aws_route_table.private
}

moved {
  from = aws_route_table_association.private_a
  to   = module.vpc.aws_route_table_association.private_a
}

moved {
  from = aws_route_table_association.private_c
  to   = module.vpc.aws_route_table_association.private_c
}
