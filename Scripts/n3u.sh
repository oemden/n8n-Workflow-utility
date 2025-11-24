#!/bin/bash
#
# n3u - n8n Workflow Utility
# See CHANGELOG.md for full history
#
# Usage: ./n3u.sh [OPTIONS]
# Example: ./n3u.sh -i gp01234ABCDEF
#

set -e

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_VERSION="0.5.2"

# Default directories (can be overridden by .n3u.env)
LOCAL_WORKFLOW_DIR="${LOCAL_WORKFLOW_DIR:-./code/workflows}"
LOCAL_WORKFLOW_ARCHIVES="${LOCAL_WORKFLOW_ARCHIVES:-${LOCAL_WORKFLOW_DIR}/archives}"
LOCAL_EXECUTIONS_DIR="${LOCAL_EXECUTIONS_DIR:-./code/executions}"
LOCAL_EXECUTIONS_ARCHIVES="${LOCAL_EXECUTIONS_ARCHIVES:-${LOCAL_EXECUTIONS_DIR}/archives}"

# Remote workflow name (set by check_workflow_exists)
REMOTE_WORKFLOW_NAME=""

# Filename format flags (set by getopts)
FORMAT_WITH_ID=false
FORMAT_WITH_DATE=false
FORMAT_WITH_VERSION=""

# Auto-approve flags (set by getopts or .n3u.env)
AUTO_APPROVE_MINOR=false
AUTO_APPROVE_ALL=false

# Custom headers from -H flags (resolved in EARLY RESOLUTION)
CLI_HEADERS=()
ALL_HEADERS=()

# ============================================================================
# FUNCTIONS
# ============================================================================

# ------------------------------------------------------------------------------
# n8n_api - Wrapper for n8n API calls with dynamic headers
# Arguments: $1 - HTTP method (GET, PUT, POST, DELETE)
#            $2 - API endpoint (e.g., /workflows/${ID})
#            $3 - JSON payload for PUT/POST (optional)
# Returns: curl response (JSON)
# Headers: Always includes X-N8N-API-KEY and Accept
#          Adds ALL_HEADERS (resolved from N3U_HEADER_* env + -H flags)
# ------------------------------------------------------------------------------
n8n_api() {
  local method="$1"
  local endpoint="$2"
  local data="${3:-}"

  local -a headers=()
  headers+=(-H "X-N8N-API-KEY: ${N8N_HQ_API_KEY}")
  headers+=(-H "Accept: application/json")

  # Add resolved custom headers (N3U_HEADER_* + -H flags)
  for header in "${ALL_HEADERS[@]}"; do
    headers+=(-H "${header}")
  done

  if [[ -n "${data}" ]]; then
    headers+=(-H "Content-Type: application/json")
    curl -s -X "${method}" "${N8N_API_URL}${endpoint}" "${headers[@]}" -d "${data}"
  else
    curl -s -X "${method}" "${N8N_API_URL}${endpoint}" "${headers[@]}"
  fi
}

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
  -H HDR    Add custom header (can be used multiple times)
  -U        Upload current workflow to n8n
  -R FILE   Restore/upload specific file to n8n
  -I        Include workflow ID in filename
  -D        Include date in filename
  -C        Complete format: ID + date in filename
  -V VER    Add version/comment suffix to filename
  -e [ID]   Download execution (latest if no ID, or specific ID)
  -E        Auto-fetch latest execution after workflow download
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
  $(basename "$0") -i gp01234ABCDEF   # Download specific workflow
  $(basename "$0") -H "Authorization: Bearer token"  # With custom header

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
# bootstrap_env - Download .n3u.env.exemple and create .n3u.env if missing
# Offers to download from GitHub repo and auto-add to .gitignore
# ------------------------------------------------------------------------------
N3U_EXEMPLE_URL="https://raw.githubusercontent.com/oemden/n8n-Workflow-utility/develop/.n3u.env.exemple"

