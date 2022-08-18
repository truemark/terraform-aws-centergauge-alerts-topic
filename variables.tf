variable "display_name" {
  description = "Overrides default display name"
  default = "CenterGaugeAlerts"
  type = string
}

variable "name" {
  description = "Overrides the default name"
  default = "CenterGaugeAlerts"
  type = string
}

variable "url" {
  description = "Overrides the default URL"
  default = "https://alerts.centergauge.com/"
  type = string
}

variable "kms_master_key_id" {
  description = "KMS Key to use for enryption"
  default = "alias/aws/sns"
  type = string
}




