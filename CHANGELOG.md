# Changelog

All notable changes to this project will be documented in this file.

## [0.4.0] - 2025-11-23

### Added
- Execution existence check - skip download if already exists (exec IDs are unique)
- Execution filename now follows workflow naming flags (-I, -D, -C, -w)
- `-e [ID]` flag - download execution (latest if no ID, or specific)
- `-E` flag - auto-fetch latest execution after workflow download
- `get_latest_execution_id()` - fetch most recent execution for workflow
- `download_execution()` - download execution JSON to `./code/executions/`

### Changed
- `download_execution()` - default filename: `<NAME>_exec-<ID>.json` (no date by default)
- With `-D`: `<NAME>_exec-<ID>-<DATE>.json`
- With `-I`: `<NAME>-<WF_ID>_exec-<ID>.json`
- With `-C`: `<NAME>-<WF_ID>_exec-<ID>-<DATE>.json`

### Removed
- `Scripts/fetche.sh` - merged into main script

## [0.3.1] - 2025-11-23

### Added
- `-y` flag - auto-approve minor confirmations (name mismatch)
- `-Y` flag - auto-approve ALL confirmations (including uploads)
- `AUTO_APPROVE` env var (none/minor/all) in `.n3u.env`

### Changed
- `prompt_confirm()` now accepts risk level argument (minor/major)

## [0.3.0] - 2025-11-23

### Added
- `-U` flag - upload current workflow to n8n
- `-R FILE` flag - restore/upload specific file (archive) to n8n
- `upload_workflow()` - shared upload function for -U and -R
- `check_name_conflict()` - warns if workflow name exists with different ID
- README upload section explaining field handling

### Changed
- Main flow restructured: upload mode vs download mode (default)
- Upload strips read-only fields (n8n rejects extra properties)
- Fields uploaded: `name`, `nodes`, `connections`, `settings`

## [0.2.5.1] - 2025-11-23

### Fixed
- Backup files now use `.bak.json` extension (was `.bak`) for IDE syntax highlighting

## [0.2.5] - 2025-11-23

### Added
- `check_name_consistency()` - compares remote vs local workflow name
- Name consistency check runs before every download
- `-n` flag now shows comparison status (match/mismatch)

### Changed
- `check_workflow_exists()` now extracts and stores `REMOTE_WORKFLOW_NAME`
- `get_workflow_name()` reuses fetched data, shows ENV comparison
- Mismatch prompts user to confirm before proceeding

## [0.2.4] - 2025-11-23

### Added
- `-w NAME` flag - override local filename for download (was `-n`)
- `-n` flag - get remote workflow name (info only)
- `-N NAME` flag - set remote workflow name (for upload, used with `-U`)
- `get_workflow_name()` - fetch and display remote workflow name

### Changed
- **Breaking**: `-n` no longer takes an argument - use `-w` for local filename override

## [0.2.3] - 2025-11-23

### Changed
- `check_workflow_changed()` - MD5 comparison now uses base filename
  - Strips `-D` date suffix (12 digits) before comparison
  - Strips `-V` version suffix before comparison
  - Prevents redundant downloads when using date/version flags

### Fixed
- MD5 check now correctly detects unchanged workflows when using `-D` or `-V` flags

## [0.2.2] - 2025-11-23

### Added
- `prompt_confirm()` - reusable y/n confirmation prompt
- `-n NAME` flag - override workflow name (for filename and future upload)
- `-I` flag - include workflow ID in filename
- `-D` flag - include date in filename
- `-C` flag - complete format (ID + date in filename)
- `-V VER` flag - add version/comment suffix to filename

### Changed
- `build_filename()` - now supports format flags (-I, -D, -C, -V)
- Help message updated with new options and filename format examples

## [0.2.1] - 2025-11-23

### Added
- Variable precedence: command flags > `.n3u.env` > shell environment
- `is_placeholder()` - detects unchanged example values
- `check_workflow_changed()` - MD5 checksum comparison
- `get_md5()` - cross-platform MD5 (macOS/Linux)
- Skip download if workflow unchanged (checksums match)

### Changed
- `load_env()` - preserves shell ENV as fallback (only overrides if .n3u.env has value)
- `download_workflow()` - uses temp file, checks MD5 before backup/save
- Documentation updated with variable precedence

## [0.2.0] - 2025-11-23

### Added
- `-i` flag to specify workflow ID (replaces positional argument)
- `check_workflow_exists()` - validates workflow exists in n8n before download
- API response validation in `download_workflow()`
- Error on unknown/stray arguments (must use `-i` flag)

### Changed
- Positional arguments no longer accepted (use `-i <ID>` instead)
- Backup only occurs after workflow is verified to exist

## [0.1.0] - 2024-XX-XX

### Added
- Refactored script into functions
- Added argument parsing with getopts
- Added backup functionality for existing files
- Created CHANGELOG.md

### Changed
- Default output: `<workflow_name>.json` in root folder
- Existing files backed up to `./code/workflows/archives/`

## [0.0.2] - 2024-XX-XX

### Changed
- Switched from `.env` to `.n3u.env` file to avoid conflicts
- Added warning when no `.n3u.env` file is found

## [0.0.1] - 2024-XX-XX

### Added
- Initial release
- Save n8n workflow to local file
- Support for Cloudflare Access authentication
- Environment variables via `.env` file
- Workflow ID as command argument or from env
