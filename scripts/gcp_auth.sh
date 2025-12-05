#!/bin/bash
set -e
echo "Authenticating with GCP..."
# Note: Azure DevOps pipeline variables are passed in as environment variables.
gcloud auth activate-service-account --key-file="$GCP_KEY_FILE_PATH" --project="$GCP_PROJECT_ID"

echo "Retrieving access token..."
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ -z "$ACCESS_TOKEN" ]; then
  echo "##vso[task.logissue type=error;]ACCESS_TOKEN is empty. Authentication with GCP failed. Check the service account key."
  exit 1
fi

# Share the access token with subsequent steps in the job
echo "##vso[task.setvariable variable=GcpAccessToken;isOutput=false;isSecret=true]$ACCESS_TOKEN"
echo "Authentication successful. Access token is set."
