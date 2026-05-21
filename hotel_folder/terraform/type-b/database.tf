# 9. RDS & Secrets Manager
# =====================================================
resource "aws_db_subnet_group" "main" {
  name       = "hotel-innovative-db-subnet"
  subnet_ids = module.vpc.db_subnet_ids
  tags = {
    Name = "hotel-innovative-db-subnet"
  }
}

resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db_credentials" {
  name                    = "hotel-innovative-db-credentials"
  recovery_window_in_days = 7
  kms_key_id              = aws_kms_key.main.id
  tags = {
    Name = "hotel-innovative-db-secret"
  }
}

resource "aws_secretsmanager_secret_version" "db_credentials_val" {
  secret_id = aws_secretsmanager_secret.db_credentials.id
  secret_string = jsonencode({
    username = "admin"
    password = random_password.db_password.result
    dbname   = "hotel_reservation"
  })
}

resource "aws_db_instance" "main" {
  identifier                   = "hotel-innovative-db"
  engine                       = "mysql"
  engine_version               = "8.0"
  instance_class               = "db.t3.small"
  storage_type                 = "gp3"
  allocated_storage            = 50
  multi_az                     = true
  storage_encrypted            = true
  kms_key_id                   = aws_kms_key.main.arn
  backup_retention_period      = 7
  username                     = "admin"
  password                     = random_password.db_password.result
  db_subnet_group_name         = aws_db_subnet_group.main.name
  vpc_security_group_ids       = [aws_security_group.db.id]
  performance_insights_enabled = true
  skip_final_snapshot          = false
  final_snapshot_identifier    = "hotel-innovative-db-final-snapshot"
  deletion_protection          = true # [FIX] 削除保護を有効化

  tags = {
    Name = "hotel-innovative-db"
  }
}

resource "aws_serverlessapplicationrepository_cloudformation_stack" "rotate_db_creds" {
  name           = "hotel-db-rotation"
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSMySQLRotationSingleUser"
  capabilities   = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  parameters = {
    endpoint            = "https://secretsmanager.${var.region}.amazonaws.com"
    functionName        = "hotel-db-rotation-lambda"
    vpcSecurityGroupIds = aws_security_group.lambda.id
    vpcSubnetIds        = "${module.vpc.subnet_lambda_1a_id},${module.vpc.subnet_lambda_1c_id}"
  }
}

resource "aws_secretsmanager_secret_rotation" "db_rotation" {
  secret_id           = aws_secretsmanager_secret.db_credentials.id
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.rotate_db_creds.outputs.RotationLambdaARN

  rotation_rules {
    automatically_after_days = 30
  }
  depends_on = [aws_db_instance.main]
}

# =====================================================
