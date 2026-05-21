data "aws_caller_identity" "current" {}

data "archive_file" "dummy_send_email" {
  type        = "zip"
  output_path = "${path.module}/dummy_send_email.zip"
  source {
    content  = "exports.handler = async (event) => { return 'ok'; };"
    filename = "index.js"
  }
}

data "archive_file" "dummy_chatbot" {
  type        = "zip"
  output_path = "${path.module}/dummy_chatbot.zip"
  source {
    content  = "exports.handler = async (event) => { return 'ok'; };"
    filename = "index.js"
  }
}

data "archive_file" "dummy_sentinel" {
  type        = "zip"
  output_path = "${path.module}/dummy_sentinel.zip"
  source {
    content  = "def lambda_handler(event, context): pass"
    filename = "main.py"
  }
}
