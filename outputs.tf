output "topic_arn" {
  value = aws_sns_topic.topic.arn
}

output "topic_id" {
  value = aws_sns_topic.topic.id
}

output "topic_subscription_arn" {
  value = aws_sns_topic_subscription.subscription.arn
}

output "topic_subscription_id" {
  value = aws_sns_topic_subscription.subscription.id
}
