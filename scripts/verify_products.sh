#!/bin/bash
set -e
set -o pipefail
echo "Waiting 1 minute for product export to complete..."
sleep 60

PRODUCT_VIEW_NAME="${PRODUCT_TABLE_ID_PREFIX}_retail_products_0"
echo "Verifying product export view: $BQ_DATASET.${PRODUCT_VIEW_NAME}"

# The project_id is inherited from the gcloud config set during authentication.
# The bq query command will fail if the view doesn't exist, and set -e will stop the script.
COUNT=$(bq query --use_legacy_sql=false --format=csv "SELECT COUNT(*) FROM \`$BQ_DATASET.${PRODUCT_VIEW_NAME}\`" | tail -n 1)

if [ "$COUNT" -gt 0 ]; then
  echo "Product export view created successfully with $COUNT records."
else
  echo "##vso[task.logissue type=warning;]Product export view is empty. This may be expected, or the export might not have populated data yet."
fi