bootstrap_env() {
  # Already have .n3u.env - nothing to do
  [[ -f .n3u.env ]] && return 0

  echo "No .n3u.env file found in current directory."
  echo ""
  echo "Template URL:"
  echo "  ${N3U_EXEMPLE_URL}"
  echo ""
  echo "  [1] Download template automatically"
  echo "  [2] Quit, and fetch manually the template from the URL above"
  echo ""

  local response
  while true; do
    read -r -p "Choice [1/2]: " response
    case "${response}" in
      1)
        echo ""
        echo "Downloading .n3u.env template..."
        if ! curl -fsSL "${N3U_EXEMPLE_URL}" -o .n3u.env 2>/dev/null; then
          echo "ERROR: Failed to download template."
          exit 1
        fi
        echo "Created: .n3u.env"

        # Auto-add to .gitignore if in a git repo
        if [[ -d .git ]]; then
          if ! grep -q "^\.n3u\.env$" .gitignore 2>/dev/null; then
            echo ".n3u.env" >> .gitignore
            echo "Added .n3u.env to .gitignore"
          fi
        fi

        echo ""
        echo "Next steps:"
        echo "  1. Edit .n3u.env with your values (at minimum: N8N_API_URL, N8N_HQ_API_KEY)"
        echo "  2. Run n3u again"
        exit 0
        ;;
      2)
        echo ""
        echo "Manual setup steps:"
        echo "  1. Download the template from the URL above"
        echo "  2. Save it as .n3u.env in this directory"
        echo "  3. Edit .n3u.env with your values (at minimum: N8N_API_URL, N8N_HQ_API_KEY)"
        echo "  4. Add .n3u.env to .gitignore (if using git)"
        echo "  5. Run n3u again"
        echo "  All this is automated if you choose option 1."
        exit 1
        ;;
      *)
        echo "Please answer 1 or 2."
        ;;
    esac
  done
}

# ------------------------------------------------------------------------------
# load_env - Load environment variables from .n3u.env file
# Precedence: -flags > .n3u.env > User ENV (shell/aliases)
# Only overrides User ENV if .n3u.env has non-empty value
# Uses `source` for proper variable expansion (e.g., ${LOCAL_WORKFLOW_DIR})
# ------------------------------------------------------------------------------
load_env() {
  # Bootstrap if .n3u.env doesn't exist
  bootstrap_env

  # Source the .n3u.env file - enables variable expansion like ${VAR}/path
  # shellcheck disable=SC1091
  source .n3u.env
}


# ------------------------------------------------------------------------------
# is_placeholder - Check if a variable still has its placeholder value
# Arguments: $1 - variable name
# Returns: 0 if placeholder (unchanged), 1 if configured with real value
# ------------------------------------------------------------------------------
is_placeholder() {
  local var_name="$1"
  local current_value="${!var_name}"

  # Known placeholder values from canonical .n3u.env.exemple
  case "${var_name}" in
    N8N_API_URL)    [[ "${current_value}" == "https://n8n.example.com/api/v1" ]] && return 0 ;;
    N8N_HQ_API_KEY) [[ "${current_value}" == "your_n8n_api_key_here" ]] && return 0 ;;
    WORKFLOW_ID)    [[ "${current_value}" == "your_n8n_workflow_id_here" ]] && return 0 ;;
  esac
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
    echo ""
    echo "Hint: Did you customize your .n3u.env.exemple with real values?"
    echo "      The .n3u.env.exemple should contain placeholder values, not your actual config."
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
  response=$(n8n_api GET "/workflows/${WORKFLOW_ID}")

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
# Note: Always compares against standard base filename <NAME>.json for consistency
# ------------------------------------------------------------------------------
check_workflow_changed() {
  local new_file="$1"
  local output_file="$2"

  # Always use standard base filename for comparison: <NAME>.json
  # This ensures consistent behavior across -I, -D, -C, -V flags
  local base_file="${N8N_WORKFLOW_NAME}.json"

  # No base file exists = changed (new)
  if [[ ! -f "${base_file}" ]]; then
    # Also check output file directly (in case using format flags on first download)
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
    mkdir -p "${LOCAL_WORKFLOW_ARCHIVES}"

    local backup_date
    backup_date=$(date "+%Y%m%d%H%M")
    local backup_name="${N8N_WORKFLOW_NAME}-${backup_date}.bak.json"
    local backup_path="${LOCAL_WORKFLOW_ARCHIVES}/${backup_name}"

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
  response=$(n8n_api GET "/workflows/${WORKFLOW_ID}?excludePinnedData=true")

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
    # Check if user wants to save with format flags anyway
    local has_format_flags=false
    if [[ "${FORMAT_WITH_ID}" == "true" || "${FORMAT_WITH_DATE}" == "true" || -n "${FORMAT_WITH_VERSION}" ]]; then
      has_format_flags=true
    fi

    if [[ "${has_format_flags}" == "true" ]]; then
      # Check if output file with format already exists
      if [[ -f "${output_file}" ]]; then
        echo "INFO: Workflow unchanged - file already exists: ${output_file}"
        rm -f "${temp_file}"
        return 1
      fi
      # Output file doesn't exist, prompt to save with format
      echo "INFO: Workflow unchanged (checksums match)"
      echo "      Output would be: ${output_file}"
      if prompt_confirm "Save with current format options anyway?" "minor"; then
        # Continue to save
        :
      else
        echo "Skipping save."
        rm -f "${temp_file}"
        return 1
      fi
    else
      echo "INFO: Workflow unchanged (checksums match) - skipping save"
      rm -f "${temp_file}"
      return 1
    fi
  fi

  # Backup existing file before overwriting
  backup_existing "${output_file}"

  # Move temp file to final location
  mv "${temp_file}" "${output_file}"
  echo "Success: Workflow saved to ${output_file}"
  return 0
}

