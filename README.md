# n8n Workflow utility - n3u -> N triple U

**Version: 0.2.1**

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
- `-i ID` - Workflow ID to download (overrides .n3u.env)
- `-h` - Show help message
- `-v` - Show version

### Save n8n workflow execution localy

The script will download the execution result locally. you need to input the `<EXECUTION_ID>` as a parameter.
Makes no sense to save this in .env file, but finding lats' execution id of a Workflow could the trick

In the Workflow Directory:

- click on the Execution Tab to get the ID.
  - **Usage**: `./fetche.sh <EXECUTION_ID>`
  - **Example**: `./fetch_e.sh 1234`

Note: useless to set an execution id in the .env as it is unique to each execution.

## TODOs

- ✅ Use only `.n3u.env`file or `export` to get `<WORKFLOW_ID>` and/or `<EXECUTION_ID>`
- ✅ turn in to functions, no inline scripting
- ✅ `-i` fetch/download Workflow (by id)
- ✅ Validate workflow exists before download
- rename Project to n-triple-u -> n8n Workflow Utility
- merge both scripts into one script
- Retrieve Workflow id by it's name (for upload only)
- Retrieve Workflow's last Ececution id ?
- Level Up and Upload a Workflow after changing some code locally ? ( maybe usefull in potential CI/CD pipelines ?)
- add parameters:
  -  ✅ `-i` fetch/download Workflow (by id)
  -  `-n` override Workflow Name (for upload)
  -  `-e` fetch/download Execution json localy (by id)
  -  `-l` local directory location to save workflow ( bypass `${LOCAL_WORKFLOW_DIR}` ) # ToChange -> use .env `${LOCAL_WORKFLOW_DIR}`
  -  `-L` local directory location to save execution ( bypass `${LOCAL_EXECUTIONS_DIR}` ) # ToChange -> bypass .env `${LOCAL_WORKFLOW_DIR}`
  -  Output file name format options (simple options): 
    - `-I` (Id): `<WORKFLOW_NAME>-<WORKFLOW_ID>`,
    - `-D` (Date): `<WORKFLOW_NAME>-<DATE>`,
    - `-C` (Complete): `<WORKFLOW_NAME>-<WORKFLOW_ID>-<DATE>`,
    - `No Options`: `<WORKFLOW_NAME>` if `-i`, `<WORKFLOW_ID>` if `-n`.
  -  `-U` Upload/upgrade Workflow
  -  `-E` Automatically save last Execution json locally after Workfdlow fetch/download.
  -  `-H` Set additionnals Headers to the command
  -  `-v` Set a "Version" or "Comment" as a suffix (before extension)
  -  `-O` Output .n3u.env Variables
  -  `-m` Add a comments to a workflows-changelog.md, using the workflow download used name as a reference in the /md file
  **Exemples of proposed usage**

  - Fetch Workflow whose name is "my_super_Automation" into the folder "Exports" including Name,WorkflowId and download date with the last execution of the workflow:

    ```
    n3u -n "my_super_Automation" -l "Exports" -L "Exports" -C -E
    ```

  - Fetch Workflow whose id is "n8nW0rkf0w0001" into the local workflow directory :

    ```
    n3u -i n8nW0rkf0w0001
    ```

## Typical n8n Structure

```bash
.
├── .gitignore
├── .n3u.env.exemple
├── README.md
├── code
│   ├── archives
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
