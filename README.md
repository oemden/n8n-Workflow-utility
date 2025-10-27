# Fetch n8n Workflows and Executions

Little Scripts to fetch a workflow and download it locally or download the Execution result of a workflow by id.

## Http Headers

Both scripts include 3x http headers:

```bash
  -H "X-N8N-API-KEY: ${N8N_MY_API_KEY}" \
  -H "CF-Access-Client-Id: ${CLOUDFLARE_ACCESS_CLIENT_ID}" \
  -H "CF-Access-Client-Secret: ${CLOUDFLARE_ACCESS_CLIENT_SECRET}" \
```

You can either save n8n API Token and Cloudflare's Application Access in your profile or export them if you prefer.

```
export N8N_MY_API_KEY="my_n8n_API-KEY123"
export CLOUDFLARE_ACCESS_CLIENT_ID ="my-CF-Acces-client-id"
export CLOUDFLARE_ACCESS_CLIENT_SECRET ="my-CF-Acces-client-secret"
```
**local .env**

- *I plan to add a check for an `.env` file in the current working repo, to override settings.*


## `WORKFLOW_ID` and `EXECUTION_ID`

You need to input the `<WORKFLOW_ID>` as a parameter.
Or you can set it hardcoded in the script. see TODOs.


## Download n8n workflow json locally

The script will download the workflow locally, usefull if you want to track versions fort exemple, or have a local version when doing some dev on your Workflows.

You can either 

- **Usage**: `./fetchw.sh <WORKFLOW_ID>`
- **Example**: `./fetchw.sh 123456789abc`


## Save n8n workflow execution localy

The script will download the execution result locally. you need to input the `<EXECUTION_ID>` as a parametre.
See TODO... plan is tro use .env file, export or parameter.

In the Workflow, click on the Execution Tab to get the ID.

- **Usage**: `./fetche.sh <EXECUTION_ID>`
- **Example**: `./fetch_e.sh 1234`



## TODO

Use a `.env` file or `export` to get `<WORKFLOW_ID>` and/or `<EXECUTION_ID>`