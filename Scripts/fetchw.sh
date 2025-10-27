#!/bin/bash
#
# v0.0.1
#
# Save n8n workflow to local file
# Usage: ./fetchw.sh <WORKFLOW_ID>
# Example: ./fetchw.sh gp4Wc0jL6faJWYf7

if [[ $1 != "" ]]; then
  WORKFLOW_ID="${1}"
else
  echo "No WORKFLOW_ID provided. Using default: 123456789abc"
    WORKFLOW_ID="123456789abc"
fi

curl -X GET "https://n8n.exemple.com/api/v1/workflows/${WORKFLOW_ID}?excludePinnedData=true" \
  -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
  -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  | jq '.' >  "my_n8n_Workflow-${WORKFLOW_ID}-$(date '+%Y%m%d%H%M').json"
