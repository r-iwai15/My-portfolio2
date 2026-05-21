# 7. EC2 Auto Scaling
# =====================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# Qwen2.5-7B用 Deep Learning AMI (GPU対応)
data "aws_ami" "deep_learning" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["Deep Learning OSS Nvidia Driver AMI GPU PyTorch*Amazon Linux 2023*"]
  }
}

# LLMサーバー用 IAM ロール
resource "aws_iam_role" "llm_role" {
  name = "hotel-innovative-llm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "llm_ssm" {
  role       = aws_iam_role.llm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "llm" {
  name = "hotel-innovative-llm-profile"
  role = aws_iam_role.llm_role.name
}

# Qwen2.5-7B + vLLM サーバー (g5.xlarge: A10G GPU 24GB)
resource "aws_instance" "llm_server" {
  ami                    = data.aws_ami.deep_learning.id
  instance_type          = "g5.xlarge"
  subnet_id              = module.vpc.subnet_llm_1a_id
  vpc_security_group_ids = [aws_security_group.llm.id]
  iam_instance_profile   = aws_iam_instance_profile.llm.name

  root_block_device {
    volume_size           = 100 # モデルファイル用に100GB確保
    volume_type           = "gp3"
    encrypted             = true
    kms_key_id            = aws_kms_key.main.arn
    delete_on_termination = true
  }

  # IMDSv2強制
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  # 起動時にQwen2.5-7BをvLLMでサーブ
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # vLLMのインストール
    pip install vllm huggingface_hub

    # Qwen2.5-7B-Instructをダウンロードしてサーブ
    # 初回起動時のみダウンロード発生（約15GB）
    cat > /etc/systemd/system/vllm.service << 'SERVICE'
    [Unit]
    Description=vLLM Server - Qwen2.5-7B
    After=network.target

    [Service]
    Type=simple
    Restart=always
    RestartSec=10
    ExecStart=/usr/bin/python3 -m vllm.entrypoints.openai.api_server \
      --model Qwen/Qwen2.5-7B-Instruct \
      --host 0.0.0.0 \
      --port 8000 \
      --max-model-len 4096 \
      --dtype auto
    StandardOutput=journal
    StandardError=journal

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable vllm
    systemctl start vllm
  EOF
  )

  tags = {
    Name = "hotel-innovative-llm-server"
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "hotel-innovative-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.small"

  iam_instance_profile {
    name = aws_iam_instance_profile.app.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.app.id]
  }

  # [FIX] IMDSv2を強制（SSRF経由のメタデータ漏洩を防止）
  metadata_options {
    http_tokens   = "required"
    http_endpoint = "enabled"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hotel Reservation - Innovative</h1>" > /var/www/html/health
  EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "hotel-innovative-app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  vpc_zone_identifier = module.vpc.app_subnet_ids
  desired_capacity    = 2
  min_size            = 2
  max_size            = 10

  launch_template {
    id      = aws_launch_template.app.id
    version = tostring(aws_launch_template.app.latest_version)
  }

  target_group_arns         = [aws_lb_target_group.app.arn]
  health_check_type         = "ELB"
  health_check_grace_period = 300

  tag {
    key                 = "Name"
    value               = "hotel-innovative-asg"
    propagate_at_launch = true
  }
}

# =====================================================
# 8. SQS + Lambda
