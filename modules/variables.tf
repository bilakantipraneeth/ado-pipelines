variable "project_id" {
  description = "The GCP Project ID."
  type        = string
}

variable "location" {
  description = "The default GCP location/region for resources."
  type        = string
}

variable "artifacts_map" {
  description = "A map of artifact repositories to create."
  type        = map(any)
  default     = {}
}

variable "iam_bindings_map" {
  description = "A map of IAM bindings to create."
  type        = map(any)
  default     = {}
}

variable "secrets_map" {
  description = "A map of secrets to create in GCP Secret Manager."
  type        = map(any)
  default     = {}
}

variable "buckets_map" {
  description = "A map of GCS buckets to create."
  type        = map(any)
  default     = {}
}


variable "cloud_run_jobs_map" {
  description = "A map of Cloud Run Jobs to create."
  type        = map(any)
  default     = {}
}

variable "service_accounts_map" {
  description = "A map of Service Accounts to create."
  type        = map(any)
  default     = {}
}
