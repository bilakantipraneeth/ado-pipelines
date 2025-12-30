# # WARNING: The following resource uses a 'local-exec' provisioner to run Docker
# # commands. This is not a recommended practice for production environments.
# # A dedicated CI/CD pipeline is the standard for building and pushing images.
# # This will only work if 'docker' and 'gcloud' are installed and configured on the
# # machine running 'terraform apply', and the Docker daemon is running.
# resource "null_resource" "image_pusher" {
#   # This trigger ensures the commands run only when the repository is created or changed.
#   triggers = {
#     repository_url = "${module.artifact_registry.repositories["my-first-repo"].location}-docker.pkg.dev/${module.artifact_registry.repositories["my-first-repo"].project}/${module.artifact_registry.repositories["my-first-repo"].repository_id}"
#   }

#   provisioner "local-exec" {
#     # Note: This assumes you are running on a system with PowerShell (like Windows).
#     command = <<EOT
#       gcloud auth configure-docker ${self.triggers.repository_url} --quiet
#       docker pull 461694764112.dkr.ecr.eu-central-1.amazonaws.com/vault-app:latest
#       docker tag 461694764112.dkr.ecr.eu-central-1.amazonaws.com/vault-app:latest ${self.triggers.repository_url}/vault-app:latest
#       docker push ${self.triggers.repository_url}/vault-app:latest
#       bash .azuredevops/scripts/run_aws_commands.sh
#     EOT
#     interpreter = ["PowerShell", "-Command"]

#     environment = {
#       # These values are now sourced from your local secrets module.
#       AWS_ACCESS_KEY_ID     = module.secrets.aws_access_key_id
#       AWS_SECRET_ACCESS_KEY = module.secrets.aws_secret_access_key
#       AWS_SESSION_TOKEN     = module.secrets.aws_session_token
#     }
#   }
# }