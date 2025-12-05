#!/bin/bash
set -e
set -o pipefail
echo "Waiting 1 minute for user event export to complete..."
sleep 60

USER_EVENT_VIEW_NAME="${USER_EVENT_TABLE_ID_PREFIX}_retail_user_events"
echo "Verifying user event export view: $BQ_DATASET.${USER_EVENT_VIEW_NAME}"

# The project_id is inherited from the gcloud config set during authentication.
COUNT=$(bq query --use_legacy_sql=false --format=csv "SELECT COUNT(*) FROM \`$BQ_DATASET.${USER_EVENT_VIEW_NAME}\`" | tail -n 1)

if [ "$COUNT" -gt 0 ]; then
  echo "User event export view created successfully with $COUNT records."
else
  echo "##vso[task.logissue type=warning;]User event export view is empty. This may be expected, or the export might not have populated data yet."
fi