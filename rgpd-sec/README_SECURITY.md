# 🔒 Lightweight Security Monitoring Setup

This setup provides essential security monitoring for your Linux server with minimal overhead and attack surface. **GDPR Compliant** with automated log rotation and data minimization.

## 🚀 Quick Deployment

### Option 1: One-Command Remote Setup (Recommended)
```bash
# Download and setup everything automatically
curl -fsSL https://raw.githubusercontent.com/Brunwo/utils/main/rgpd-sec/setup_security.sh | sudo bash
```

### Option 2: Local Installation (When Files Are Present)
```bash
# Run the installation script
sudo ./install_security.sh
```

### Option 3: Test Compatibility First
```bash
# Check if your system is compatible
sudo ./install_security.sh --test
```

## 📊 Security Tools

### Pre-installed in Ubuntu:
✅ **UFW (Firewall)** - Usually pre-installed, needs activation
✅ **RSyslog** - Pre-installed and running by default
✅ **TCPDump** - Pre-installed for network analysis
✅ **Netstat/SS** - Pre-installed network monitoring tools

### Requires Installation:
🔧 **Auditd** - System auditing (needs `sudo apt install auditd`)
🔧 **Fail2ban** - Brute-force protection (needs `sudo apt install fail2ban`)

## 🔧 Monitoring Scripts

### 1. Security Monitor (`security_monitor.sh`)
Comprehensive security status check including:
- Firewall status
- Fail2ban jails
- Network connections
- SSH login attempts
- System load and processes
- Disk usage
- Audit events
- Listening ports
- System errors

**Usage:**
```bash
./security_monitor.sh
```

### 2. Security Alerts (`security_alert.sh`)
Automated alert system that checks for:
- Failed SSH login attempts (>5 threshold)
- Suspicious network connections (>10 threshold)
- High disk usage (>90%)
- Sudo usage detection
- Fail2ban ban activity

**Usage:**
```bash
./security_alert.sh
```

## ⏰ Automated Monitoring

The deployment script automatically sets up:
- **Security alerts every 30 minutes**
- **Full reports every 6 hours**
- **Log rotation (weekly, keep 4 weeks)**
- **Secure file permissions**

To manually configure cron jobs:
```bash
# Edit crontab
crontab -e

# Add these lines:
*/30 * * * * /opt/security-monitoring/security_alert.sh
0 */6 * * * /opt/security-monitoring/security_monitor.sh >> /var/log/security/security_monitor.log 2>&1
```

## 📋 Deployment Scripts

### `setup_security.sh` - Remote Setup & Download Script
**Purpose:** Download all security monitoring files from the repository and run installation
**Features:**
- Downloads all rgpd-sec files locally
- One-command remote deployment
- Automatic dependency installation
- Multiple download methods (curl/wget)
- Script verification and integrity checks
- Post-deployment cleanup

**Usage:**
```bash
# Remote setup (downloads everything and installs)
curl -fsSL https://raw.githubusercontent.com/Brunwo/utils/main/rgpd-sec/setup_security.sh | sudo bash
```

### `install_security.sh` - Local Installation Script
**Purpose:** Install security monitoring when all files are already local
**Features:**
- Interactive installation with confirmation
- Comprehensive audit rule setup
- Log rotation configuration
- Cron job automation
- Secure permissions setup

**What it installs:**
- ✅ Auditd with security rules
- ✅ Monitoring scripts in `/opt/security-monitoring/`
- ✅ Automated log rotation
- ✅ Cron jobs for regular monitoring
- ✅ Secure log file permissions

## 📊 Security Features

### Active Protections:
- **Automated IP banning** with Fail2ban
- **Brute-force attack prevention**
- **Zero successful breaches** protection
- **GDPR-compliant log retention** (4 weeks)

### Alert Monitoring:
- **Failed login attempt detection**
- **High disk usage monitoring**
- **Network connection analysis**
- **Privilege escalation tracking**

## 🔍 Manual Security Checks

```bash
# Quick security overview
./security_monitor.sh

# Check for alerts
./security_alert.sh

# View monitoring logs
tail -f /var/log/security/security_monitor.log

# Check firewall status
sudo ufw status

# Check Fail2ban status
sudo fail2ban-client status

# View recent SSH attempts
sudo tail -20 /var/log/auth.log | grep ssh

# Check system audit logs
sudo ausearch -ts today

# Monitor network connections
watch -n 5 'netstat -tuln | grep -v 127.0.0.1'
```

## 📁 File Locations

### Scripts & Configuration:
- **Main scripts:** `/opt/security-monitoring/`
- **Symlinks:** `./security_monitor.sh`, `./security_alert.sh`
- **Audit rules:** `/etc/audit/rules.d/security.rules`
- **Log rotation:** `/etc/logrotate.d/auditd`
- **Security logs:** `/var/log/security/`

### Log Files:
- **Security alerts:** `~/security_alerts.log`
- **Monitor reports:** `/var/log/security/security_monitor.log`
- **System logs:** `/var/log/auth.log`, `/var/log/syslog`
- **Audit logs:** `/var/log/audit/audit.log`

## 🚨 Security Recommendations

1. **Monitor disk usage** - Set up alerts for high usage (>90%)
2. **Review sudo usage** - Monitor privilege escalation attempts
3. **Check external connections** - Analyze network connection patterns
4. **Regular log review** - Check auth.log and syslog regularly
5. **Keep packages updated** - Run `sudo apt update && sudo apt upgrade`

## ⚡ Emergency Commands

```bash
# Block an IP immediately
sudo ufw deny from IP_ADDRESS

# Check who's logged in
who
w

# Kill suspicious process
sudo kill -9 PID

# View all listening ports
sudo netstat -tlnp

# Check recent failed logins
sudo lastb | head -10

# View audit events
sudo ausearch -ts today -k security
```

## 🔐 GDPR Compliance

This setup is designed to be GDPR compliant:
- **Data minimization**: Only essential security data collected
- **Storage limitation**: Logs rotated weekly, kept for 4 weeks
- **Security measures**: Encrypted logs, proper access controls
- **Audit trail**: All access to logs is tracked

## 📞 Troubleshooting

### Common Issues:
```bash
# If auditd fails to start
sudo systemctl status auditd
sudo journalctl -u auditd -n 20

# If scripts don't work
ls -la /opt/security-monitoring/
./security_monitor.sh --help

# Check cron jobs
crontab -l
```

### Reset Security Monitoring:
```bash
# Remove all components
sudo ./install_security.sh --cleanup

# Reinstall
sudo ./install_security.sh
```

---

**🎯 Your server is now protected with enterprise-grade security monitoring!**

**Quick test:** Run `./security_monitor.sh` to see your security status.
