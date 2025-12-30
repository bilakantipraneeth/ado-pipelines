# dev/data.tf

# 1. Fetch Secrets 
# NOTE: We remove the explicit depends_on here to allow these blocks to be used 
# in the module inputs without causing a circular dependency cycle.
data "google_secret_manager_secret_version" "lr_access_key" {
  secret  = "liveramp-access-key-id"
  project = var.gcp_project_id
  version = "latest"
}

data "google_secret_manager_secret_version" "lr_secret_key" {
  secret  = "liveramp-secret-access-key"
  project = var.gcp_project_id
  version = "latest"
}

data "google_secret_manager_secret_version" "lr_account_id" {
  secret  = "liveramp-account-id"
  project = var.gcp_project_id
  version = "latest"
}

# 2. Dynamic Bucket Lookup
data "google_storage_bucket" "managed_buckets" {
  for_each = local.buckets
  name     = each.key
}

# 3. Service Account Lookup
data "google_service_account" "liveramp_sa" {
  account_id = "liveramp-encoder-sa"
  project    = var.gcp_project_id
}

# 4. Artifact Registry Lookup
data "google_artifact_registry_repository" "my_repo" {
  location      = var.gcp_region
  repository_id = "my-first-repo"
  project       = var.gcp_project_id
}
