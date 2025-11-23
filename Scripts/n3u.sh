#!/bin/bash
#
# n3u - n8n Workflow Utility
# v0.2.1 - Variable precedence, MD5 change detection, placeholder safety
# See CHANGELOG.md for full history
#
# Usage: ./n3u.sh [OPTIONS]
# Example: ./n3u.sh -i gp4Wc0jL6faJWYf7
#

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_VERSION="0.2.2"
ARCHIVE_DIR="./code/workflows/archives"

# Filename format flags (set by getopts)
FORMAT_WITH_ID=false
FORMAT_WITH_DATE=false
FORMAT_WITH_VERSION=""

# ============================================================================
# FUNCTIONS
# ============================================================================

# ------------------------------------------------------------------------------
# prompt_confirm - Reusable y/n confirmation prompt
# Arguments: $1 - prompt message (optional, default: "Continue?")
# Returns: 0 if yes, 1 if no
# ------------------------------------------------------------------------------
prompt_confirm() {
  local message="${1:-Continue?}"
  local response

  while true; do
    read -r -p "${message} [y/n]: " response
    case "${response}" in
      [yY]|[yY][eE][sS])
        return 0
        ;;
      [nN]|[nN][oO])
        return 1
        ;;
      *)
        echo "Please answer y or n."
        ;;
    esac
  done
}

