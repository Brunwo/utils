# Get latest Lazydocker release version
LAZYDOCKER_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazydocker/releases/latest" | grep -Po '"tag_name": "v\K[0-9.]+')

# Download the tarball for Linux x86_64
curl -Lo lazydocker.tar.gz "https://github.com/jesseduffield/lazydocker/releases/latest/download/lazydocker_${LAZYDOCKER_VERSION}_Linux_x86_64.tar.gz"

# Extract the archive
mkdir lazydocker-temp
tar xf lazydocker.tar.gz -C lazydocker-temp

# Move the binary to /usr/local/bin for system-wide command
sudo mv lazydocker-temp/lazydocker /usr/local/bin/

# Clean up
rm -rf lazydocker.tar.gz lazydocker-temp

