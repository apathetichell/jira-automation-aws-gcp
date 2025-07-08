##this module is responsible for creating the GCP Workload Identity Federation Pool, Pub/Sub Topic and granting access.


provider "google" {
  project = var.google_project
}

data "google_project" "project" {
}


## Pub/Sub Topic with defaults
resource "google_pubsub_topic" "main" {
  name    = var.google_topic_name
  project = data.google_project.project.project_id
}

## Workload Identity Federation Pool
resource "google_iam_workload_identity_pool" "main" {
  project                   = data.google_project.project.project_id
  workload_identity_pool_id = var.workload_identity_pool
  display_name              = "AWS Lambda Pool"
  description               = "Workload Identity Pool for AWS Lambda"
}

## Workload Identity Federation Provider
resource "google_iam_workload_identity_pool_provider" "main" {
  project                            = data.google_project.project.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.main.workload_identity_pool_id
  workload_identity_pool_provider_id = var.workload_identity_provider
  display_name                       = "AWS Lambda Provider"
  description                        = "OIDC provider for AWS Lambda"


  # AWS account information

  aws {
    account_id = var.account_arn
  }

  # Attribute mapping
  attribute_mapping = {
    "google.subject" = "assertion.arn"
    "attribute.aws_role"="assertion.arn.contains('assumed-role') ? assertion.arn.extract('{account_arn}assumed-role/') + 'assumed-role/' + assertion.arn.extract('assumed-role/{role_name}/') : assertion.arn"
  }
}


## IAM binding for Pub/Sub publisher access - Direct to principal
resource "google_pubsub_topic_iam_binding" "publisher_binding" {
  project = data.google_project.project.project_id
  topic   = google_pubsub_topic.main.name
  role    = "roles/pubsub.publisher"

  members = [
    "principal://iam.googleapis.com/${google_iam_workload_identity_pool.main.name}/subject/arn:aws:sts::${var.account_arn}:assumed-role/${var.aws_gcp_role}/${var.aws_role_session_name}"
  ]
}