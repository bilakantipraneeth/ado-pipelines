module "gcp_artifact_registry" {
  for_each = var.artifacts_map

  source  = "GoogleCloudPlatform/artifact-registry/google"
  version = "~> 0.8"

  project_id    = var.project_id
  location      = lookup(each.value, "location", var.location)
  repository_id = each.key
  format        = each.value.format

  # Optional values
  description               = lookup(each.value, "description", null)
  kms_key_name              = lookup(each.value, "kms_key_name", null)
  mode                      = lookup(each.value, "mode", "STANDARD_REPOSITORY")
  labels                    = lookup(each.value, "labels", {})
  cleanup_policy_dry_run    = lookup(each.value, "cleanup_policy_dry_run", false)
  cleanup_policies          = lookup(each.value, "cleanup_policies", {})
  members                   = lookup(each.value, "members", {})
}
