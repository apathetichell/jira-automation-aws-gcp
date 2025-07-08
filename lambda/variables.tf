# Variable for ECR repo name


variable "ecr_repo_name" {
  description = "Name of the ECR repository"
  type        = string
  default     = "my-lambda-function"
}

# Variable for ECR repo name

variable "pool_id" {
  description = "Name of the workload identity pool"
  type        = string
}

variable "aws_role_session_name" {
    description ="this will be mapped to the sub field to create a specific GCP principal"
    type = string
    default="jira-sync"

}

variable "account_arn" {
    description ="this is the aws account"
    type = string

}

variable "aws_gcp_role" {
  description="this is the AWS role which will be granted access to GCP resources --- it may or may not be the native lambda invoker ---> but the lambda invoker must have permission to assume this role"
  type= string
}

variable "lambda_name" {
    description="this is the name of the function which creates the gcp session token and syncs to pub/sub"
    type=string
    default="gcp_jira_sync"

}

variable "aws_lambda_invoker_role"{
    description="this is the name of the role which invokes the lambda it will have a random number appended to it."
    type=string
    default="lambda_invoker"

}


variable "provider_id"{
    description="this is the workload identity federation provider id from GCP"
    type=string
}

variable "pubsubtopic_name" {
    description="this is the gcp pub sub topic name"
    type=string
}

variable "gcp_project_number"{
    description="this is the gcp proect number"
    type=string
}

variable "topic_arn" {
  description = "topic name for the SNS topic"
  type        = string
}

variable "gcp_project_id"{
    description="this is the name/id of your gcp project"
    type=string
}