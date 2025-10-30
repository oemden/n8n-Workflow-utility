#!/bin/bash
#
# v0.0.1
#
# Save n8n workflow to local file
# Usage: ./fetchw.sh <WORKFLOW_ID>
# Example: ./fetchw.sh gp4Wc0jL6faJWYf7
#
# Variables should be set in .env file per project or here if you uncomment:
# N8N_API_URL="https://n8n.exemple.com/api/v1"
# N8N_HQ_API_KEY="your_n8n_api_key_here"
# N8N_WORKFLOW_NAME="MY_N8N_SUPER_WORKFLOW"
# CLOUDFLARE_ACCESS_CLIENT_ID="your_cloudflare_access_client_id_here"
# CLOUDFLARE_ACCESS_CLIENT_SECRET="your_cloudflare_access_client_secret_here"
# WORKFLOW_ID="your_n8n_workflow_id_here"

# detect .env file and load it
#TODO: improve .env loading with more robust method
# and .n3u.env file or .env to avoid any conflicts

if [ -f .env ] || [ -f .n3u.env ]; then
  export $(grep -v '^#' .env | xargs)
  export $(grep -v '^#' .n3u.env | xargs)
fi

# check if WORKFLOW_ID is provided as argument
if [[ $1 != "" ]]; then
  WORKFLOW_ID="${1}"
else
  echo "No WORKFLOW_ID provided. Using default: ${WORKFLOW_ID}"
    WORKFLOW_ID="${WORKFLOW_ID}"
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
curl -X GET "${N8N_API_URL}/workflows/${WORKFLOW_ID}?excludePinnedData=true" \
  -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
  -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  | jq '.' >  "${N8N_WORKFLOW_NAME}-${WORKFLOW_ID}-${my_date}.json"
