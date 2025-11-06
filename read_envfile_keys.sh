#!/bin/bash

# read_envfile_keys.sh - Extract variable names from secured .env files without revealing secrets
# Usage: ./read_envfile_keys.sh <env_file_path>

set -e  # Exit on any error

# Check if file path is provided
if [ $# -eq 0 ]; then
    echo "Error: No .env file path provided"
    echo "Usage: $0 <env_file_path>"
    exit 1
fi

ENV_FILE="$1"

# Check if file exists (we can check this as regular user)
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: File '$ENV_FILE' does not exist"
    exit 1
fi

echo "keys present in : $ENV_FILE"
echo "=========================================="

# Use sudo to read the file and process it safely
# This extracts variable names only (everything before first =)
# and outputs them with masked values (unless empty)
sudo cat "$ENV_FILE" | while IFS= read -r line; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Extract variable name and value (everything before and after first =)
    if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
        var_name="${BASH_REMATCH[1]}"
        var_value="${BASH_REMATCH[2]}"
        # Remove any leading/trailing whitespace from variable name
        var_name=$(echo "$var_name" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # If value is empty, don't add ***
        if [[ -z "$var_value" ]]; then
            echo "${var_name}="
        else
            echo "${var_name}=***"
        fi
    fi
done

