locals {
  buckets = {
    (var.input_bucket_name) = {
      location      = var.gcp_region
      force_destroy = true # For dev/testing convenience
      versioning    = true
      labels = {
        usage = "liveramp-input"
      }
    }
    (var.output_bucket_name) = {
      location      = var.gcp_region
      force_destroy = true
      versioning    = true
      labels = {
        usage = "liveramp-output"
      }
    }
  }
}
