# 5. AI Agents & Guardrails
# =====================================================
resource "aws_bedrock_guardrail" "main" {
  name                      = "${var.app_name}-guard"
  blocked_input_messaging   = "Security violation detected."
  blocked_outputs_messaging = "Response restricted."

  content_policy_config {
    filters_config {
      type            = "PROMPT_ATTACK"
      input_strength  = "HIGH"
      output_strength = "HIGH"
    }
  }
}

resource "aws_bedrock_guardrail_version" "main" {
  guardrail_arn = aws_bedrock_guardrail.main.guardrail_arn
  description   = "Production version"
}

resource "aws_iam_role" "agent_role" {
  name = "${var.app_name}-agent-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "bedrock.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "agent_policy" {
  name = "agent-core-policy"
  role = aws_iam_role.agent_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/*"
      },
      {
        Effect = "Allow"
        Action = ["lambda:InvokeFunction"]
        Resource = [
          aws_lambda_function.reader.arn,
          aws_lambda_function.reservation.arn
        ]
      }
    ]
  })
}

resource "aws_bedrockagent_agent" "orchestrator" {
  agent_name              = "HotelOrchestrator"
  agent_resource_role_arn = aws_iam_role.agent_role.arn
  foundation_model        = "anthropic.claude-3-sonnet-20240229-v1:0"
  instruction             = "You are a professional hotel agent. Coordinate between sub-agents to fulfill guest requests."

  guardrail_configuration {
    guardrail_identifier = aws_bedrock_guardrail.main.guardrail_id
    guardrail_version    = aws_bedrock_guardrail_version.main.version
  }
}

resource "aws_bedrockagent_agent_action_group" "reader_action" {
  agent_id                   = aws_bedrockagent_agent.orchestrator.agent_id
  agent_version              = "DRAFT"
  action_group_name          = "ReservationReader"
  description                = "Reads hotel reservation data from the database."
  skip_resource_in_use_check = true

  action_group_executor {
    lambda = aws_lambda_function.reader.arn
  }

  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info    = { title = "Reader API", version = "1.0.0" }
      paths = {
        "/reservation" = {
          get = {
            description = "Get reservation details"
            responses   = { "200" = { description = "OK" } }
          }
        }
      }
    })
  }
}

resource "aws_bedrockagent_agent_action_group" "reservation_action" {
  agent_id                   = aws_bedrockagent_agent.orchestrator.agent_id
  agent_version              = "DRAFT"
  action_group_name          = "ReservationWriter"
  description                = "Creates or updates hotel reservations (execution layer)."
  skip_resource_in_use_check = true

  action_group_executor {
    lambda = aws_lambda_function.reservation.arn
  }

  api_schema {
    payload = jsonencode({
      openapi = "3.0.0"
      info    = { title = "Writer API", version = "1.0.0" }
      paths = {
        "/reservation" = {
          post = {
            description = "Create or update reservation"
            responses   = { "200" = { description = "OK" } }
          }
        }
      }
    })
  }
}

resource "null_resource" "prepare_agent" {
  depends_on = [
    aws_bedrockagent_agent.orchestrator,
    aws_bedrockagent_agent_action_group.reader_action,
    aws_bedrockagent_agent_action_group.reservation_action
  ]

  triggers = {
    agent_id = aws_bedrockagent_agent.orchestrator.agent_id
  }

  provisioner "local-exec" {
    command = <<EOT
      aws bedrock-agent prepare-agent \
        --agent-id ${aws_bedrockagent_agent.orchestrator.agent_id} \
        --region ${var.region}
    EOT
  }
}

# 本番用エイリアス（interface が InvokeAgent で参照する）
resource "aws_bedrockagent_agent_alias" "prod" {
  agent_id         = aws_bedrockagent_agent.orchestrator.agent_id
  agent_alias_name = "prod"
  description      = "Production alias for HotelOrchestrator"
  depends_on       = [null_resource.prepare_agent]
}

# =====================================================
