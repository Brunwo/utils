#!/bin/bash

# Security Monitoring Installation Script
# This script installs comprehensive security monitoring for Linux servers
# Compatible with GDPR requirements and minimal resource overhead

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration variables
AUDIT_RULES_FILE="/etc/audit/rules.d/security.rules"
LOGROTATE_AUDIT="/etc/logrotate.d/auditd"
SECURITY_LOG_DIR="/var/log/security"
MONITORING_DIR="/opt/security-monitoring"

# Functions
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
        exit 1
    fi
}

backup_file() {
    local file="$1"
    if [[ -f "$file" ]]; then
        cp "$file" "${file}.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backed up $file"
    fi
}

# Main installation function
install_security_monitoring() {
    log_info "Starting Security Monitoring Setup..."

    # Create security log directory
    mkdir -p "$SECURITY_LOG_DIR"
    chmod 750 "$SECURITY_LOG_DIR"
    chown root:adm "$SECURITY_LOG_DIR"
    log_success "Created security log directory: $SECURITY_LOG_DIR"

    # Create monitoring scripts directory
    mkdir -p "$MONITORING_DIR"
    chmod 755 "$MONITORING_DIR"
    log_success "Created monitoring directory: $MONITORING_DIR"

    # Install required packages (only what's not pre-installed)
    log_info "Installing required packages..."
    apt update
    apt install -y auditd  # rsyslog is already pre-installed in Ubuntu

    # Configure auditd rules
    setup_audit_rules

    # Configure log rotation
    setup_log_rotation

    # Create monitoring scripts
    create_monitoring_scripts

    # Set up cron jobs
    setup_cron_jobs

    # Secure log file permissions
    secure_log_permissions

    log_success "Security monitoring setup completed!"
    log_info "Run './security_monitor.sh' to test the installation"
}

setup_audit_rules() {
    log_info "Setting up audit rules..."

    # Backup existing audit rules
    backup_file "/etc/audit/audit.rules"

    # Create security audit rules
    cat > "$AUDIT_RULES_FILE" << 'EOF'
# Basic Security Audit Rules
# Monitor file system changes
-w /etc/passwd -p wa -k passwd_changes
-w /etc/shadow -p wa -k shadow_changes
-w /etc/group -p wa -k group_changes
-w /etc/sudoers -p wa -k sudoers_changes

# Monitor authentication events
-w /var/log/auth.log -p wa -k auth_logs
-w /var/log/sudo.log -p wa -k sudo_logs

# Monitor SSH activity
-w /etc/ssh/sshd_config -p wa -k ssh_config

# Monitor system binaries (common attack targets)
-w /bin/su -p x -k su_exec
-w /usr/bin/sudo -p x -k sudo_exec
-w /usr/bin/su -p x -k su_exec

# Monitor network configuration
-w /etc/network/interfaces -p wa -k network_config
-w /etc/hosts -p wa -k hosts_file

# Monitor cron jobs
-w /etc/crontab -p wa -k crontab_changes
-w /var/spool/cron -p wa -k cron_spool

# Monitor kernel modules
-w /etc/modules -p wa -k modules_config

# Monitor login/logout events
-w /var/log/wtmp -p wa -k login_logout
-w /var/log/btmp -p wa -k failed_logins

# Monitor user privilege escalation
-a always,exit -F arch=b64 -S setuid -S setgid -F auid>=1000 -F auid!=4294967295 -k privilege_escalation
-a always,exit -F arch=b32 -S setuid -S setgid -F auid>=1000 -F auid!=4294967295 -k privilege_escalation

# Monitor file deletion (potential data destruction)
-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k file_deletion
-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -F auid>=1000 -F auid!=4294967295 -k file_deletion

# Monitor system time changes
-a always,exit -F arch=b64 -S adjtimex -S settimeofday -S clock_settime -k time_change
-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S clock_settime -k time_change
EOF

    chmod 640 "$AUDIT_RULES_FILE"
    chown root:root "$AUDIT_RULES_FILE"

    # Reload audit rules
    augenrules --load
    systemctl restart auditd

    log_success "Audit rules configured and loaded"
}

setup_log_rotation() {
    log_info "Setting up log rotation..."

    # Create auditd log rotation
    cat > "$LOGROTATE_AUDIT" << 'EOF'
/var/log/audit/audit.log {
    weekly
    rotate 4
    compress
    missingok
    notifempty
    create 0640 root adm
    postrotate
        systemctl reload auditd
    endscript
}
EOF

    chmod 644 "$LOGROTATE_AUDIT"
    log_success "Log rotation configured for audit logs"
}

