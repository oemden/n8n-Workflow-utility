# n8n Workflow utility - n3u -> N triple U

**Version: 0.4.0.1**

Fetch and download n8n Workflows and Executions locally.

Script to fetch a workflow and download it locally or download the Execution result of a workflow by providing the execution id.

Features:
- Download workflows by ID (`-i` flag) or from `.n3u.env`
- Validates workflow exists before download
- Auto-backup existing files to archives
- Cloudflare Access authentication support

### Next Steps:

Check the TODOs at the end of the document.

### Http Headers

Both scripts include 3x http headers:

```bash
  -H "X-N8N-API-KEY: ${N8N_MY_API_KEY}" \
  -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
```

You can either save n8n API Token and Cloudflare's Application Access in your profile or export them if you prefer.

```bash
export N8N_MY_API_KEY="my_n8n_API-KEY123"
export CLOUDFLARE_ACCESS_CLIENT_ID ="my-CF-Acces-client-id"
export CLOUDFLARE_ACCESS_CLIENT_SECRET ="my-CF-Acces-client-secret"
```

### local .n3u.env

Scripts detect the presence of a `.n3u.env` file from where the script is called.

### Variable Precedence

Variables are resolved in this order (highest to lowest priority):

| Priority | Source | Example |
|----------|--------|---------|
| 1 | Command flags | `-i abc123` |
| 2 | `.n3u.env` file | `WORKFLOW_ID="abc123"` |
| 3 | Shell environment | `.zshrc`, `.zsh_aliases`, `export` |

This allows you to:
- Set global defaults in shell config (API keys, Cloudflare)
- Override per-project in `.n3u.env` (workflow ID, name)
- Override per-command with flags (`-i`)


## Usage

### Download n8n workflow json locally

**Using `-i` flag (recommended):**
```bash
./Scripts/n3u.sh -i <WORKFLOW_ID>
# Example:
./Scripts/n3u.sh -i gp01234ABCDEF
```

**Using `.n3u.env` file:**
```bash
# Set WORKFLOW_ID in .n3u.env, then:
./Scripts/n3u.sh
```

**Options:**
- `-i ID` - Workflow ID (overrides .n3u.env)
- `-w NAME` - Override local filename for download
- `-n` - Get remote workflow name (info only)
- `-N NAME` - Set remote workflow name (for upload)
- `-U` - Upload current workflow to n8n
- `-R FILE` - Restore/upload specific file (archive) to n8n
- `-I` - Include workflow ID in filename
- `-D` - Include date in filename
- `-C` - Complete format (ID + date)
- `-V VER` - Add version/comment suffix
- `-y` - Auto-approve minor confirmations (name mismatch)
- `-e [ID]` - Download execution (latest if no ID, or specific ID)
- `-E` - Auto-fetch latest execution after workflow download
- `-Y` - Auto-approve ALL confirmations (including uploads)
- `-h` - Show help message
- `-v` - Show version

**Filename formats:**
```
(default)  <NAME>.json
-I         <NAME>-<ID>.json
-D         <NAME>-<YYYYMMDDHHMM>.json
-C         <NAME>-<ID>-<YYYYMMDDHHMM>.json
-V v1.2    <NAME>-v1.2.json
```

**How MD5 change detection works:**

The script compares the remote workflow against your local file using MD5 checksums. If unchanged, it skips the download.

- `-I` (ID) affects comparison: different ID = different workflow
- `-D` (date) and `-V` (version) are **ignored** in comparison

This means:
```bash
./n3u.sh -V v1.0    # Downloads workflow-v1.0.json
./n3u.sh            # Compares against workflow.json → skips if unchanged
./n3u.sh -V v2.0    # Compares against workflow.json → skips if unchanged
```

The date/version suffixes are for **your local organization**, not workflow identity. The script always compares against the base filename (`<NAME>.json` or `<NAME>-<ID>.json`).

### Upload workflow to n8n

**Upload current workflow:**
```bash
./Scripts/n3u.sh -U              # Uses N8N_WORKFLOW_NAME from .n3u.env
./Scripts/n3u.sh -U -N "NewName" # Override name on upload
```

