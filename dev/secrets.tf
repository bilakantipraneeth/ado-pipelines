locals {
  secrets_to_create = {
    "aws-credentials" = {
      secret_data = jsonencode({
        aws_access_key_id     = var.aws_access_key_id
        aws_secret_access_key = var.aws_secret_access_key
        aws_session_token     = var.aws_session_token
      })
    }

    "liveramp-access-key-id" = {
      secret_data = var.lr_aws_access_key_id
    }
    "liveramp-secret-access-key" = {
      secret_data = var.lr_aws_secret_access_key
    }
    "liveramp-account-id" = {
      secret_data = var.lr_account_id
    }

  }
}
