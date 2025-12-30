# dev/image_bootstrapper.tf

# This resource handles the one-time bootstrap of the Docker image from AWS to GCP.
# It uses the secrets fetched in data.tf via standard Data Blocks.
resource "null_resource" "initial_image_bootstrapper" {
  triggers = {
    # Implicit dependency: This ensures the repository is created before the bootstrapper runs
    repository_id = module.main_orchestrator.repositories["my-first-repo"].artifact_id
  }

  provisioner "local-exec" {
    working_dir = "${path.root}/../.azuredevops/scripts"
    command     = "./bootstrap_initial_image.sh ${self.triggers.repository_id}"
    interpreter = ["bash", "-c"]

    environment = {
      AWS_ACCESS_KEY_ID     = data.google_secret_manager_secret_version.lr_access_key.secret_data
      AWS_SECRET_ACCESS_KEY = data.google_secret_manager_secret_version.lr_secret_key.secret_data
      AWS_ACCOUNT_ID        = data.google_secret_manager_secret_version.lr_account_id.secret_data
    }
  }
}
