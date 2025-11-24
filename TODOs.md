# n3u - TODOs & Roadmap

Changelog [CHANGELOG.md](CHANGELOG.md)

## Completed

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
- ✅ `N3U_AUTO_BACKUP` - implement skip backup option

## Next Priority

- `-N` vs `N8N_WORKFLOW_NAME` -> if -N empty value -> use ENV value, if ENV value empty -> meesage and ask to continue without changing name ( if other options are set ), or cancel uplaod / Restore. ( if only -N / -R is set )
- `-l` / `-L` custom output directories

### Later
- Bootstrap: prompt user for mandatory values (N8N_API_URL, N8N_HQ_API_KEY) after download
- Bootstrap: `-S` / `--setup` flag - interactive setup to configure .n3u.env values
- Config: store `.n3u.env.exemple` in `~/.config/n3u/` during install (avoid re-download)
- Config: version check to retrieve latest `.n3u.env.exemple` if changed
- Headers: `-H` override - allow `-H` to override mandatory headers (API key, etc.)
- Debug: verbosity levels (`-d`, `-v` verbose) - show URL, headers sent
- Debug: `-o` / `-O` output current .n3u.env variables with secret masking (e.g., `****` vs real value)
- Recheck if Directory structure exist and if functions create them if missing ( aka create directory sub-structure if it does not exist - respect .n3u.env )
- `-D` / `-C` flags: improve MD5 check for date-based filenames (date always changes)
- `-V` Change to `-m` - Avoid `-v` confusion, consistent with `-M`
- `-M` (was planned to be `-m`) - Add comments to workflows-changelog.md, saved in workflows ?
- Search Workflow id by Name ( ouput only ), get the id of workflow by its name, display list of workflows if more than one or ambiguous results exist.
- Rename project to "n8n Workflow Utility - n-triple-u"
- `--long` parameters for all flags
- Handle archives folder path when overridden by `-l` / `-L`
- Create a New Workflow from file ?


### Much later
Multiple Projects 
- Options to manage More than 1 workflow ?
-> reccurent backup of Listed Workflows ?
-> automatic git commits and push ?
- Detect Folders and tags - in case of More than 1 Workflow ?
    - Use Folders and/or tags for internal organisation ? would bypass .env
    - 1x .env per sub-folder/project ?


## Completed in v0.5.2

- ✅ `-H` flag - add custom headers via command line (can be used multiple times)
- ✅ Headers resolved in EARLY RESOLUTION block (consistent with other params)
- ✅ `n8n_api()` uses `ALL_HEADERS` array (env + CLI combined)

## Completed in v0.5.1

- ✅ `bootstrap_env()` - auto-download `.n3u.env` template when missing
- ✅ `is_placeholder()` - hardcoded placeholder values (no `.n3u.env.exemple` file dependency)
- ✅ Auto-add `.n3u.env` to `.gitignore` if in git repo
- ✅ Removed `load_env_legacy()` function
- ✅ Removed Cloudflare vars from required list in `validate_env()`

## Completed in v0.5.0

- ✅ `n8n_api()` wrapper function - single point for all API calls
- ✅ Dynamic `N3U_HEADER_*` system - add any custom header via `.n3u.env`
- ✅ Replaced 6 hardcoded curl blocks with DRY one-liners
- ✅ Removed hardcoded Cloudflare headers (now user-configurable)

## Completed in v0.4.2

- ✅ Early resolution refactor: all flag/env precedence resolved in one place
- ✅ Cleaner code: removed duplicate resolution logic from operational sections

## Completed in v0.4.1

- ✅ MD5 check now always compares against standard base filename `<NAME>.json`
- ✅ Consistent behavior across `-I`, `-D`, `-C`, `-V` flags
- ✅ "Save with current format options anyway?" prompt when unchanged

## Completed in v0.4.0.1

- ✅ `-e <ID>` now shows execution info (ID, workflow) like `-e` (latest)
- ✅ `-E` now continues to execution even when workflow unchanged

## Completed in v0.4.0

- ✅ `-e [ID]` download execution (latest or specific)
- ✅ `-E` auto-fetch latest execution after workflow download
- ✅ Merged `fetche.sh` into main script (removed)
- ✅ `get_latest_execution_id()` function
- ✅ `download_execution()` function

## Completed in v0.3.1

- ✅ `-y` / `-Y` Auto-approve (minor / all) with `AUTO_APPROVE` env var

## Completed in v0.3.0

- ✅ `-U` Upload/upgrade Workflow
- ✅ `-R FILE` Restore specific archived workflow
- ✅ `check_name_conflict()` - warn on name collision before upload
