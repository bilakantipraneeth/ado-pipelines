module "project_iam_bindings" {
  source = "terraform-google-modules/iam/google//modules/projects_iam"
  version = "~> 7.5"

  for_each = var.iam_bindings_map

  projects = [var.project_id]
  mode     = "additive"

  bindings = {
    for role in lookup(each.value, "project_roles", []) : role => [
      lookup(each.value, "service_account_address", "")
    ]
  }
}