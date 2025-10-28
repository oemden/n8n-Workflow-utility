#!/bin/bash
#
# v0.0.1
#
# Save n8n workflow execution to local file
# Usage: ./fetch_execution.sh <EXECUTION_ID>
# Example: ./fetch_execution.sh 1234
#
# Variables should be set in .env file per project or here if you uncomment:
# N8N_API_URL="https://n8n.exemple.com/api/v1"
# N8N_HQ_API_KEY="your_n8n_api_key_here"
# N8N_WORKFLOW_NAME="MY_N8N_SUPER_WORKFLOW"
# CLOUDFLARE_ACCESS_CLIENT_ID="your_cloudflare_access_client_id_here"
# CLOUDFLARE_ACCESS_CLIENT_SECRET="your_cloudflare_access_client_secret_here"
# EXECUTION_ID has no sense as it changes for each new Execution.

# detect .env file and load it
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
fi

# Check if EXECUTION_ID is provided as argument
if [[ $1 == "" ]]; then
  echo "No EXECUTION_ID provided. Usage: ./fetch_execution.sh <EXECUTION_ID>"
  exit 1
else
  EXECUTION_ID="${1}"
fi

# test .env Variables # for future parameter options
if [[ -z "${N8N_API_URL}" || -z "${N8N_HQ_API_KEY}" || -z "${N8N_WORKFLOW_NAME}" || -z "${CLOUDFLARE_ACCESS_CLIENT_ID}" || -z "${CLOUDFLARE_ACCESS_CLIENT_SECRET}" ]]; then
  echo "One or more required environment variables are missing. Please check your .env file."
  exit 1
else # echo all vars
  echo "N8N_API_URL: ${N8N_API_URL}"
  echo "N8N_WORKFLOW_NAME: ${N8N_WORKFLOW_NAME}"
  echo "CLOUDFLARE_ACCESS_CLIENT_ID: ${CLOUDFLARE_ACCESS_CLIENT_ID}"
  echo "CLOUDFLARE_ACCESS_CLIENT_SECRET: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}"
  echo "WORKFLOW_ID: ${WORKFLOW_ID}"
fi

my_date=$(date "+%Y%m%d%H%M")
curl -X GET "${N8N_API_URL}/executions/${EXECUTION_ID}?includeData=true" \
  -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
  -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  | jq '.' > "${N8N_WORKFLOW_NAME}_exec-${EXECUTION_ID}-${my_date}.json"
