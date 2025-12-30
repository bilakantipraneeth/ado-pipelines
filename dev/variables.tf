variable "gcp_project_id" {
  type        = string
  description = "The GCP Project ID to deploy resources to."
  default     = "praneeth1211-gcp-pilot"
}

variable "gcp_region" {
  type        = string
  description = "The GCP region to use for resources where a default is needed."
  default     = "asia-south1" # Providing a default as it's common
}

variable "aws_access_key_id" {
  type        = string
  description = "AWS access key ID for the local-exec provisioner."
  sensitive   = true
  default     = "key1234"
}

variable "aws_secret_access_key" {
  type        = string
  description = "AWS secret access key for the local-exec provisioner."
  sensitive   = true
  default     = "secret12344"
}

variable "aws_session_token" {
  type        = string
  description = "AWS session token for the local-exec provisioner."
  default     = "token12344"
  sensitive   = true
}

# --- LiveRamp Credentials ---
variable "lr_aws_access_key_id" {
  type        = string
  description = "LiveRamp AWS Access Key ID."
  sensitive   = true
}

variable "lr_aws_secret_access_key" {
  type        = string
  description = "LiveRamp AWS Secret Access Key."
  sensitive   = true
}

variable "lr_account_id" {
  type        = string
  description = "LiveRamp AWS Account ID."
  sensitive   = true
}

variable "lr_aws_region" {
  type        = string
  description = "LiveRamp AWS Region."
  default     = "eu-central-1" # Hardcoded in their docs, but good to have as var
}

# --- Buckets ---
variable "input_bucket_name" {
  type        = string
  description = "Name of the GCS bucket for input files."
}

variable "output_bucket_name" {
  type        = string
  description = "Name of the GCS bucket for output files."
}
