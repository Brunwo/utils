#!/bin/bash

# Path to the file containing API keys
API_KEYS_FILE=".aider.env"

# Check if the API keys file exists
if [ -f "$API_KEYS_FILE" ]; then
    # Source the file to export the environment variables
    source "$API_KEYS_FILE"
else
    echo "API keys file not found: $API_KEYS_FILE"
    exit 1
fi

# Check if the required environment variables are set
if [ -z "$DEEPSEEK_API_KEY" ]; then
    echo "DEEPSEEK_API_KEY is not set in $API_KEYS_FILE"
    exit 1
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo "ANTHROPIC_API_KEY is not set in $API_KEYS_FILE"
    exit 1
fi

# Export the environment variables explicitly (optional, but ensures they are available)
export DEEPSEEK_API_KEY
export ANTHROPIC_API_KEY

# Launch aider with the specified options
aider --architect --model r1 --editor-model sonnet