# =====================================================
# 0. Data Sources & Variables
# =====================================================
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_prefix_list" "dynamodb" {
  name = "com.amazonaws.${var.region}.dynamodb"
}

data "archive_file" "dummy" {
  type        = "zip"
  output_path = "${path.module}/dummy_agile_final.zip"
  source {
    content  = "exports.handler = async (event) => { return { statusCode: 200, body: 'ok' }; };"
    filename = "index.js"
  }
}

