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

variable "bedrock_agent_alias_id" {
  description = "Bedrock Agent alias ID for interface Lambda InvokeAgent call."
  type        = string
  default     = "prod"
}
