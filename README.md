# n3u

**n8n Workflow utility - n3u** ( *pronounce N triple U* ), fetch and download n8n Workflows and Executions locally.

**Version: 0.5.0**

A simple script to fetch a workflow and download it locally or download the Execution result of a workflow by providing the execution id, allowing to version control your workflow in a dedicated git Repo and roll it back to your last working commited version.

If you've ever found yourself working on a complex n8n workflow, saving it repeatedly while testing, and then realizing you can't remember which version was the last working one, this might help. Or perhaps you've accidentally broken a production workflow and wished you had a quick way to restore yesterday's or last working version.
These are the situations that led to the craetion of this tool. Now we can save snapshots before major changes, add meaningful version tags like "before-api-refactor," and when something inevitably breaks, have a clear trail back to what worked amd restore last working version.


### Features:

- Download workflows by ID (`-i` flag) or from `.n3u.env`
- Validates workflow exists before download
- Auto-backup existing files to archives
- Cloudflare Access authentication support
- Upload or restore Workflow

### Http Headers:

The script always sends mandatory Headers:

- `X-N8N-API-KEY` (from `N8N_HQ_API_KEY`)
- `Accept: application/json`

**Custom headers** 

You can add any Custom Headers by using `N3U_HEADER_*` prefix in `.n3u.env` or parameter `-H "Authorization: Bearer ${MY_TOKEN}"` :

```bash
# Cloudflare Access (if behind CF)
N3U_HEADER_CF_CLIENT_ID="CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}"
N3U_HEADER_CF_CLIENT_SECRET="CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}"

# Or hardcode directly
N3U_HEADER_CF_CLIENT_ID="CF-Access-Client-Id: your_client_id"

# Any custom header
N3U_HEADER_BEARER="Authorization: Bearer ${MY_TOKEN}"
```

Each `N3U_HEADER_*` value is passed directly to `curl -H`.

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

**Using `.n3u.env` file (recommended):**

```bash
# Set WORKFLOW_ID in .n3u.env, then:
./Scripts/n3u.sh
```

**Using `-i` flag (bypass `.n3u.env` settings :**

```bash
./Scripts/n3u.sh -i <WORKFLOW_ID>
# Example:
./Scripts/n3u.sh -i gp01234ABCDEF
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
- `-e [ID]` - Download execution (latest if no ID, or specific ID)
- `-E` - Auto-fetch latest execution after workflow download
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

The script always compares against the base filename (`<NAME>.json` or `<NAME>-<ID>.json`). Date/version suffixes are for your local organization only.

### Upload workflow to n8n

**Upload current workflow:**

```bash
# Upload using N8N_WORKFLOW_NAME from .n3u.env
./Scripts/n3u.sh -U

# Override name on upload
./Scripts/n3u.sh -U -N "NewName"
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
- Fields uploaded: `name`, `nodes`, `connections`, `settings`
- Fields stripped: `id`, `active`, `updatedAt`, `createdAt`, `shared`, `versionId`, `versionCounter`, `triggerCount`, `isArchived`, `meta`, `staticData`

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

## Examples by Use Case

### Daily backup
```bash
./Scripts/n3u.sh
```
Downloads workflow using `.n3u.env` settings. Skips if unchanged.

### Before making changes
```bash
./Scripts/n3u.sh -V "before-refactor"
# Output: MyWorkflow-before-refactor.json
```
Create a named snapshot before editing in n8n.

### Timestamped backup
```bash
./Scripts/n3u.sh -D
# Output: MyWorkflow-202311231430.json
```
Keep multiple dated copies for audit trail.

### Full archive (ID + date)
```bash
./Scripts/n3u.sh -C
# Output: MyWorkflow-gp01234ABC-202311231430.json
```
Complete format when managing multiple workflows.

### Check remote name
```bash
./Scripts/n3u.sh -n
```
See what the workflow is called in n8n, compare with local `.n3u.env`.

### Debug a failed workflow
```bash
./Scripts/n3u.sh -e
# or with specific execution:
./Scripts/n3u.sh -e 12345
```
Download execution data to inspect input/output of each node.

### Download workflow + latest execution
```bash
./Scripts/n3u.sh -E
```
Get both workflow definition and last run data in one command.

### Restore from backup
```bash
./Scripts/n3u.sh -R ./code/workflows/archives/MyWorkflow-202311231430.bak.json
```
Upload an archived version back to n8n.

### Upload with new name
```bash
./Scripts/n3u.sh -U -N "MyWorkflow v2"
```
Push local changes and rename the workflow in n8n.

### Skip confirmation prompts
```bash
./Scripts/n3u.sh -y      # Skip minor prompts (name mismatch)
./Scripts/n3u.sh -Y      # Skip ALL prompts (use with caution)
```
Useful for scripted backups.

## Typical n8n Project Structure

You can change paths in the `.n3u.env` file if above structure does not suit you.

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

See [TODOs.md](TODOs.md) for the complete roadmap and changelog.

