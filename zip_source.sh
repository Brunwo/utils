#!/usr/bin/env bash

# Function to print usage
print_usage() {
    echo "Usage: zip_source <source_directory> [<output_zip_file>]"
    echo "Zips the contents of a directory, excluding files specified in .gitignore"
}

# Check if the directory is provided
if [ -z "$1" ] || [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    print_usage
    exit 1
fi

SOURCE_DIR=$1
OUTPUT_FILE=${2:-source_code.zip}

# Get the absolute path of the source directory
ABSOLUTE_SOURCE_DIR=$(realpath "$SOURCE_DIR")

# Create a temporary directory to hold the files to be zipped
TEMP_DIR=$(mktemp -d)

# Sync the files to the temporary directory, excluding those in .gitignore
rsync -av --exclude-from="$ABSOLUTE_SOURCE_DIR/.gitignore" --exclude=".git" "$ABSOLUTE_SOURCE_DIR/" "$TEMP_DIR/"

# Zip the contents of the temporary directory
cd "$TEMP_DIR" || { echo "Failed to change directory to $TEMP_DIR"; exit 1; }
zip -r "$OUTPUT_FILE" . -q

# Move the zip file to the original directory
mv "$OUTPUT_FILE" "$ABSOLUTE_SOURCE_DIR/"

# Clean up the temporary directory
rm -rf "$TEMP_DIR"

echo "Source code from '$SOURCE_DIR' has been zipped into '$SOURCE_DIR/$OUTPUT_FILE', excluding files in .gitignore."
