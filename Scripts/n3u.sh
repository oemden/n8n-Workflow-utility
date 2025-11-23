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
SCRIPT_VERSION="0.3.1"
ARCHIVE_DIR="./code/workflows/archives"

# Remote workflow name (set by check_workflow_exists)
REMOTE_WORKFLOW_NAME=""

# Filename format flags (set by getopts)
FORMAT_WITH_ID=false
FORMAT_WITH_DATE=false
FORMAT_WITH_VERSION=""

# Auto-approve flags (set by getopts or .n3u.env)
AUTO_APPROVE_MINOR=false
AUTO_APPROVE_ALL=false

# ============================================================================
# FUNCTIONS
# ============================================================================

# ------------------------------------------------------------------------------
# prompt_confirm - Reusable y/n confirmation prompt with auto-approve support
# Arguments: $1 - prompt message (optional, default: "Continue?")
#            $2 - risk level: "minor" or "major" (default: "major")
# Returns: 0 if yes, 1 if no
# ------------------------------------------------------------------------------
prompt_confirm() {
  local message="${1:-Continue?}"
  local risk_level="${2:-major}"
  local response

  # Check auto-approve settings
  if [[ "${AUTO_APPROVE_ALL}" == "true" ]]; then
    echo "⚠ Auto-approve (ALL) - proceeding without confirmation"
    return 0
  fi

  if [[ "${AUTO_APPROVE_MINOR}" == "true" && "${risk_level}" == "minor" ]]; then
    echo "⚠ Auto-approve (minor) - proceeding without confirmation"
    return 0
  fi

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
  -i ID     Workflow ID (overrides .n3u.env)
  -w NAME   Override local filename for download
  -n        Get remote workflow name (info only)
  -N NAME   Set remote workflow name (for upload)
  -U        Upload current workflow to n8n
  -R FILE   Restore/upload specific file to n8n
  -I        Include workflow ID in filename
  -D        Include date in filename
  -C        Complete format: ID + date in filename
  -V VER    Add version/comment suffix to filename
  -y        Auto-approve minor confirmations (name mismatch)
  -Y        Auto-approve ALL confirmations (including uploads)
  -h        Show this help message
  -v        Show version

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
# Sets: REMOTE_WORKFLOW_NAME (global)
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

  # Extract and store remote workflow name
  REMOTE_WORKFLOW_NAME=$(echo "${response}" | jq -r '.name')

  echo "Workflow verified: ${WORKFLOW_ID} (${REMOTE_WORKFLOW_NAME})"
}

# ------------------------------------------------------------------------------
# check_name_consistency - Compare remote vs local workflow name
# Uses: REMOTE_WORKFLOW_NAME (global), N8N_WORKFLOW_NAME (env)
# Warns and prompts if mismatch
# ------------------------------------------------------------------------------
check_name_consistency() {
  # Skip if local name not set
  if [[ -z "${N8N_WORKFLOW_NAME}" ]]; then
    echo "INFO: N8N_WORKFLOW_NAME not set in .n3u.env"
    echo "      Remote workflow name: ${REMOTE_WORKFLOW_NAME}"
    echo "      Consider adding: N8N_WORKFLOW_NAME=\"${REMOTE_WORKFLOW_NAME}\""
    return 0
  fi

  # Compare names
  if [[ "${N8N_WORKFLOW_NAME}" == "${REMOTE_WORKFLOW_NAME}" ]]; then
    echo "Name check: OK (local and remote names match)"
    return 0
  fi

  # Mismatch - warn and confirm
  echo ""
  echo "WARNING: Workflow name mismatch!"
  echo "  Remote (n8n):  ${REMOTE_WORKFLOW_NAME}"
  echo "  Local (.env):  ${N8N_WORKFLOW_NAME}"
  echo ""

  if ! prompt_confirm "Names differ. Continue anyway?" "minor"; then
    echo "Aborted by user."
    exit 0
  fi
}

