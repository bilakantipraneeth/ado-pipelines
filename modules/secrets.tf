# This file defines the call to the official Google Secret Manager module
# and orchestrates the creation of secrets.

module "gcp_secrets" {
  source  = "GoogleCloudPlatform/secret-manager/google"
  version = "~> 0.9" # Corrected version based on user feedback

  for_each = var.secrets_map

  project_id = var.project_id
  
  # The 'secrets' input is now correctly formatted as a list of objects,
  # using 'name' as required by the module.
  secrets = [
    {
      name               = each.key # Corrected: 'name' attribute is required
      secret_data        = lookup(each.value, "secret_data", "")
      labels             = lookup(each.value, "labels", {})
      replication_policy = lookup(each.value, "replication_policy", "AUTOMATIC")
    }
  ]
}
