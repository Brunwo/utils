#!/bin/bash

# Check if correct number of arguments is passed
if [ "$#" -ne 2 ]; then
  echo "Usage: $0 <folderA (MTP path)> <folderB (local path)>"
  exit 1
fi

# Get folder paths from arguments
FOLDER_A="$1"  # MTP Camera folder
FOLDER_B="$2"  # Local folder
FOLDER_B_SAVED="$FOLDER_B/saved"  # Local "saved" folder

# Create the saved folder in Folder B (local path)
mkdir -p "$FOLDER_B_SAVED"

# Process files in Folder A (MTP Camera folder)
# Use gio to list and handle files
for file_a in $(gio list -l "$FOLDER_A" | grep -v 'File doesn\t exist'); do
  # Remove the file from Folder A (MTP)
  gio remove "$FOLDER_A/$file_a" && echo "Removed $file_a from MTP"
done

# Process files in Folder B (local folder)
# List files in Folder B
for file_b in $(gio list -l "$FOLDER_B" | grep -v 'File doesn\t exist'); do
  # Move the file to the saved folder within Folder B (local path)
  mv "$FOLDER_B/$file_b" "$FOLDER_B_SAVED" && echo "Moved $file_b to saved"
done

echo "Processing complete."
