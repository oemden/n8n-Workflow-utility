# n8n Workflow utility - n3u -> N triple U

**Version: 0.3.1**

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
./Scripts/n3u.sh -i gp4Wc0jL6faJWYf7
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

### Save n8n workflow execution localy

The script will download the execution result locally. you need to input the `<EXECUTION_ID>` as a parameter.
Makes no sense to save this in .env file, but finding lats' execution id of a Workflow could the trick

In the Workflow Directory:

- click on the Execution Tab to get the ID.
  - **Usage**: `./fetche.sh <EXECUTION_ID>`
  - **Example**: `./fetch_e.sh 1234`

Note: useless to set an execution id in the .env as it is unique to each execution.

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
- `-e` download execution by ID
- Merge both scripts (`fetche.sh` → `n3u.sh`)
- `-l` / `-L` custom output directories

### Completed in v0.3.1
- ✅ `-y` / `-Y` Auto-approve (minor / all) with `AUTO_APPROVE` env var

### Completed in v0.3.0
- ✅ `-U` Upload/upgrade Workflow
- ✅ `-R FILE` Restore specific archived workflow
- ✅ `check_name_conflict()` - warn on name collision before upload

### Later
- Rename Project to n-triple-u -> n8n Workflow Utility
- Merge both scripts into one script (`fetche.sh` → `n3u.sh`)
- `-n` Retrieve Workflow ID by its name (for info only)
- `-N` Set/Change Workflow's name (for upload only)
- Retrieve Workflow's last Execution ID
- `-e` fetch/download Execution json locally (by id)
- `-l` local directory location to save workflow
- `-L` local directory location to save execution
- `-E` Automatically save last Execution json locally after Workflow download
- `-H` Set additional Headers to the command
- `-O` Output .n3u.env Variables
- `-m` Add comments to a workflows-changelog.md
- `-???` Omit backup file when downloading workflows while local file exist ( NEW .env option tto )
- Assess All options parameters and see if we can do better/simpler less confusing
- add --parameters to all -p parameters ?
- handle arch98ives folder path when overriden by paramters (-l -L)

### Future Usage Examples

```bash
# Download with full options (future)
n3u -n "my_super_Automation" -l "Exports" -C -E

# Upload workflow
n3u -U ./my-workflow.json -n "New Name"
```
