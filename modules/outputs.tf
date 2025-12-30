output "repositories" {
  description = "The created artifact repositories."
  value       = module.gcp_artifact_registry # Directly outputting the map that main_orchestrator.repositories showed
}

output "iam_bindings" {
  description = "The applied IAM bindings."
  value       = module.project_iam_bindings
}

output "gcp_secrets" {
  description = "The created GCP Secret Manager secrets."
  value       = module.gcp_secrets # Directly outputting the map that main_orchestrator.gcp_secrets showed
}

output "buckets" {
  description = "The created GCS buckets."
  value       = module.gcp_storage
}

output "cloud_run_jobs" {
  description = "The created Cloud Run Jobs."
  value       = module.cloud_run_jobs
}
output "service_accounts" {
  description = "The created Service Accounts."
  value       = google_service_account.service_accounts
}