# ------------------------------------------------------------------------------
# get_workflow_name - Display remote workflow name (-n flag)
# Uses: REMOTE_WORKFLOW_NAME (already fetched by check_workflow_exists)
# Shows comparison with local ENV setting
# ------------------------------------------------------------------------------
get_workflow_name() {
  echo ""
  echo "Workflow ID:   ${WORKFLOW_ID}"
  echo "Workflow Name: ${REMOTE_WORKFLOW_NAME}"
  echo ""

  # Show comparison with ENV
  if [[ -z "${N8N_WORKFLOW_NAME}" ]]; then
    echo "Local (.n3u.env): (not set)"
    echo ""
    echo "To set in .n3u.env:"
    echo "  N8N_WORKFLOW_NAME=\"${REMOTE_WORKFLOW_NAME}\""
  elif [[ "${N8N_WORKFLOW_NAME}" == "${REMOTE_WORKFLOW_NAME}" ]]; then
    echo "Local (.n3u.env): ${N8N_WORKFLOW_NAME}"
    echo "Status: OK - names match"
  else
    echo "Local (.n3u.env): ${N8N_WORKFLOW_NAME}"
    echo "Status: MISMATCH - names differ!"
    echo ""
    echo "To sync, update .n3u.env:"
    echo "  N8N_WORKFLOW_NAME=\"${REMOTE_WORKFLOW_NAME}\""
  fi
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
# Arguments: $1 - new file (temp), $2 - output file (may have date/version suffix)
# Returns: 0 if changed (or no existing), 1 if unchanged
# Note: Derives base filename for comparison (strips -D date and -V version suffixes)
# ------------------------------------------------------------------------------
check_workflow_changed() {
  local new_file="$1"
  local output_file="$2"

  # Derive base filename for comparison (strip date/version suffixes)
  # Output: workflow-ID-202311231234-v1.0.json → workflow-ID.json
  local base_file="${output_file}"

  # Strip version suffix: -<anything>.json → .json (but keep -ID which is alphanumeric)
  # Version pattern: dash followed by non-date content before .json
  # e.g., -v1.0.json, -beta.json, -test.json
  if [[ -n "${FORMAT_WITH_VERSION}" ]]; then
    base_file=$(echo "${base_file}" | sed "s/-${FORMAT_WITH_VERSION}\.json$/.json/")
  fi

  # Strip date suffix: -YYYYMMDDHHMM.json → .json (12 digits)
  if [[ "${FORMAT_WITH_DATE}" == "true" ]]; then
    base_file=$(echo "${base_file}" | sed 's/-[0-9]\{12\}\.json$/.json/')
  fi

  # No base file exists = changed (new)
  if [[ ! -f "${base_file}" ]]; then
    # Also check output file directly (in case base == output)
    if [[ ! -f "${output_file}" ]]; then
      return 0
    fi
    # Output file exists, compare against it
    base_file="${output_file}"
  fi

  local new_md5 existing_md5
  new_md5=$(get_md5 "${new_file}")
  existing_md5=$(get_md5 "${base_file}")

  if [[ "${new_md5}" == "${existing_md5}" ]]; then
    echo "  (compared against: ${base_file})"
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
    local backup_name="${N8N_WORKFLOW_NAME}-${backup_date}.bak.json"
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

# ------------------------------------------------------------------------------
# check_name_conflict - Check if workflow name exists with different ID
# Arguments: $1 - name to check, $2 - current workflow ID
# Returns: 0 if no conflict, 1 if conflict (prompts user)
# ------------------------------------------------------------------------------
check_name_conflict() {
  local check_name="$1"
  local current_id="$2"

  echo "Checking for name conflicts..."

  # Fetch all workflows and check for name match with different ID
  local response
  response=$(curl -s -X GET "${N8N_API_URL}/workflows" \
    -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
    -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
    -H "Accept: application/json")

  if [[ -z "${response}" ]]; then
    echo "WARNING: Could not check for name conflicts (empty response)"
    return 0
  fi

  # Find workflow with same name but different ID
  local conflict_id
  conflict_id=$(echo "${response}" | jq -r --arg name "${check_name}" --arg id "${current_id}" \
    '.data[] | select(.name == $name and .id != $id) | .id' 2>/dev/null | head -1)

  if [[ -n "${conflict_id}" ]]; then
    echo ""
    echo "WARNING: Name conflict detected!"
    echo "  Name: ${check_name}"
    echo "  Existing workflow ID: ${conflict_id}"
    echo "  Your workflow ID: ${current_id}"
    echo ""

    if ! prompt_confirm "A different workflow has this name. Continue anyway?" "major"; then
      echo "Upload cancelled."
      exit 0
    fi
  fi

  return 0
}

# ------------------------------------------------------------------------------
# upload_workflow - Upload local workflow JSON to n8n API
# Arguments: $1 - input file path
# Uses: WORKFLOW_ID, remote_name_arg (for -N override)
# ------------------------------------------------------------------------------
upload_workflow() {
  local input_file="$1"
  local response

  # Validate file exists
  if [[ ! -f "${input_file}" ]]; then
    echo "ERROR: File not found: ${input_file}"
    exit 1
  fi

  echo "Preparing upload from: ${input_file}"

  # Validate JSON
  if ! jq '.' "${input_file}" >/dev/null 2>&1; then
    echo "ERROR: Invalid JSON in file: ${input_file}"
    exit 1
  fi

  # Extract workflow ID from file if not provided via -i
  local file_workflow_id
  file_workflow_id=$(jq -r '.id // empty' "${input_file}")

  if [[ -z "${WORKFLOW_ID}" && -n "${file_workflow_id}" ]]; then
    WORKFLOW_ID="${file_workflow_id}"
    echo "Using workflow ID from file: ${WORKFLOW_ID}"
  fi

  if [[ -z "${WORKFLOW_ID}" ]]; then
    echo "ERROR: No workflow ID. Provide via -i flag or ensure file contains 'id' field."
    exit 1
  fi

  # Get current name from file
  local file_workflow_name
  file_workflow_name=$(jq -r '.name // empty' "${input_file}")

  # Determine final name (remote_name_arg from -N takes precedence)
  local final_name="${file_workflow_name}"
  if [[ -n "${remote_name_arg}" ]]; then
    final_name="${remote_name_arg}"
    echo "Name override (-N): ${final_name}"
  fi

  # Check for name conflicts
  if [[ -n "${final_name}" ]]; then
    check_name_conflict "${final_name}" "${WORKFLOW_ID}"
  fi

  echo ""
  echo "Upload summary:"
  echo "  File: ${input_file}"
  echo "  Workflow ID: ${WORKFLOW_ID}"
  echo "  Name: ${final_name}"
  echo ""

  # Confirm upload
  if ! prompt_confirm "Upload workflow to n8n?" "major"; then
    echo "Upload cancelled."
    exit 0
  fi

  # Prepare payload - update name if -N was provided
  local payload
  if [[ -n "${remote_name_arg}" ]]; then
    payload=$(jq --arg name "${remote_name_arg}" '.name = $name' "${input_file}")
  else
    payload=$(cat "${input_file}")
  fi

  # Strip read-only fields (n8n rejects them on upload)
  payload=$(echo "${payload}" | jq '{name, nodes, connections, settings}')

  echo "Uploading..."

  # Upload via PUT
  response=$(echo "${payload}" | curl -s -X PUT "${N8N_API_URL}/workflows/${WORKFLOW_ID}" \
    -H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}" \
    -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
    -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -d @-)

  # Check response
  if [[ -z "${response}" ]]; then
    echo "ERROR: Empty response from API"
    exit 1
  fi

  # Check for error
  if echo "${response}" | jq -e '.message' >/dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "${response}" | jq -r '.message')
    echo "ERROR: Upload failed: ${error_msg}"
    exit 1
  fi

  # Verify success
  if echo "${response}" | jq -e '.id' >/dev/null 2>&1; then
    local updated_name
    updated_name=$(echo "${response}" | jq -r '.name')
    echo ""
    echo "Success: Workflow uploaded"
    echo "  ID: ${WORKFLOW_ID}"
    echo "  Name: ${updated_name}"
  else
    echo "ERROR: Unexpected response"
    echo "${response}" | head -c 200
    exit 1
  fi

  return 0
}

