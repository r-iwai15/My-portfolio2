variable "region" {
  default = "ap-northeast-1"
}

variable "app_name" {
  default = "hotel-agile-ai"
}

variable "reader_zip_path" {
  default = "../../lambda/reader.zip"
}

variable "interface_zip_path" {
  default = "../../lambda/interface.zip"
}

variable "reservation_zip_path" {
  default = "../../lambda/reservation.zip"
}

# NOTE: interface Lambda の BEDROCK_AGENT_ALIAS_ID は
# aws_bedrockagent_agent_alias.prod.agent_alias_id（AWS 自動採番の ID）を
# 直接参照する（lambda.tf 参照）。エイリアス「名」とは別物なので変数化しない。
