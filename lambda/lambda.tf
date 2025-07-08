

resource "aws_ecr_repository" "lambda_repo" {
  name  = var.ecr_repo_name
}


# get authorization credentials to push to ecr
data "aws_ecr_authorization_token" "token" {}

# configure docker provider
provider "docker" {
  registry_auth {
      address = data.aws_ecr_authorization_token.token.proxy_endpoint
      username = data.aws_ecr_authorization_token.token.user_name
      password  = data.aws_ecr_authorization_token.token.password
    }
}





# Locals to determine final role names
locals {


 repo_url = aws_ecr_repository.lambda_repo.repository_url

}



#this is the lambda role. it must will the aws_gcp_role and use the session name
resource "aws_iam_role" "lambda_invoker_updated" {
  name  = var.aws_lambda_invoker_role

  assume_role_policy = jsonencode({

    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
}
  
  )
}

# Create GCP Role ---> this is the role which is synched to GCP's Workload Identity Federation
resource "aws_iam_role" "aws_gcp_role" {
  name  = var.aws_gcp_role
  assume_role_policy = jsonencode({

    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_invoker_updated.arn
        }
      }
    ]
  }
  )
}












# this will map the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_invoker_updated.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}


# Updated Docker image triggers
resource "docker_image" "lambda_image" {
  name = var.ecr_repo_name
  build {
    context = "./lambda"
    dockerfile = "Dockerfile"
    tag = ["${local.repo_url}:latest"]
  }
  triggers = {
    dockerfile = filemd5("./lambda/Dockerfile")
    requirements = filemd5("./lambda/pyproject.toml")
    handler_code = filemd5("./lambda/src/index.py")
  }
}


resource "docker_registry_image" "lambda_image_push" {
  name = "${local.repo_url}:latest"
  
  depends_on = [docker_image.lambda_image]
}



# Lambda function using the repo URL
resource "aws_lambda_function" "jira-sync-lambda" {
  function_name = var.lambda_name
  role         = aws_iam_role.lambda_invoker_updated.arn
  timeout      = 30
  memory_size = 512

  
  package_type = "Image"
  image_uri    = "${local.repo_url}:latest"
  
 environment {
  variables = {
    project_number=var.gcp_project_number,
    pool_id = var.pool_id
    provider_id = var.provider_id
    role_arn = aws_iam_role.aws_gcp_role.arn
    role_session_name = var.aws_role_session_name
    pubsub_topic_name=var.pubsubtopic_name
    gcp_project_id=var.gcp_project_id

}
}
}




resource "aws_lambda_permission" "allow_sns" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.jira-sync-lambda.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = var.topic_arn
}


resource "aws_sns_topic_subscription" "lambda_subscription" {
  topic_arn = var.topic_arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.jira-sync-lambda.arn
}