# ============================================================================
# MAIN
# ============================================================================

main() {
  local workflow_id_arg=""
  local local_name_arg=""      # -w: local filename override
  local get_remote_name=false  # -n: get remote name (info)
  local remote_name_arg=""     # -N: set remote name (upload)
  local do_upload=false        # -U: upload current workflow
  local restore_file=""        # -R: restore specific file

  # Parse options
  while getopts ":hvi:w:nN:UR:IDCV:yY" opt; do
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
      w)
        local_name_arg="${OPTARG}"
        ;;
      n)
        get_remote_name=true
        ;;
      N)
        remote_name_arg="${OPTARG}"
        ;;
      U)
        do_upload=true
        ;;
      R)
        restore_file="${OPTARG}"
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
      y)
        AUTO_APPROVE_MINOR=true
        ;;
      Y)
        AUTO_APPROVE_ALL=true
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

  # Load environment
  load_env
  validate_env

  # Apply AUTO_APPROVE from .n3u.env (flags take precedence)
  if [[ "${AUTO_APPROVE_MINOR}" != "true" && "${AUTO_APPROVE_ALL}" != "true" ]]; then
    case "${AUTO_APPROVE:-none}" in
      minor) AUTO_APPROVE_MINOR=true ;;
      all)   AUTO_APPROVE_ALL=true ;;
    esac
  fi

  # Display warning if auto-approve is enabled
  if [[ "${AUTO_APPROVE_ALL}" == "true" ]]; then
    echo "⚠ Warning: Auto-approve (ALL) is enabled - use with caution!"
    echo ""
  elif [[ "${AUTO_APPROVE_MINOR}" == "true" ]]; then
    echo "⚠ Warning: Auto-approve (minor) is enabled"
    echo ""
  fi

  # Apply workflow ID from -i flag
  if [[ -n "${workflow_id_arg}" ]]; then
    WORKFLOW_ID="${workflow_id_arg}"
  fi

  # ========================================================================
  # UPLOAD MODE: -U (upload current) or -R FILE (restore specific file)
  # ========================================================================
  if [[ "${do_upload}" == "true" || -n "${restore_file}" ]]; then
    # Determine upload file
    local upload_file
    if [[ -n "${restore_file}" ]]; then
      # -R FILE: restore specific file
      upload_file="${restore_file}"
    else
      # -U: upload current workflow file (build from ENV)
      if [[ -z "${N8N_WORKFLOW_NAME}" ]]; then
        echo "ERROR: N8N_WORKFLOW_NAME not set. Cannot determine file to upload."
        echo "       Use -R FILE to specify a file path, or set N8N_WORKFLOW_NAME in .n3u.env"
        exit 1
      fi
      upload_file="${N8N_WORKFLOW_NAME}.json"
    fi

    upload_workflow "${upload_file}"
    exit 0
  fi

  # ========================================================================
  # DOWNLOAD MODE (default)
  # ========================================================================
  validate_inputs "${workflow_id_arg}"

  # Apply local filename override (-w flag, highest precedence)
  if [[ -n "${local_name_arg}" ]]; then
    N8N_WORKFLOW_NAME="${local_name_arg}"
    echo "Using local filename from -w flag: ${N8N_WORKFLOW_NAME}"
  fi

  check_workflow_exists

  # Handle -n flag: get remote workflow name and exit
  if [[ "${get_remote_name}" == "true" ]]; then
    get_workflow_name
    exit 0
  fi

  # Check name consistency (warn + confirm if mismatch)
  check_name_consistency

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
# v0.3.0 - Upload (-U) and Restore (-R FILE) features, check_name_conflict()
# v0.2.5.1 - Backup files now .bak.json (keeps IDE syntax highlighting)
# v0.2.5 - Name consistency check: warn + confirm if remote/local names differ
# v0.2.4 - Naming refactor: -w (local filename), -n (get remote name), -N (set remote name)
# v0.2.3 - MD5 check uses base filename (ignores -D date and -V version suffixes)
# v0.2.2 - Filename format options (-I,-D,-C,-V), -w name override, prompt_confirm()
# v0.2.1 - Variable precedence, MD5 change detection, placeholder safety checks
# v0.2.0 - Added -i flag, workflow existence check, API validation
# v0.1.0 - Refactored into functions, backup feature
# v0.0.1 - Initial release
