# n3u - TODOs & Roadmap

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

## Next Priority

- `-l` / `-L` custom output directories

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

## Later

- `-D` / `-C` flags: improve MD5 check for date-based filenames (date always changes)
- `-H` extra headers for API requests
- `-o` output current .n3u.env variables ( find a way to avoid secrets if possible or use `-O` )
- `-m` add comments to workflows-changelog.md
- `N3U_AUTO_BACKUP` - implement skip backup option
- Rename project to n-triple-u
- `--long` parameters for all flags
- Handle archives folder path when overridden by `-l` / `-L`