# ------------------------------------------------------------------------------
# get_latest_execution_id - Get the most recent execution ID for a workflow
# Uses: WORKFLOW_ID
# Returns: Sets LATEST_EXECUTION_ID, LATEST_EXECUTION_STATUS, LATEST_EXECUTION_DATE
# ------------------------------------------------------------------------------
get_latest_execution_id() {
  local response

  echo "Fetching latest execution for workflow ${WORKFLOW_ID}..."

  response=$(n8n_api GET "/executions?workflowId=${WORKFLOW_ID}&limit=1")

  if [[ -z "${response}" ]]; then
    echo "ERROR: Empty response from API"
    return 1
  fi

  # Check for API error
  if echo "${response}" | jq -e '.message' >/dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "${response}" | jq -r '.message')
    echo "ERROR: API returned error: ${error_msg}"
    return 1
  fi

  # Extract execution data
  local exec_count
  exec_count=$(echo "${response}" | jq -r '.data | length')

  if [[ "${exec_count}" == "0" ]]; then
    echo "INFO: No executions found for workflow ${WORKFLOW_ID}"
    return 1
  fi

  LATEST_EXECUTION_ID=$(echo "${response}" | jq -r '.data[0].id')
  LATEST_EXECUTION_STATUS=$(echo "${response}" | jq -r '.data[0].status // .data[0].finished // "unknown"')
  LATEST_EXECUTION_DATE=$(echo "${response}" | jq -r '.data[0].startedAt // .data[0].createdAt // "unknown"')

  echo "Latest execution:"
  echo "  ID: ${LATEST_EXECUTION_ID}"
  echo "  Status: ${LATEST_EXECUTION_STATUS}"
  echo "  Date: ${LATEST_EXECUTION_DATE}"

  return 0
}

