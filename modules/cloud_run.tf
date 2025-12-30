module "cloud_run_jobs" {
  source  = "GoogleCloudPlatform/cloud-run/google//modules/job-exec"
  version = "0.13.0"

  for_each = var.cloud_run_jobs_map

  project_id = var.project_id
  name       = each.key
  location   = lookup(each.value, "location", var.location)
  image      = each.value.image

  # Resources
  # Limits
  limits = lookup(each.value, "limits", {
    cpu    = "1000m"
    memory = "512Mi"
  })

  # Env vars
  env_vars        = lookup(each.value, "env_vars", [])
  env_secret_vars = lookup(each.value, "env_secret_vars", [])

  # Volume Mounts
  volumes       = lookup(each.value, "volumes", [])
  volume_mounts = lookup(each.value, "volume_mounts", [])

  # VPC Access
  vpc_access = lookup(each.value, "vpc_access", [])

  # Service Account
  service_account_email = lookup(each.value, "service_account_email", "")

  # Execute immediately after creation?
  exec = lookup(each.value, "execute_job", false)
}
