#!/bin/bash

# make_secret.sh - Script to secure a file by making it readable only by root
# Usage: ./make_secret.sh <file_path>

set -e  # Exit on any error

# Check if file path is provided
if [ $# -eq 0 ]; then
    echo "Error: No file path provided"
    echo "Usage: $0 <file_path>"
    exit 1
fi

FILE_PATH="$1"

# Check if file exists
if [ ! -f "$FILE_PATH" ]; then
    echo "Error: File '$FILE_PATH' does not exist"
    exit 1
fi

echo "Securing file: $FILE_PATH"

# Change ownership to root:root
echo "Changing ownership to root:root..."
sudo chown root:root "$FILE_PATH"

# Set permissions to 600 (read/write for owner only)
echo "Setting permissions to 600..."
sudo chmod 600 "$FILE_PATH"

# Verify the changes
echo "Verifying changes..."
PERMISSIONS=$(ls -la "$FILE_PATH" | awk '{print $1}')
OWNER=$(ls -la "$FILE_PATH" | awk '{print $3}')
GROUP=$(ls -la "$FILE_PATH" | awk '{print $4}')

echo "File secured successfully:"
echo "  Path: $FILE_PATH"
echo "  Permissions: $PERMISSIONS"
echo "  Owner: $OWNER"
echo "  Group: $GROUP"

echo ""
echo "Note: The file is now only readable by root (use 'sudo cat $FILE_PATH' to read it)"
