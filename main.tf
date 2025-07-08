provider "google" {
  project     = var.google_project
  region      = var.google_region
}

data "google_project" "project" {
}



# Get current AWS account ID
data "aws_caller_identity" "current" {}

# Use it in locals or resources
locals {
  account_id = data.aws_caller_identity.current.account_id
}

module "gcp_resources" {
  source = "./gcp-resources"


  account_arn=local.account_id
  aws_gcp_role=var.aws_gcp_role
  aws_role_session_name=var.aws_role_session_name

  google_project=var.google_project
  google_region=var.google_region
  google_topic_name="jira_topic2"
  workload_identity_pool=var.workload_identity_pool
  workload_identity_provider=var.workload_identity_provider

}

module "aws_resources" {
  source ="./aws-resources"
  
  topic_name="jira-automation-sync2"


}


module lambda {
  source="./lambda"
  
  account_arn=local.account_id
  aws_gcp_role=var.aws_gcp_role
  aws_lambda_invoker_role=var.aws_lambda_role
  aws_role_session_name=var.aws_role_session_name
  ecr_repo_name="jira-lambda-repo-cleaned"
  gcp_project_id=var.google_project
  gcp_project_number=data.google_project.project.number
  lambda_name="cleaned_jira_aws_function"
  pool_id=var.workload_identity_pool
  provider_id=var.workload_identity_provider
  pubsubtopic_name=module.gcp_resources.pubsub_topic_name
  topic_arn=module.aws_resources.sns_topic_arn




}
