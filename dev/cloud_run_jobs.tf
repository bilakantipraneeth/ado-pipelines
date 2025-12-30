locals {
  # Construct the image URL using predictable strings to avoid dependency cycles
  image_url = "${var.gcp_region}-docker.pkg.dev/${var.gcp_project_id}/my-first-repo/vault-app:latest"

  cloud_run_jobs = {
    "liveramp-encoder" = {
      location = var.gcp_region

      # SEQUENCING GATE: This is where we force the Cloud Run job to wait for the bootstrapper
      image = "${null_resource.initial_image_bootstrapper.id != "" ? local.image_url : local.image_url}"

      limits = {
        cpu    = "2000m"
        memory = "2Gi"
      }

      env_vars = [
        {
          name = "LR_VAULT_INPUT"
          # USE VARIABLES DIRECTLY for bucket names to allow for initial creation.
          # Using data blocks here would fail if the bucket doesn't exist yet.
          value = "gs://${var.input_bucket_name}"
        },
        {
          name = "LR_VAULT_OUTPUT"
          # USE VARIABLES DIRECTLY for bucket names to allow for initial creation.
          # Using data blocks here would fail if the bucket doesn't exist yet.
          value = "gs://${var.output_bucket_name}"
        },
        {
          name  = "LR_VAULT_GCP_PROJECT_NAME"
          value = var.gcp_project_id
        },
        {
          name  = "LR_VAULT_LOCALE"
          value = "us"
        },
        {
          name  = "LR_VAULT_MODE"
          value = "task"
        }
      ]

      env_secret_vars = [
        {
          name = "LR_VAULT_LR_AWS_ACCESS_KEY_ID"
          value_source = [
            {
              secret_key_ref = {
                secret  = data.google_secret_manager_secret_version.lr_access_key.secret
                version = data.google_secret_manager_secret_version.lr_access_key.version
              }
            }
          ]
        },
        {
          name = "LR_VAULT_LR_AWS_SECRET_ACCESS_KEY"
          value_source = [
            {
              secret_key_ref = {
                secret  = data.google_secret_manager_secret_version.lr_secret_key.secret
                version = data.google_secret_manager_secret_version.lr_secret_key.version
              }
            }
          ]
        },
        {
          name = "LR_VAULT_LR_ACCOUNT_ID"
          value_source = [
            {
              secret_key_ref = {
                secret  = data.google_secret_manager_secret_version.lr_account_id.secret
                version = data.google_secret_manager_secret_version.lr_account_id.version
              }
            }
          ]
        }
      ]

      # Predictable email address to break circular dependency cycles
      service_account_email = "liveramp-encoder-sa@${var.gcp_project_id}.iam.gserviceaccount.com"
      execute_job           = false
    }
  }
}
