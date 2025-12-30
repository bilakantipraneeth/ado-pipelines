module "main_orchestrator" {
  source = "../modules"

  project_id           = var.gcp_project_id
  location             = var.gcp_region
  artifacts_map        = local.artifacts
  iam_bindings_map     = local.iam_bindings_to_create
  secrets_map          = local.secrets_to_create
  buckets_map          = local.buckets
  cloud_run_jobs_map   = local.cloud_run_jobs
  service_accounts_map = local.service_accounts
}
