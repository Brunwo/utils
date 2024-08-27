# Save secrets to a zip file : 
# - .env

#also save config files (yaml yml properties cfg conf crt)

#! /bin/bash

set -e

# Function to print usage
print_usage() {
    echo "Usage: save_secrets <source_directory> [<output_directory>]"
    echo "Zips the secret and config files, keeping folder hierarchy and skipping build folders"
    echo "If no output directory is provided, it creates the zip file in the source directory"
}

# Check if the source directory is provided
if [ -z "$1" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    print_usage
    exit 1
fi

SOURCE_DIR=$1
# Get the basename of the source directory for the zip name
ZIP_NAME="secrets_and_configs_$(basename "$(realpath "$SOURCE_DIR")").zip"

# Set output directory
OUTPUT_DIR=${2:-"$SOURCE_DIR"}

# Get the absolute paths
ABSOLUTE_SOURCE_DIR=$(realpath "$SOURCE_DIR")
ABSOLUTE_OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

# Create a temporary directory to hold the files to be zipped
TEMP_DIR=$(mktemp -d)

echo "using temp dir: $TEMP_DIR"

# Find and copy secret and config files to the temporary directory
find "$ABSOLUTE_SOURCE_DIR" \
    -type f \( \
        -name ".env*" -o \
        -name "application*.yaml" -o \
        -name "application*.yml" -o \
        -name "*.crt" -o \
        -name "application*.properties" -o \
        -name "*.cfg" -o \
        -name "*.conf" \
    \) \
    -not -path "*/build/*" \
    -not -path "*/.*/*" \
    -exec cp --parents {} "$TEMP_DIR/" \;

# Debug: List contents of temp directory
echo "Contents of temporary directory:"
ls -R "$TEMP_DIR"

# Check if any files were copied
if [ -z "$(ls -A "$TEMP_DIR")" ]; then
    echo "No files were copied to the temporary directory. Exiting."
    exit 1
fi

# Zip the contents of the temporary directory
(cd "$TEMP_DIR" && zip -r "$ZIP_NAME" . -q) || { echo "Failed to create zip file"; exit 1; }

# Move the zip file to the output directory
mv "$TEMP_DIR/$ZIP_NAME" "$ABSOLUTE_OUTPUT_DIR/" || { echo "Failed to move zip file to output directory"; exit 1; }

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

echo "Secret and config files from '$SOURCE_DIR' have been zipped into '$ABSOLUTE_OUTPUT_DIR/$ZIP_NAME', keeping folder hierarchy and skipping build folders."
