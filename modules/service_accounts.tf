
resource "google_service_account" "service_accounts" {
  for_each = var.service_accounts_map

  account_id   = each.key
  display_name = lookup(each.value, "display_name", null)
  description  = lookup(each.value, "description", null)
  project      = var.project_id
}
