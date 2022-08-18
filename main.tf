resource "aws_sns_topic" "topic" {
  display_name = var.display_name
  name = var.name
  fifo_topic = false
  kms_master_key_id = var.kms_master_key_id
}

resource "aws_sns_topic_subscription" "subscription" {
  endpoint  = var.url
  protocol  = "https"
  topic_arn = aws_sns_topic.topic.arn
}
