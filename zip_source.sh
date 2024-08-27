#!/usr/bin/env bash

set -e

# Function to print usage
print_usage() {
    echo "Usage: zip_source <source_directory> [<output_directory>]"
    echo "Zips the contents of a directory, excluding files specified in .gitignore"
    echo "If no output directory is provided, it creates the zip file in the source directory"
}

# Check if the source directory is provided
if [ -z "$1" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    print_usage
    exit 1
fi

SOURCE_DIR=$1
# Get the basename of the source directory for the zip name
ZIP_NAME=$(basename "$(realpath "$SOURCE_DIR")").zip

# Set output directory
OUTPUT_DIR=${2:-"$SOURCE_DIR"}

# Get the absolute paths
ABSOLUTE_SOURCE_DIR=$(realpath "$SOURCE_DIR")
ABSOLUTE_OUTPUT_DIR=$(realpath "$OUTPUT_DIR")

# Create a temporary directory to hold the files to be zipped
TEMP_DIR=$(mktemp -d)

# Sync the files to the temporary directory, excluding those in .gitignore
rsync -a --exclude-from="$ABSOLUTE_SOURCE_DIR/.gitignore" --exclude=".git" "$ABSOLUTE_SOURCE_DIR/" "$TEMP_DIR/"

# Zip the contents of the temporary directory
(cd "$TEMP_DIR" && zip -r "$ZIP_NAME" . -q) || { echo "Failed to create zip file"; exit 1; }

# Move the zip file to the output directory
mv "$TEMP_DIR/$ZIP_NAME" "$ABSOLUTE_OUTPUT_DIR/" || { echo "Failed to move zip file to output directory"; exit 1; }

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

echo "Source code from '$SOURCE_DIR' has been zipped into '$ABSOLUTE_OUTPUT_DIR/$ZIP_NAME', excluding files in .gitignore."
