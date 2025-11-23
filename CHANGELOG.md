# Changelog

All notable changes to this project will be documented in this file.

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
