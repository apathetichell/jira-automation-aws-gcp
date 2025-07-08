# outputs.tf

output "pubsub_topic_name" {
  description = "Name of the created Pub/Sub topic"
  value       = google_pubsub_topic.main.name
}

output "workload_identity_pool_name" {
  description = "Name of the workload identity pool"
  value       = google_iam_workload_identity_pool.main.name
}

output "workload_identity_provider_name" {
  description = "Full name of the workload identity provider"
  value       = google_iam_workload_identity_pool_provider.main.name
}

output "principal_identifier" {
  description = "Principal identifier for direct IAM binding"
  value       = "principal://iam.googleapis.com/${google_iam_workload_identity_pool.main.name}/subject/${var.aws_role_session_name}"
}