**Restore from archive:**
```bash
./Scripts/n3u.sh -R ./code/workflows/archives/my-workflow-v1.bak.json
```

**How upload works:**
- Reads workflow ID from file JSON (or uses `-i` flag)
- Checks for name conflicts (warns if name exists with different ID)
- Strips read-only metadata fields before upload (n8n rejects extra properties)
- Uses PUT to update existing workflow

**Fields uploaded:** `name`, `nodes`, `connections`, `settings`

**Fields stripped:** `id`, `active`, `updatedAt`, `createdAt`, `shared`, `versionId`, `versionCounter`, `triggerCount`, `isArchived`, `meta`, `staticData`

### Download execution

**Download latest execution:**
```bash
./Scripts/n3u.sh -e              # Downloads latest execution for workflow in .n3u.env
./Scripts/n3u.sh -i <ID> -e      # Downloads latest execution for specific workflow
```

**Download specific execution:**
```bash
./Scripts/n3u.sh -e 12345        # Downloads execution with ID 12345
```

**Auto-fetch after workflow download:**
```bash
./Scripts/n3u.sh -E              # Downloads workflow + latest execution
```

Output: `<WORKFLOW_NAME>_exec-<EXEC_ID>-<DATE>.json` in `./code/executions/`

## Typical n8n Structure

```bash
.
├── .gitignore
├── .n3u.env.exemple
├── README.md
├── code
│   ├── codeNodes
│   │   └── n8n-codeNode-extract-values.json
│   ├── standaloneNodes
│   │   └── n8n-FormNode-GetValues.json
│   └── workflows
│       └── archives
│           └── my-n8n-workflow-v0.1.json
│       └── executions
└── my-n8n-workflow.json
```

## TODOs

### Completed
- ✅ Use only `.n3u.env` file or `export` to get `<WORKFLOW_ID>` and/or `<EXECUTION_ID>`
- ✅ Turn into functions, no inline scripting
- ✅ `-i` fetch/download Workflow (by id)
- ✅ Validate workflow exists before download
- ✅ `-n` override Workflow Name (for filename and upload)
- ✅ `-I` (Id): `<WORKFLOW_NAME>-<WORKFLOW_ID>.json`
- ✅ `-D` (Date): `<WORKFLOW_NAME>-<DATE>.json`
- ✅ `-C` (Complete): `<WORKFLOW_NAME>-<WORKFLOW_ID>-<DATE>.json`
- ✅ `-V` (Version): `<WORKFLOW_NAME>-<VERSION>.json`
- ✅ MD5 change detection (skip download if unchanged)
- ✅ MD5 uses base filename (ignores -D/-V suffixes)

### Next Priority
- `-l` / `-L` custom output directories

### Completed in v0.4.0.1
- ✅ `-e <ID>` now shows execution info (ID, workflow) like `-e` (latest)
- ✅ `-E` now continues to execution even when workflow unchanged

### Completed in v0.4.0
- ✅ `-e [ID]` download execution (latest or specific)
- ✅ `-E` auto-fetch latest execution after workflow download
- ✅ Merged `fetche.sh` into main script (removed)
- ✅ `get_latest_execution_id()` function
- ✅ `download_execution()` function

### Completed in v0.3.1
- ✅ `-y` / `-Y` Auto-approve (minor / all) with `AUTO_APPROVE` env var

### Completed in v0.3.0
- ✅ `-U` Upload/upgrade Workflow
- ✅ `-R FILE` Restore specific archived workflow
- ✅ `check_name_conflict()` - warn on name collision before upload

### Later
- Retrieve workflow's last Execution ID
- `-E` auto-fetch last execution after workflow download
- `-H` extra headers for API requests
- `-O` output current .n3u.env variables
- `-m` add comments to workflows-changelog.md
- `N3U_AUTO_BACKUP` - implement skip backup option
- Rename project to n-triple-u
- `--long` parameters for all flags
- Handle archives folder path when overridden by `-l` / `-L`

### Future Usage Examples

```bash
# Download with full options (future)
n3u -n "my_super_Automation" -l "Exports" -C -E

# Upload workflow
n3u -U ./my-workflow.json -n "New Name"
```
