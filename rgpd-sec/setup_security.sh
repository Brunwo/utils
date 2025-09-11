#!/bin/bash

# Security Monitoring Setup Script
# One-command setup and deployment of comprehensive security monitoring
# Usage: curl -fsSL https://example.com/setup_security.sh | sudo bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

REPO_URL="https://raw.githubusercontent.com/Brunwo/utils/main/rgpd-sec"
LOCAL_SETUP="./install_security.sh"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        echo "Usage: sudo $0"
        exit 1
    fi
}

check_dependencies() {
    local deps=("curl" "wget" "git")
    local missing=()

    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing+=("$dep")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing[*]}"
        log_info "Installing missing dependencies..."
        apt update && apt install -y "${missing[@]}"
    fi
}

download_all_scripts() {
    log_info "Downloading all security monitoring scripts..."

    # Create temporary directory for downloads
    TMP_DIR="/tmp/security-setup"
    mkdir -p "$TMP_DIR"

    # List of files to download from rgpd-sec directory
    FILES_TO_DOWNLOAD=(
        "install_security.sh"
        "security_monitor.sh"
        "security_alert.sh"
        "README_SECURITY.md"
    )

    # Download each file
    for file in "${FILES_TO_DOWNLOAD[@]}"; do
        if [[ -f "./$file" ]]; then
            log_info "$file already exists locally"
            continue
        fi

        log_info "Downloading $file..."

        # Try curl first
        if curl -fsSL "$REPO_URL/$file" -o "./$file" 2>/dev/null; then
            log_success "Downloaded $file via curl"
        # Try wget as fallback
        elif wget -q "$REPO_URL/$file" -O "./$file" 2>/dev/null; then
            log_success "Downloaded $file via wget"
        else
            log_error "Failed to download $file"
            return 1
        fi

        # Make scripts executable
        if [[ "$file" == *.sh ]]; then
            chmod +x "./$file"
        fi
    done

    log_success "All scripts downloaded successfully"
}

verify_script() {
    if [[ ! -f "$LOCAL_SETUP" ]]; then
        log_error "Setup script not found"
        exit 1
    fi

    if [[ ! -x "$LOCAL_SETUP" ]]; then
        log_error "Setup script is not executable"
        chmod +x "$LOCAL_SETUP"
    fi

    # Basic integrity check
    if ! head -n 5 "$LOCAL_SETUP" | grep -q "Security Monitoring Setup Script"; then
        log_error "Setup script appears to be corrupted"
        exit 1
    fi

    log_success "Setup script verified"
}

run_installation() {
    log_info "Starting security monitoring installation..."

    # Export environment variables for the setup script
    export DEBIAN_FRONTEND=noninteractive

    # Run the setup script
    if "$LOCAL_SETUP"; then
        log_success "Security monitoring installation completed"
    else
        log_error "Installation failed"
        exit 1
    fi
}

cleanup() {
    log_info "Cleaning up temporary files..."
    rm -f "$LOCAL_SETUP"
    rm -rf /tmp/utils 2>/dev/null || true
    log_success "Cleanup completed"
}

show_post_installation_info() {
    echo
    echo "=========================================="
    echo "  📦 Files Downloaded Successfully!"
    echo "=========================================="
    echo
    echo "📁 Downloaded files:"
    echo "   install_security.sh"
    echo "   security_monitor.sh"
    echo "   security_alert.sh"
    echo "   README_SECURITY.md"
    echo
    echo "🚀 Next steps:"
    echo "  The installation script has been executed."
    echo "  Check the output above for installation details."
    echo
    echo "📖 Documentation: README_SECURITY.md"
    echo
    echo "� For management commands, use:"
    echo "  sudo ./install_security.sh --help"
    echo
}

main() {
    echo "=========================================="
    echo "  🚀 Security Monitoring Deployment"
    echo "=========================================="
    echo

    check_root
    check_dependencies
    download_all_scripts
    verify_script
    run_installation
    show_post_installation_info
    cleanup

    echo
    log_success "Deployment completed successfully!"
    echo "Your server is now protected with comprehensive security monitoring."
}

# Run main function
main "$@"
