
module "gcp_storage" {
  source  = "terraform-google-modules/cloud-storage/google//modules/simple_bucket"
  version = "~> 5.0"

  for_each = var.buckets_map

  project_id    = var.project_id
  name          = each.key
  location      = lookup(each.value, "location", var.location)
  
  # Optional values with defaults
  force_destroy = lookup(each.value, "force_destroy", false)
  
  # Versioning
  versioning = lookup(each.value, "versioning", false)

  # Labels
  labels = lookup(each.value, "labels", {})
  
  # Lifecycle Rules
  lifecycle_rules = lookup(each.value, "lifecycle_rules", [])

  # IAM Members
  iam_members = lookup(each.value, "iam_members", [])
}
