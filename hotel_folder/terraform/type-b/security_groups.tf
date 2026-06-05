# 2. セキュリティグループ
# =====================================================
data "aws_ec2_managed_prefix_list" "cloudfront" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

resource "aws_security_group" "alb" {
  name   = "hotel-innovative-alb-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
    description     = "HTTPS from CloudFront only"
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront.id]
    description     = "HTTP redirect from CloudFront only"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "alb-sg"
  }
}

resource "aws_security_group" "app" {
  name   = "hotel-innovative-app-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
    description     = "Only from ALB"
  }

  # App層は内部通信のみに限定（VPC内HTTPS）
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "HTTPS only within VPC"
  }

  tags = {
    Name = "app-sg"
  }
}

resource "aws_security_group" "lambda" {
  name   = "hotel-innovative-lambda-sg"
  vpc_id = module.vpc.vpc_id

  # このSGはインターフェース型VPCエンドポイントにもアタッチされる。
  # エンドポイントENIがVPC内（Lambda/EC2 app）からの接続を受けるにはインバウンド443が必須。
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "HTTPS to interface VPC endpoints from within the VPC"
  }

  # VPC Endpoint への HTTPS
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
    description = "HTTPS to VPC endpoints only"
  }

  tags = {
    Name = "lambda-sg"
  }
}

# LLMサーバー専用セキュリティグループ
resource "aws_security_group" "llm" {
  name   = "hotel-innovative-llm-sg"
  vpc_id = module.vpc.vpc_id

  # モデルダウンロード用（初回起動時のみ必要）
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for model download from HuggingFace"
  }

  tags = {
    Name = "llm-sg"
  }
}

resource "aws_security_group_rule" "lambda_to_llm_egress" {
  type                     = "egress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda.id
  source_security_group_id = aws_security_group.llm.id
  description              = "vLLM API to LLM server"
}

resource "aws_security_group_rule" "llm_from_lambda_ingress" {
  type                     = "ingress"
  from_port                = 8000
  to_port                  = 8000
  protocol                 = "tcp"
  security_group_id        = aws_security_group.llm.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "vLLM API from Lambda only"
}

resource "aws_security_group" "db" {
  name   = "hotel-innovative-db-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id, aws_security_group.lambda.id]
    description     = "MySQL from App and Lambda only"
  }

  # DLP: egress ルールを一切定義しないことで全アウトバウンドを拒否する。
  # （cidr_blocks=[] の空 egress は apply 時にエラーになるため定義しない）

  tags = {
    Name = "db-sg"
  }
}

resource "aws_security_group_rule" "app_to_db_egress" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  security_group_id        = aws_security_group.app.id
  source_security_group_id = aws_security_group.db.id
  description              = "MySQL to DB only"
}

# =====================================================
