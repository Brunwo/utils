#!/bin/bash

# Script to install 'make_executable.sh' Nautilus script to add chmod +x right-click

set -e

# Create Nautilus scripts directory if missing
mkdir -p ~/.local/share/nautilus/scripts

# Create the make_executable.sh script
cat << 'EOF' > ~/.local/share/nautilus/scripts/make_executable.sh
#!/bin/bash
# Make selected files executable

for filepath in "$@"; do
    chmod +x "$filepath"
done
EOF

# Make the script executable
chmod +x ~/.local/share/nautilus/scripts/make_executable.sh

# Restart Nautilus to apply changes
nautilus -q

echo "Make Executable Nautilus script installed successfully."
echo "Right-click one or more files in Nautilus, go to Scripts > make_executable.sh to make files executable."

