

## this module builds the AWS SNS topic and creates the topic policy.


## SNS Topic - standard type, no encryption

resource "aws_sns_topic" "main" {
  name = var.topic_name
}

## SNS Topic Policy - Allow Atlassian automation to publish
resource "aws_sns_topic_policy" "main" {
  arn = aws_sns_topic.main.arn

  policy = jsonencode({
    Version = "2008-10-17"
    Id      = "__default_policy_ID"
    Statement = [
      {
        Sid    = "grant-atlassian-automation-publish"
        Effect = "Allow"
        Principal = {
          AWS = "815843069303"
        }
        Action = [
          "sns:Publish"
        ]
        Resource = aws_sns_topic.main.arn
      }
    ]
  })
}

