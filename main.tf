data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "topic" {
  display_name      = var.display_name
  name              = var.name
  fifo_topic        = false
  kms_master_key_id = var.kms_key_arn
  tags              = var.tags
}

resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.topic.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

data "aws_iam_policy_document" "sns_topic_policy" {
  policy_id = "centergauge_sns_policy"
  statement {
    actions = [
      "sns:Subscribe",
      "sns:SetTopicAttributes",
      "sns:RemovePermission",
      "sns:Receive",
      "sns:Publish",
      "sns:ListSubscriptionsByTopic",
      "sns:GetTopicAttributes",
      "sns:DeleteTopic",
      "sns:AddPermission",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"

      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = ["*"]
    }
    resources = [
      aws_sns_topic.topic.arn,
    ]
    sid = "centergauge_aws_default"
  }

  statement {
    actions = [
      "sns:Publish",
      "sns:GetTopicAttributes"
    ]
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    resources = [
      aws_sns_topic.topic.arn,
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"

      values = [
        data.aws_caller_identity.current.account_id,
      ]
    }
    sid = "centergauge_services_default"
  }
}


resource "aws_sqs_queue" "dlq" {
  name = "${var.name}DeadLetterQueue"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "subscription" {
  endpoint        = var.url
  protocol        = "https"
  topic_arn       = aws_sns_topic.topic.arn
  delivery_policy = jsonencode({
    "healthyRetryPolicy" : {
      "numRetries" : 10,
      "numNoDelayRetries" : 0,
      "minDelayTarget" : 30,
      "maxDelayTarget" : 120,
      "numMinDelayRetries" : 3,
      "numMaxDelayRetries" : 0,
      "backoffFunction" : "linear"
    }
  })
  redrive_policy = jsonencode({
    "deadLetterTargetArn" : aws_sqs_queue.dlq.arn
  })
}

resource "aws_sqs_queue_policy" "dlq" {
  queue_url = aws_sqs_queue.dlq.id
  policy    = <<POLICY
{
  "Version": "2012-10-17",
  "Id": "sqspolicy",
  "Statement": [
    {
      "Sid": "First",
      "Effect": "Allow",
      "Principal": "*",
      "Action": ["sqs:SendMessage"],
      "Resource": "${aws_sqs_queue.dlq.arn}",
      "Condition": {
        "ArnEquals": {
          "aws:SourceArn": "${aws_sns_topic.topic.arn}"
        }
      }
    }
  ]
}
POLICY
}
