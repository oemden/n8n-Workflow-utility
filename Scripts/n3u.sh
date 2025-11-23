#!/bin/bash
#
# n3u - n8n Workflow Utility
# v0.2.0 - Added safety checks, placeholder detection, -i flag
# See CHANGELOG.md for full history
#
# Usage: ./n3u.sh [OPTIONS] [WORKFLOW_ID]
# Example: ./n3u.sh gp4Wc0jL6faJWYf7
#

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_VERSION="0.2.0"
ARCHIVE_DIR="./code/workflows/archives"

# ============================================================================
# FUNCTIONS
# ============================================================================

# ------------------------------------------------------------------------------
# print_usage - Display help message
# ------------------------------------------------------------------------------
print_usage() {
  cat <<EOF
n3u - n8n Workflow Utility v${SCRIPT_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  -i ID   Workflow ID to download (overrides .n3u.env)
  -h      Show this help message
  -v      Show version

Examples:
  $(basename "$0")                    # Use WORKFLOW_ID from .n3u.env
  $(basename "$0") -i gp4Wc0jL6faJWYf7   # Download specific workflow

Configuration:
  Create a .n3u.env file in your project root with required variables.
  See .n3u.env.exemple for reference.
EOF
}

# ------------------------------------------------------------------------------
# print_version - Display version
# ------------------------------------------------------------------------------
print_version() {
  echo "n3u v${SCRIPT_VERSION}"
}

# ------------------------------------------------------------------------------
# load_env - Load environment variables from .n3u.env file
# ------------------------------------------------------------------------------
load_env() {
  if [ -f .n3u.env ]; then
    export $(grep -v '^#' .n3u.env | xargs)
  else
    echo "WARNING! No .n3u.env file found. Please create one."
    echo "Refer to .n3u.env.example for required variables."
    echo ""
    echo "Required variables:"
    echo "  N8N_API_URL                    - Your n8n API URL"
    echo "  N8N_HQ_API_KEY                 - Your n8n API key"
    echo "  N8N_WORKFLOW_NAME              - Workflow name for output file"
    echo "  CLOUDFLARE_ACCESS_CLIENT_ID    - Cloudflare Access client ID"
    echo "  CLOUDFLARE_ACCESS_CLIENT_SECRET - Cloudflare Access client secret"
    echo "  WORKFLOW_ID                    - Default workflow ID (optional)"
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# validate_env - Check that required environment variables are set
# ------------------------------------------------------------------------------
validate_env() {
  local missing=()

  [[ -z "${N8N_API_URL}" ]] && missing+=("N8N_API_URL")
  [[ -z "${N8N_HQ_API_KEY}" ]] && missing+=("N8N_HQ_API_KEY")
  [[ -z "${N8N_WORKFLOW_NAME}" ]] && missing+=("N8N_WORKFLOW_NAME")
  [[ -z "${CLOUDFLARE_ACCESS_CLIENT_ID}" ]] && missing+=("CLOUDFLARE_ACCESS_CLIENT_ID")
  [[ -z "${CLOUDFLARE_ACCESS_CLIENT_SECRET}" ]] && missing+=("CLOUDFLARE_ACCESS_CLIENT_SECRET")

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "ERROR: Missing required environment variables:"
    for var in "${missing[@]}"; do
      echo "  - ${var}"
    done
    echo ""
    echo "Please check your .n3u.env file."
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# validate_inputs - Check workflow ID from args or env
# Arguments: $1 - workflow ID from command line (optional)
# ------------------------------------------------------------------------------
validate_inputs() {
  local arg_workflow_id="$1"

  if [[ -n "${arg_workflow_id}" ]]; then
    WORKFLOW_ID="${arg_workflow_id}"
    echo "Using WORKFLOW_ID from argument: ${WORKFLOW_ID}"
  elif [[ -n "${WORKFLOW_ID}" ]]; then
    echo "Using WORKFLOW_ID from .n3u.env: ${WORKFLOW_ID}"
  else
    echo "ERROR: No WORKFLOW_ID provided."
    echo "Provide as argument or set in .n3u.env file."
    exit 1
  fi
}

# ------------------------------------------------------------------------------
# check_workflow_exists - Verify workflow exists in n8n before proceeding
# Exits with error if workflow not found
# ------------------------------------------------------------------------------
check_workflow_exists() {
  echo "Verifying workflow ${WORKFLOW_ID} exists..."

  local response
  response=$(curl -s -X GET "${N8N_API_URL}/workflows/${WORKFLOW_ID}" \
    -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
    -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
    -H "Accept: application/json")

  # Check if response is empty
  if [[ -z "${response}" ]]; then
    echo "ERROR: Empty response from API - check your connection"
    exit 1
  fi

  # Check if API returned an error
  if echo "${response}" | jq -e '.message' >/dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "${response}" | jq -r '.message')
    echo "ERROR: Workflow '${WORKFLOW_ID}' not found: ${error_msg}"
    exit 1
  fi

  # Verify it's a valid workflow (has id field)
  if ! echo "${response}" | jq -e '.id' >/dev/null 2>&1; then
    echo "ERROR: Invalid workflow ID: ${WORKFLOW_ID}"
    exit 1
  fi

  echo "Workflow verified: ${WORKFLOW_ID}"
}

# ------------------------------------------------------------------------------
# build_filename - Build output filename based on options
# Returns: filename string
# ------------------------------------------------------------------------------
build_filename() {
  # Default: just workflow name (no ID, no date)
  echo "${N8N_WORKFLOW_NAME}.json"
}

# ------------------------------------------------------------------------------
# backup_existing - Backup existing file if it exists
# Arguments: $1 - filename to check
# ------------------------------------------------------------------------------
backup_existing() {
  local filename="$1"

  if [[ -f "${filename}" ]]; then
    # Create archive directory if it doesn't exist
    mkdir -p "${ARCHIVE_DIR}"

    local backup_date
    backup_date=$(date "+%Y%m%d%H%M")
    local backup_name="${N8N_WORKFLOW_NAME}-${backup_date}.bak"
    local backup_path="${ARCHIVE_DIR}/${backup_name}"

    echo "Backing up existing file to: ${backup_path}"
    mv "${filename}" "${backup_path}"
  fi
}

# ------------------------------------------------------------------------------
# download_workflow - Download workflow from n8n API
# Arguments: $1 - output filename
# ------------------------------------------------------------------------------
download_workflow() {
  local output_file="$1"
  local response

  echo "Downloading workflow ${WORKFLOW_ID}..."
  echo "  API URL: ${N8N_API_URL}"
  echo "  Output:  ${output_file}"

  # Fetch workflow from API
  response=$(curl -s -X GET "${N8N_API_URL}/workflows/${WORKFLOW_ID}?excludePinnedData=true" \
    -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
    -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json")

  # Check if response is empty
  if [[ -z "${response}" ]]; then
    echo "ERROR: Empty response from API"
    exit 1
  fi

  # Check if API returned an error (n8n returns 'message' or 'code' on error)
  if echo "${response}" | jq -e '.message' >/dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "${response}" | jq -r '.message')
    echo "ERROR: API returned error: ${error_msg}"
    exit 1
  fi

  # Check if response has expected workflow structure (id field)
  if ! echo "${response}" | jq -e '.id' >/dev/null 2>&1; then
    echo "ERROR: Invalid response - not a valid workflow"
    echo "${response}" | head -c 200
    exit 1
  fi

  # Save workflow to file
  echo "${response}" | jq '.' > "${output_file}"

  if [[ -s "${output_file}" ]]; then
    echo "Success: Workflow saved to ${output_file}"
  else
    echo "ERROR: Failed to save workflow to file"
    rm -f "${output_file}"
    exit 1
  fi
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  local workflow_id_arg=""

  # Parse options
  while getopts ":hvi:" opt; do
    case ${opt} in
      h)
        print_usage
        exit 0
        ;;
      v)
        print_version
        exit 0
        ;;
      i)
        workflow_id_arg="${OPTARG}"
        ;;
      :)
        echo "ERROR: Option -${OPTARG} requires an argument"
        print_usage
        exit 1
        ;;
      \?)
        echo "Invalid option: -${OPTARG}"
        print_usage
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  # Warn about stray positional arguments
  if [[ $# -gt 0 ]]; then
    echo "ERROR: Unknown argument(s): $*"
    echo "       Use -i <ID> to specify workflow ID"
    exit 1
  fi

  # Execute workflow
  load_env
  validate_env
  validate_inputs "${workflow_id_arg}"
  check_workflow_exists

  local output_file
  output_file=$(build_filename)

  backup_existing "${output_file}"
  download_workflow "${output_file}"
}

# Run main function
main "$@"

# ============================================================================
# CHANGELOG (latest only - see CHANGELOG.md for full history)
# ============================================================================
# v0.2.0 - Added -i flag, workflow existence check, API validation, error on stray args
# v0.1.0 - Refactored into functions, added argument parsing, backup feature
# v0.0.1 - Initial release
