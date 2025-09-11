#!/bin/bash

# Lightweight Security Monitoring Script
# Run with: bash security_monitor.sh

echo "=== SECURITY MONITORING REPORT ==="
echo "Timestamp: $(date)"
echo

# 1. Check firewall status
echo "=== FIREWALL STATUS ==="
sudo ufw status | head -10
echo

# 2. Check Fail2ban status
echo "=== FAIL2BAN STATUS ==="
sudo fail2ban-client status
echo

# 3. Check for suspicious network connections
echo "=== NETWORK CONNECTIONS ==="
echo "Active connections (excluding localhost):"
netstat -tuln | grep -v "127.0.0.1\|::1" | head -10
echo

# 4. Check recent SSH login attempts
echo "=== RECENT SSH ATTEMPTS ==="
echo "Last 10 auth log entries:"
sudo tail -10 /var/log/auth.log | grep -i ssh
echo

# 5. Check system load and processes
echo "=== SYSTEM LOAD ==="
uptime
echo
echo "Top 5 CPU-consuming processes:"
ps aux --sort=-%cpu | head -6
echo

# 6. Check disk usage
echo "=== DISK USAGE ==="
df -h | grep -E "^/dev/"
echo

# 7. Check audit logs for security events
echo "=== RECENT AUDIT EVENTS ==="
sudo ausearch -ts today -k security | tail -5
echo

# 8. Check for listening ports
echo "=== LISTENING PORTS ==="
sudo netstat -tlnp | grep LISTEN | head -10
echo

# 9. Check system logs for errors
echo "=== SYSTEM LOG ERRORS (last hour) ==="
sudo journalctl --since "1 hour ago" --priority err | tail -5
echo

echo "=== MONITORING COMPLETE ==="
echo "Run this script periodically: watch -n 300 bash security_monitor.sh"
