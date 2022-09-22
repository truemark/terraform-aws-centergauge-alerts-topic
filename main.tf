data "aws_caller_identity" "current" {}

resource "aws_sns_topic" "topic" {
  display_name      = var.display_name
  name              = var.name
  fifo_topic        = false
  kms_master_key_id = aws_kms_key.sns.id
  tags              = var.tags
}

# Cloudwatch cannot write to an SNS topic that is encrypted with the SNS CMK.
# https://aws.amazon.com/premiumsupport/knowledge-center/cloudwatch-receive-sns-for-alarm-trigger/
# Create a key specific to this SNS topic and grant RDS and Cloudwatch 
# publish permissions.

resource "aws_kms_key" "sns" {
  description = "Encrypt SNS topic CenterGaugeAlerts. Managed by Terraform."
  tags        = var.tags
  policy      = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "key-default-1",
    "Statement": [
        {
            "Sid": "Enable IAM User Permissions",
            "Effect": "Allow",
            "Principal": {
                "AWS": "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
            },
            "Action": "kms:*",
            "Resource": "*"
        },
        {
            "Sid": "Allow_CloudWatch_for_CMK",
            "Effect": "Allow",
            "Principal": {
                "Service": [ "cloudwatch.amazonaws.com", "rds.amazonaws.com", "events.amazonaws.com" ]
            },
            "Action": [
                "kms:Decrypt",
                "kms:GenerateDataKey*"
            ],
            "Resource": "*"
        }
    ]
}
POLICY
}

# Create the alias. Without the alias, there is no friendly name in the console
resource "aws_kms_alias" "sns" {
  name          = "alias/${var.name}"
  target_key_id = aws_kms_key.sns.key_id
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.name}DeadLetterQueue"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "subscription" {
  endpoint  = var.url
  protocol  = "https"
  topic_arn = aws_sns_topic.topic.arn
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
      "Action": "sqs:SendMessage",
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