# ------------------------------------------------------------------------------
# download_execution - Download execution from n8n API
# Arguments: $1 - execution ID, $2 - output directory (optional)
# Uses: N8N_WORKFLOW_NAME, LOCAL_EXECUTIONS_DIR
# ------------------------------------------------------------------------------
download_execution() {
  local exec_id="$1"
  local output_dir="${2:-${LOCAL_EXECUTIONS_DIR}}"
  local response

  # Ensure output directory exists
  mkdir -p "${output_dir}"

  # Check if execution already downloaded (exec IDs are unique, no need for MD5)
  local existing_file
  existing_file=$(find "${output_dir}" -name "*_exec-${exec_id}*.json" 2>/dev/null | head -1)
  if [[ -n "${existing_file}" ]]; then
    echo "INFO: Execution ${exec_id} already downloaded: ${existing_file} - skipping save"
    return 0
  fi

  # Build filename using same format flags as workflow download
  local name="${N8N_WORKFLOW_NAME}"
  local suffix=""

  if [[ "${FORMAT_WITH_ID}" == "true" ]]; then
    suffix="${suffix}-${WORKFLOW_ID}"
  fi

  # Execution ID is always included (uniqueness)
  suffix="${suffix}_exec-${exec_id}"

  if [[ "${FORMAT_WITH_DATE}" == "true" ]]; then
    local exec_date
    exec_date=$(date "+%Y%m%d%H%M")
    suffix="${suffix}-${exec_date}"
  fi

  local output_file="${output_dir}/${name}${suffix}.json"

  echo "Downloading execution ${exec_id}..."
  echo "  API URL: ${N8N_API_URL}"

  response=$(n8n_api GET "/executions/${exec_id}?includeData=true")

  if [[ -z "${response}" ]]; then
    echo "ERROR: Empty response from API"
    return 1
  fi

  # Check for API error
  if echo "${response}" | jq -e '.message' >/dev/null 2>&1; then
    local error_msg
    error_msg=$(echo "${response}" | jq -r '.message')
    echo "ERROR: API returned error: ${error_msg}"
    return 1
  fi

  # Check if response has expected execution structure
  if ! echo "${response}" | jq -e '.id' >/dev/null 2>&1; then
    echo "ERROR: Invalid response - not a valid execution"
    echo "${response}" | head -c 200
    return 1
  fi

  # Save execution
  echo "${response}" | jq '.' > "${output_file}"

  if [[ ! -s "${output_file}" ]]; then
    echo "ERROR: Failed to save execution data"
    rm -f "${output_file}"
    return 1
  fi

  echo "Success: Execution saved to ${output_file}"
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
  response=$(n8n_api GET "/workflows")

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
  response=$(n8n_api PUT "/workflows/${WORKFLOW_ID}" "${payload}")

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
  local exec_id_arg=""         # -e: execution ID (empty = latest)
  local do_execution=false     # -e flag was used
  local auto_execution=false   # -E: auto-fetch after workflow download

  # Parse options
  while getopts ":hvi:w:nN:UR:IDCV:yYeEH:" opt; do
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
      e)
        do_execution=true
        ;;
      E)
        auto_execution=true
        ;;
      H)
        CLI_HEADERS+=("${OPTARG}")
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

  # Handle positional argument for -e (execution ID)
  if [[ "${do_execution}" == "true" && $# -gt 0 ]]; then
    exec_id_arg="$1"
    shift
  fi

  # Warn about stray positional arguments
  if [[ $# -gt 0 ]]; then
    echo "ERROR: Unknown argument(s): $*"
    echo "       Use -i <ID> to specify workflow ID"
    echo "       Use -e [EXEC_ID] to download execution"
    exit 1
  fi

  # Load environment
  load_env
  validate_env

  # ==========================================================================
  # EARLY RESOLUTION: Resolve all flag/env precedence in one place
  # Pattern: flag > env > default (flag already set by getopts above)
  # ==========================================================================

  # Workflow ID: -i flag > WORKFLOW_ID env
  if [[ -n "${workflow_id_arg}" ]]; then
    WORKFLOW_ID="${workflow_id_arg}"
  fi

  # Local filename: -w flag > N8N_WORKFLOW_NAME env
  if [[ -n "${local_name_arg}" ]]; then
    N8N_WORKFLOW_NAME="${local_name_arg}"
  fi

  # Auto-approve: -y/-Y flags > AUTO_APPROVE env > none
  if [[ "${AUTO_APPROVE_MINOR}" != "true" && "${AUTO_APPROVE_ALL}" != "true" ]]; then
    case "${AUTO_APPROVE:-none}" in
      minor) AUTO_APPROVE_MINOR=true ;;
      all)   AUTO_APPROVE_ALL=true ;;
    esac
  fi

  # Auto-execution: -E flag > N3U_AUTO_EXECUTION env > false
  if [[ "${auto_execution}" != "true" && "${N3U_AUTO_EXECUTION}" == "true" ]]; then
    auto_execution=true
  fi

  # Headers: N3U_HEADER_* env vars + -H flags (additive)
  ALL_HEADERS=()
  for var in $(compgen -v | grep "^N3U_HEADER_"); do
    [[ -n "${!var}" ]] && ALL_HEADERS+=("${!var}")
  done
  for header in "${CLI_HEADERS[@]}"; do
    ALL_HEADERS+=("${header}")
  done

  # ==========================================================================
  # WARNINGS: Display after resolution
  # ==========================================================================
  if [[ "${AUTO_APPROVE_ALL}" == "true" ]]; then
    echo "⚠ Warning: Auto-approve (ALL) is enabled - use with caution!"
    echo ""
  elif [[ "${AUTO_APPROVE_MINOR}" == "true" ]]; then
    echo "⚠ Warning: Auto-approve (minor) is enabled"
    echo ""
  fi

  if [[ -n "${local_name_arg}" ]]; then
    echo "Using local filename from -w flag: ${N8N_WORKFLOW_NAME}"
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
  # EXECUTION MODE: -e [EXEC_ID] (standalone execution download)
  # ========================================================================
  if [[ "${do_execution}" == "true" ]]; then
    handle_execution_mode "${exec_id_arg}"
    exit 0
  fi

  # ========================================================================
  # DOWNLOAD MODE (default)
  # ========================================================================
  validate_inputs "${workflow_id_arg}"
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
  # Use || true to prevent set -e from exiting on return 1 (unchanged)
  download_workflow "${output_file}" || true

  # ========================================================================
  # EXECUTION MODE: -E auto-fetch after workflow download
  # ========================================================================
  if [[ "${auto_execution}" == "true" ]]; then
    echo ""
    if get_latest_execution_id; then
      download_execution "${LATEST_EXECUTION_ID}"
    fi
  fi
}

# ============================================================================
# EXECUTION MODE: -e [EXEC_ID] (standalone execution download)
# ============================================================================
handle_execution_mode() {
  local exec_id="$1"

  # Need workflow ID to find executions
  if [[ -z "${WORKFLOW_ID}" ]]; then
    echo "ERROR: No workflow ID. Use -i <ID> or set WORKFLOW_ID in .n3u.env"
    exit 1
  fi

  if [[ -n "${exec_id}" ]]; then
    # Specific execution ID provided - display info like -e (latest) does
    echo "Execution:"
    echo "  ID: ${exec_id}"
    echo "  Workflow: ${WORKFLOW_ID}"
    download_execution "${exec_id}"
  else
    # No ID provided - get latest (get_latest_execution_id displays info)
    if get_latest_execution_id; then
      download_execution "${LATEST_EXECUTION_ID}"
    else
      exit 1
    fi
  fi
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
