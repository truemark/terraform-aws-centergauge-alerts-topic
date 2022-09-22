
variable "display_name" {
  description = "Overrides default display name"
  default     = "CenterGaugeAlerts"
  type        = string
}

variable "name" {
  description = "Overrides the default name"
  default     = "CenterGaugeAlerts"
  type        = string
}

variable "tags" {
  description = "Tags to be added to all resources."
  type        = map(string)
}

variable "url" {
  description = "Overrides the default URL"
  default     = "https://alerts.centergauge.com/"
  type        = string
}