# ------------------------------------------------------------------------------
# print_usage - Display help message
# ------------------------------------------------------------------------------
print_usage() {
  cat <<EOF
n3u - n8n Workflow Utility v${SCRIPT_VERSION}

Usage: $(basename "$0") [OPTIONS]

Options:
  -i ID   Workflow ID to download (overrides .n3u.env)
  -n NAME Override workflow name (for filename and upload)
  -U FILE Upload workflow from local JSON file
  -I      Include workflow ID in filename
  -D      Include date in filename
  -C      Complete format: ID + date in filename
  -V VER  Add version/comment suffix to filename
  -h      Show this help message
  -v      Show version

Filename formats:
  (default)  <NAME>.json
  -I         <NAME>-<ID>.json
  -D         <NAME>-<YYYYMMDDHHMM>.json
  -C         <NAME>-<ID>-<YYYYMMDDHHMM>.json
  -V v1.2    <NAME>-v1.2.json

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
# Precedence: -flags > .n3u.env > User ENV (shell/aliases)
# Only overrides User ENV if .n3u.env has non-empty value
# ------------------------------------------------------------------------------
load_env() {
  if [ ! -f .n3u.env ]; then
    echo "WARNING! No .n3u.env file found. Please create one."
    echo "Refer to .n3u.env.exemple for required variables."
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

  # Parse .n3u.env line by line, only set if value is non-empty
  while IFS='=' read -r key value; do
    # Skip comments and empty lines
    [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue

    # Remove surrounding quotes from value
    value=$(echo "$value" | sed 's/^["'\'']*//;s/["'\'']*$//')

    # Only set if value is not empty (preserve User ENV as fallback)
    if [[ -n "$value" ]]; then
      export "$key=$value"
    fi
  done < .n3u.env
}

# ------------------------------------------------------------------------------
# is_placeholder - Check if a variable value matches the example file
# Arguments: $1 - variable name
# Returns: 0 if placeholder (unchanged from example), 1 if configured
# ------------------------------------------------------------------------------
is_placeholder() {
  local var_name="$1"
  local current_value="${!var_name}"  # indirect reference

  # Read example value from .n3u.env.exemple
  local example_value
  example_value=$(grep "^${var_name}=" .n3u.env.exemple 2>/dev/null | cut -d'=' -f2- | tr -d '"')

  # If current value matches example value, it's a placeholder
  [[ "${current_value}" == "${example_value}" ]] && return 0
  return 1
}

# ------------------------------------------------------------------------------
# validate_env - Check that required environment variables are set
# ------------------------------------------------------------------------------
validate_env() {
  local missing=()
  local placeholders=()

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

  # Check critical variables for placeholder values
  if is_placeholder "N8N_API_URL"; then
    placeholders+=("N8N_API_URL")
  fi
  if is_placeholder "N8N_HQ_API_KEY"; then
    placeholders+=("N8N_HQ_API_KEY")
  fi
  if is_placeholder "WORKFLOW_ID"; then
    placeholders+=("WORKFLOW_ID")
  fi

  if [[ ${#placeholders[@]} -gt 0 ]]; then
    echo "ERROR: The following variables appear unchanged from the example file:"
    for var in "${placeholders[@]}"; do
      echo "  - ${var}"
    done
    echo ""
    echo "Please configure your .n3u.env file with actual values."
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
# Uses: FORMAT_WITH_ID, FORMAT_WITH_DATE, FORMAT_WITH_VERSION
# Returns: filename string
# ------------------------------------------------------------------------------
build_filename() {
  local name="${N8N_WORKFLOW_NAME}"
  local suffix=""

  # -C (Complete) sets both ID and date
  if [[ "${FORMAT_WITH_ID}" == "true" ]]; then
    suffix="${suffix}-${WORKFLOW_ID}"
  fi

  if [[ "${FORMAT_WITH_DATE}" == "true" ]]; then
    local date_stamp
    date_stamp=$(date "+%Y%m%d%H%M")
    suffix="${suffix}-${date_stamp}"
  fi

  if [[ -n "${FORMAT_WITH_VERSION}" ]]; then
    suffix="${suffix}-${FORMAT_WITH_VERSION}"
  fi

  echo "${name}${suffix}.json"
}

# ------------------------------------------------------------------------------
# get_md5 - Get MD5 checksum (cross-platform: macOS and Linux)
# Arguments: $1 - file path
# Returns: MD5 hash string
# ------------------------------------------------------------------------------
get_md5() {
  local file="$1"
  if command -v md5 >/dev/null 2>&1; then
    # macOS
    md5 -q "${file}"
  else
    # Linux
    md5sum "${file}" | cut -d' ' -f1
  fi
}

# ------------------------------------------------------------------------------
# check_workflow_changed - Compare new workflow with existing file
# Arguments: $1 - new file (temp), $2 - existing file
# Returns: 0 if changed (or no existing), 1 if unchanged
# ------------------------------------------------------------------------------
check_workflow_changed() {
  local new_file="$1"
  local existing_file="$2"

  # No existing file = changed (new)
  if [[ ! -f "${existing_file}" ]]; then
    return 0
  fi

  local new_md5 existing_md5
  new_md5=$(get_md5 "${new_file}")
  existing_md5=$(get_md5 "${existing_file}")

  if [[ "${new_md5}" == "${existing_md5}" ]]; then
    return 1  # Unchanged
  fi

  return 0  # Changed
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
# Returns: 0 on success, 1 if unchanged (skipped)
# ------------------------------------------------------------------------------
download_workflow() {
  local output_file="$1"
  local response
  local temp_file

  echo "Downloading workflow ${WORKFLOW_ID}..."
  echo "  API URL: ${N8N_API_URL}"

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

  # Save to temp file first
  temp_file=$(mktemp)
  echo "${response}" | jq '.' > "${temp_file}"

  if [[ ! -s "${temp_file}" ]]; then
    echo "ERROR: Failed to process workflow data"
    rm -f "${temp_file}"
    exit 1
  fi

  # Check if workflow has changed
  if ! check_workflow_changed "${temp_file}" "${output_file}"; then
    echo "INFO: Workflow unchanged (checksums match) - skipping save"
    rm -f "${temp_file}"
    return 1
  fi

  # Backup existing file before overwriting
  backup_existing "${output_file}"

  # Move temp file to final location
  mv "${temp_file}" "${output_file}"
  echo "Success: Workflow saved to ${output_file}"
  return 0
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  local workflow_id_arg=""
  local workflow_name_arg=""

  # Parse options
  while getopts ":hvi:n:IDCV:" opt; do
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
      n)
        workflow_name_arg="${OPTARG}"
        ;;
      I)
        FORMAT_WITH_ID=true
        ;;
      D)
        FORMAT_WITH_DATE=true
        ;;
      C)
        # Complete = ID + Date
        FORMAT_WITH_ID=true
        FORMAT_WITH_DATE=true
        ;;
      V)
        FORMAT_WITH_VERSION="${OPTARG}"
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

  # Apply name override (highest precedence)
  if [[ -n "${workflow_name_arg}" ]]; then
    N8N_WORKFLOW_NAME="${workflow_name_arg}"
    echo "Using workflow name from -n flag: ${N8N_WORKFLOW_NAME}"
  fi

  check_workflow_exists

  local output_file
  output_file=$(build_filename)

  # download_workflow handles: temp file, MD5 check, backup if changed, save
  download_workflow "${output_file}"
}

# Run main function
main "$@"

# ============================================================================
# CHANGELOG (latest only - see CHANGELOG.md for full history)
# ============================================================================
# v0.2.2 - Filename format options (-I,-D,-C,-V), -n name override, prompt_confirm()
# v0.2.1 - Variable precedence, MD5 change detection, placeholder safety checks
# v0.2.0 - Added -i flag, workflow existence check, API validation
# v0.1.0 - Refactored into functions, backup feature
# v0.0.1 - Initial release
