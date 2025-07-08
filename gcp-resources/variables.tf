variable "google_project" {
  description = "google project name"
  type        = string
}

variable "google_region" {
  description = "google region"
  type        = string
}

variable "google_topic_name" {
  description = "name of gcp pub/sub topic"
  type        = string
  default = "jira_topic"
}


variable "workload_identity_provider" {
  description = "workload_identity_provider_name"
  type        = string
  default     = "AWS"
}


variable "workload_identity_pool" {
    description ="workload identity pool name"
    type = string
    default = "AWS-Lambda-Pool"
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

variable "aws_gcp_role"{
  description="this is the AWS role which will be granted access to GCP resources --- it may or may not be the native lambda invoker ---> but the lambda invoker must have permission to assume this role"
  type= string
}
