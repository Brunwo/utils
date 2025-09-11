#!/bin/bash

# Lightweight Security Alert Script
# Run with: bash security_alert.sh

ALERT_LOG="$HOME/security_alerts.log"
THRESHOLD_FAILED_LOGINS=5
THRESHOLD_SUSPICIOUS_CONNECTIONS=10

echo "=== SECURITY ALERT CHECK ===" >> "$ALERT_LOG"
echo "Timestamp: $(date)" >> "$ALERT_LOG"

# Check for failed SSH logins
FAILED_LOGINS=$(sudo grep "Failed password" /var/log/auth.log | wc -l)
if [ "$FAILED_LOGINS" -gt "$THRESHOLD_FAILED_LOGINS" ]; then
    echo "ALERT: High number of failed SSH logins detected: $FAILED_LOGINS" >> "$ALERT_LOG"
    echo "Recent failed attempts:" >> "$ALERT_LOG"
    sudo grep "Failed password" /var/log/auth.log | tail -5 >> "$ALERT_LOG"
fi

# Check for suspicious network connections
SUSPICIOUS_CONNECTIONS=$(netstat -tuln | grep -v "127.0.0.1\|::1" | wc -l)
if [ "$SUSPICIOUS_CONNECTIONS" -gt "$THRESHOLD_SUSPICIOUS_CONNECTIONS" ]; then
    echo "ALERT: High number of external connections: $SUSPICIOUS_CONNECTIONS" >> "$ALERT_LOG"
fi

# Check disk usage
DISK_USAGE=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    echo "ALERT: High disk usage detected: ${DISK_USAGE}%" >> "$ALERT_LOG"
fi

# Check for unauthorized sudo usage
SUDO_USAGE=$(sudo grep "sudo:" /var/log/auth.log | grep -v "session opened\|session closed" | wc -l)
if [ "$SUDO_USAGE" -gt 0 ]; then
    echo "ALERT: Sudo usage detected: $SUDO_USAGE attempts" >> "$ALERT_LOG"
    sudo grep "sudo:" /var/log/auth.log | tail -3 >> "$ALERT_LOG"
fi

# Check Fail2ban bans
FAIL2BAN_BANS=$(sudo fail2ban-client status sshd | grep "Currently banned:" | awk '{print $4}')
if [ "$FAIL2BAN_BANS" -gt 0 ]; then
    echo "INFO: Fail2ban has banned $FAIL2BAN_BANS IP addresses" >> "$ALERT_LOG"
fi

echo "--- End of check ---" >> "$ALERT_LOG"
echo

# Show recent alerts
echo "=== RECENT SECURITY ALERTS ==="
tail -20 "$ALERT_LOG" | grep -E "(ALERT|INFO)"

# Clean up old logs (keep last 7 days)
find "$ALERT_LOG" -mtime +7 -delete 2>/dev/null || true
