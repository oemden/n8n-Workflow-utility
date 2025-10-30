#!/bin/bash
# Scripts/fetchw.sh
# A Bash script to install Scripts/fetchw.sh.
# v0.1.0
# Will be installed in /usr/local/bin/n3u

INSTALL_PATH="/usr/local/bin/n3u"
SCRIPT_SOURCE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/Scripts/fetchw.sh"

# Check if the script source file exists
if [ ! -f "$SCRIPT_SOURCE_PATH" ]; then
    echo "Error: Scripts/fetchw.sh not found in the current directory."
    exit 1
fi

# Check if the user has sudo privileges
if ! sudo -v; then
    echo "This script requires sudo privileges. Please run it with a user that has sudo access."
    exit 1
fi

# Install the script
echo "Installing N triple U to $INSTALL_PATH ..."
# Copy the script to the installation path
cp "$SCRIPT_SOURCE_PATH" "$INSTALL_PATH"
# Make the script executable
chmod +x "$INSTALL_PATH"

echo "Installing N triple U has been installed to $INSTALL_PATH"
ls -l "$INSTALL_PATH"

echo "You can run it using the command: n3u"

# Detect user's shell and source the appropriate file
if [ -f ~/.zshrc ]; then
    source ~/.zshrc
elif [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi

exit 0
