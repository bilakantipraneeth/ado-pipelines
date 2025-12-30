locals {
  artifacts = {
    "my-first-repo" = {
      format   = "DOCKER"
      location = var.gcp_region # Use the variable for default location
    }
  }
}