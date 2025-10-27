#!/bin/bash
#
# v0.0.1
#
# Save n8n workflow execution to local file
# Usage: ./fetch_execution.sh <EXECUTION_ID>
# Example: ./fetch_execution.sh 1234

if [[ $1 == "" ]]; then
  echo "No EXECUTION_ID provided. Usage: ./fetch_execution.sh <EXECUTION_ID>"
  exit 1
else
  EXECUTION_ID="${1}"
fi


my_date=$(date "+%Y%m%d%H%M")
curl -X GET "https://n8n.exemple.com/api/v1/executions/${EXECUTION_ID}?includeData=true" \
  -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
  -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  | jq '.' > "my_n8n_Workflow_exec-${EXECUTION_ID}-${my_date}.json"
