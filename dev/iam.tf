locals {
  iam_bindings_to_create = {
    "wif_service_account" = {
      service_account_address = "principalSet://iam.googleapis.com/projects/1234567890/locations/global/workloadIdentityPools/my-pool/subject/my-repo-subject"
      project_roles           = ["roles/storage.objectViewer", "roles/compute.networkViewer"]
    },
    "regular_user_sa" = {
      service_account_address = "serviceAccount:example-sa@${var.gcp_project_id}.iam.gserviceaccount.com"
      project_roles           = ["roles/bigquery.dataViewer"]
    }
    "liveramp_sa" = {
      # Use predictable email to break circular dependency (input vs output)
      service_account_address = "serviceAccount:liveramp-encoder-sa@${var.gcp_project_id}.iam.gserviceaccount.com"
      project_roles = [
        "roles/storage.objectAdmin",
        "roles/secretmanager.secretAccessor"
      ]
    }
  }
}
