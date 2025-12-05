#!/bin/bash
set -e
echo "--- Starting User Event Export Step ---"

JSON_PAYLOAD=$(cat <<EOF
{
  "outputConfig": {
    "bigqueryDestination": {
      "datasetId": "$BQ_DATASET",
      "tableIdPrefix": "$USER_EVENT_TABLE_ID_PREFIX",
      "tableType": "view"
    }
  }
}
EOF
)

API_ENDPOINT="https://retail.googleapis.com/v2alpha/projects/$GCP_PROJECT_ID/locations/global/catalogs/default_catalog/userEvents:export"

echo "Triggering user events export to $API_ENDPOINT..."

RESPONSE_BODY_FILE=$(mktemp)
HTTP_STATUS=$(curl -s -w "%{http_code}" -o "$RESPONSE_BODY_FILE" -X POST \
  -H "Authorization: Bearer $GCP_ACCESS_TOKEN" \
  -H "Content-Type: application/json; charset=utf-8" \
  -H "x-goog-user-project: $GCP_PROJECT_ID" \
  -d "$JSON_PAYLOAD" \
  "$API_ENDPOINT")
  
RESPONSE_BODY=$(cat "$RESPONSE_BODY_FILE")
rm "$RESPONSE_BODY_FILE"

if [ "$HTTP_STATUS" -eq 200 ]; then
  echo "User event export initiated successfully."
  echo "API Response: $RESPONSE_BODY"
else
  ERROR_MESSAGE=$(echo "$RESPONSE_BODY" | jq -r '.error.message' 2>/dev/null)
  if [ -z "$ERROR_MESSAGE" ] || [ "$ERROR_MESSAGE" == "null" ]; then
    ERROR_MESSAGE="No detailed error message in response body. Full response: $RESPONSE_BODY"
  fi
  
  SUGGESTION=""
  if [ "$HTTP_STATUS" -eq 403 ]; then
    SUGGESTION=" This 403 error often means the 'Service Usage API' (serviceusage.googleapis.com) or other required APIs are not enabled on your GCP project. Please check your project's API & Services dashboard."
  fi
  
  echo "##vso[task.logissue type=error;]Failed to initiate user event export. Received HTTP status code: $HTTP_STATUS. Error: $ERROR_MESSAGE.$SUGGESTION"
  exit 1
fi
