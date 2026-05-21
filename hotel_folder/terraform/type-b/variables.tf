variable "region" {
  default = "ap-northeast-1"
}

variable "domain_name" {
  default = "innovative.example-hotel.com"
}

variable "ops_email" {
  default = "ops@example.com"
}

variable "from_email" {
  default = "noreply@example.com"
}

variable "lambda_zip_path" {
  default = "../../lambda/send_email.zip"
}

variable "chatbot_lambda_zip_path" {
  default = "../../lambda/chatbot.zip"
}

variable "sentinel_lambda_zip_path" {
  default = "../../lambda/sentinel_executioner.zip"
}

variable "sentinel_release_zip_path" {
  default = "../../lambda/sentinel_release.zip"
}
