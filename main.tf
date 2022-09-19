resource "aws_sns_topic" "topic" {
  display_name      = var.display_name
  name              = var.name
  fifo_topic        = false
  kms_master_key_id = aws_kms_key.sns.id
}

# Cloudwatch cannot write to an SNS topic that is encrypted with the SNS CMK.
# https://aws.amazon.com/premiumsupport/knowledge-center/cloudwatch-receive-sns-for-alarm-trigger/
# Create a key specific to this SNS topic and grant RDS and Cloudwatch 
# publish permissions.

resource "aws_kms_key" "sns" {
  description = "Encrypt SNS topic CenterGaugeAlerts. Managed by Terraform."
}

resource "aws_iam_role" "kms_sns_key" {
  name               = "${var.name}Decrypt"
  assume_role_policy = data.aws_iam_policy_document.assume_kms_sns_key.json
}

# This policy defines which AWS services can assume the role defined above. 
data "aws_iam_policy_document" "assume_kms_sns_key" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["cloudwatch.amazonaws.com", "rds.amazonaws.com"]
    }
  }
}

resource "aws_iam_policy" "kms_sns_key" {
  name        = "${var.name}Decrypt"
  description = "Encrypt SNS topic CenterGaugeAlerts. Managed by Terraform."
  policy      = data.aws_iam_policy_document.kms_sns_key.json
}

data "aws_iam_policy_document" "kms_sns_key" {
  statement {
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.sns.arn]
  }
}

resource "aws_iam_policy_attachment" "kms_sns_key" {
  name       = "${var.name}Decrypt"
  roles      = [aws_iam_role.kms_sns_key.name]
  policy_arn = aws_iam_policy.kms_sns_key.arn
}

resource "aws_sqs_queue" "dlq" {
  name = "${var.name}DeadLeterQueue"
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
