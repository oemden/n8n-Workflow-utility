#!/bin/bash
#
# n3u - n8n Workflow Utility
# v0.1.0 - Refactored into functions, added argument parsing
# See CHANGELOG.md for full history
#
# Usage: ./n3u.sh [OPTIONS] [WORKFLOW_ID]
# Example: ./n3u.sh gp4Wc0jL6faJWYf7
#

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_VERSION="0.1.0"
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

Usage: $(basename "$0") [OPTIONS] [WORKFLOW_ID]

Options:
  -h    Show this help message
  -v    Show version

Arguments:
  WORKFLOW_ID    The n8n workflow ID to download (optional if set in .n3u.env)

Examples:
  $(basename "$0")                    # Use WORKFLOW_ID from .n3u.env
  $(basename "$0") gp4Wc0jL6faJWYf7   # Download specific workflow

Configuration:
  Create a .n3u.env file in your project root with required variables.
  See .n3u.env.example for reference.
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

  echo "Downloading workflow ${WORKFLOW_ID}..."
  echo "  API URL: ${N8N_API_URL}"
  echo "  Output:  ${output_file}"

  curl -s -X GET "${N8N_API_URL}/workflows/${WORKFLOW_ID}?excludePinnedData=true" \
    -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
    -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    | jq '.' > "${output_file}"

  if [[ -s "${output_file}" ]]; then
    echo "Success: Workflow saved to ${output_file}"
  else
    echo "ERROR: Download failed or empty response"
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
  while getopts ":hv" opt; do
    case ${opt} in
      h)
        print_usage
        exit 0
        ;;
      v)
        print_version
        exit 0
        ;;
      \?)
        echo "Invalid option: -${OPTARG}"
        print_usage
        exit 1
        ;;
    esac
  done
  shift $((OPTIND - 1))

  # Get positional argument (workflow ID)
  workflow_id_arg="${1:-}"

  # Execute workflow
  load_env
  validate_env
  validate_inputs "${workflow_id_arg}"

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
# v0.1.0 - Refactored into functions, added argument parsing, backup feature
# v0.0.2 - Switched to .n3u.env file
# v0.0.1 - Initial release
