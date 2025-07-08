variable "google_region" {
  description = "region for the gcp project"
  type        = string
}

variable "google_project" {
  description = "Name of the gcp project"
  type        = string
}

variable "workload_identity_provider"{
  description ="Name of the worload identity provider"
  type =string
  default="awspool"
}

variable "workload_identity_pool"{
  description="Name of the workload identity pool"
  type=string
  default="aws-jira"
}

variable "aws_role_session_name"{
  description="Name of the AWS session --- this will be used to create the identity principal in GCP and will be assumed by the Lambda role"
  type=string
  default="jira_sync"
}

variable "aws_gcp_role" {
  description="this is the role which is synched between AWS and GCP"
  type=string
  default="aws_gcp_role_for_jira"
}

variable "aws_lambda_role"{
    description="this is lambda invoker role"
    type=string
    default="aws-gcp-jira-lambda-invoker"




}