create_monitoring_scripts() {
    log_info "Copying monitoring scripts..."

    # Copy existing scripts from current directory
    if [[ -f "./security_monitor.sh" ]]; then
        cp "./security_monitor.sh" "$MONITORING_DIR/security_monitor.sh"
        log_success "Copied security_monitor.sh"
    else
        log_error "security_monitor.sh not found in current directory"
        return 1
    fi

    if [[ -f "./security_alert.sh" ]]; then
        cp "./security_alert.sh" "$MONITORING_DIR/security_alert.sh"
        log_success "Copied security_alert.sh"
    else
        log_error "security_alert.sh not found in current directory"
        return 1
    fi

    # Make scripts executable
    chmod +x "$MONITORING_DIR/security_monitor.sh"
    chmod +x "$MONITORING_DIR/security_alert.sh"

    # Create symlinks in current directory for easy access
    ln -sf "$MONITORING_DIR/security_monitor.sh" "./security_monitor.sh"
    ln -sf "$MONITORING_DIR/security_alert.sh" "./security_alert.sh"

    log_success "Monitoring scripts copied and configured"
}

setup_cron_jobs() {
    log_info "Setting up automated monitoring..."

    # Create cron job for regular security checks
    CRON_JOB="*/30 * * * * $MONITORING_DIR/security_alert.sh"
    ALERT_CRON="0 */6 * * * $MONITORING_DIR/security_monitor.sh >> /var/log/security/security_monitor.log 2>&1"

    # Add to root's crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    (crontab -l 2>/dev/null; echo "$ALERT_CRON") | crontab -

    log_success "Cron jobs configured for automated monitoring"
}

secure_log_permissions() {
    log_info "Securing log file permissions..."

    # Ensure proper permissions on log files
    chmod 640 /var/log/auth.log 2>/dev/null || true
    chmod 640 /var/log/audit/audit.log 2>/dev/null || true
    chmod 640 /var/log/syslog 2>/dev/null || true

    # Set proper ownership
    chown root:adm /var/log/auth.log 2>/dev/null || true
    chown root:adm /var/log/audit/audit.log 2>/dev/null || true
    chown root:adm /var/log/syslog 2>/dev/null || true

    log_success "Log file permissions secured"
}

# Main execution
main() {
    echo "=========================================="
    echo "  🔒 Security Monitoring Setup Script"
    echo "=========================================="
    echo

    check_root

    # Confirm installation
    read -p "This will install security monitoring tools. Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi

    install_security_monitoring

    echo
    echo "=========================================="
    echo "  ✅ Installation Complete!"
    echo "=========================================="
    echo
    echo "Next steps:"
    echo "1. Run: ./security_monitor.sh"
    echo "2. Check alerts: ./security_alert.sh"
    echo "3. View logs: tail -f /var/log/security/security_monitor.log"
    echo
    echo "Documentation: README_SECURITY.md"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        echo "Security Monitoring Installation Script"
        echo
        echo "Usage:"
        echo "  sudo $0              # Install security monitoring"
        echo "  sudo $0 --test       # Test installation (dry run)"
        echo "  sudo $0 --cleanup    # Remove all security monitoring"
        echo "  sudo $0 --help       # Show this help"
        echo
        echo "Examples:"
        echo "  sudo ./install_security.sh"
        echo "  sudo ./install_security.sh --test"
        exit 0
        ;;
    --test)
        log_info "Test mode - checking system compatibility..."
        check_root
        log_success "System is compatible with security monitoring"
        exit 0
        ;;
    --cleanup)
        log_warning "This will remove all security monitoring components"
        read -p "Are you sure? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing security monitoring components..."
            # Stop services
            systemctl stop auditd 2>/dev/null || true
            systemctl disable auditd 2>/dev/null || true

            # Remove files and directories
            rm -rf /opt/security-monitoring
            rm -f /etc/audit/rules.d/security.rules
            rm -f /etc/logrotate.d/auditd
            rm -rf /var/log/security

            # Remove symlinks
            rm -f ./security_monitor.sh
            rm -f ./security_alert.sh

            # Remove cron jobs
            crontab -l 2>/dev/null | grep -v "security_monitor\|security_alert" | crontab -

            log_success "Security monitoring components removed"
        fi
        exit 0
        ;;
    *)
        main "$@"
        ;;
esac
