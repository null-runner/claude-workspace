# Security - Claude Workspace

[🇺🇸 English](security-en.md) | [🇮🇹 Italiano](security-it.md)

This guide describes the security system implemented in Claude Workspace and best practices to keep it secure - designed with simplicity for hobby developers and personal projects.

## How Security Works

Claude Workspace implements multiple security layers without the complexity of enterprise systems:

### 1. SSH Key-Based Authentication

**Principle**: Only devices with authorized SSH keys can access

**Implementation**:
- No password authentication
- ED25519 keys (more secure than RSA)
- Unique key for each device

**Configuration**:
```bash
# Generate secure key
ssh-keygen -t ed25519 -b 256 -f ~/.ssh/claude_workspace_key -C "device-identifier"

# Correct permissions
chmod 700 ~/.ssh
chmod 600 ~/.ssh/claude_workspace_key
chmod 644 ~/.ssh/claude_workspace_key.pub
```

### 2. Access Control System

**Control file**: `~/claude-workspace/configs/access_control.conf`

**Structure**:
```
# Access Control Configuration
# Format: DEVICE_ID|PUBLIC_KEY|STATUS|LAST_ACCESS
laptop-nullrunner|ssh-ed25519 AAAAC3...|ENABLED|2025-01-06 10:30:45
```

**Possible states**:
- `ENABLED`: Device authorized
- `DISABLED`: Access temporarily disabled
- `BLOCKED`: Access permanently blocked

### 3. Device Validation

**Control script**: Before each sync, the system verifies:

1. **Valid SSH key**:
   ```bash
   # Excerpt from sync-now.sh
   SSH_KEY=$(ssh-keygen -lf ~/.ssh/claude_workspace_key.pub | awk '{print $2}')
   ```

2. **Authorized device**:
   ```bash
   # Verify on server
   grep "$SSH_KEY" ~/claude-workspace/configs/access_control.conf | grep "ENABLED"
   ```

3. **Source IP** (optional):
   ```bash
   # In .ssh/authorized_keys
   from="192.168.1.*" ssh-ed25519 AAAAC3...
   ```

## Access Control System

### Control Architecture

```
Laptop → SSH Key → Desktop PC → Verify access_control.conf → Access
                      ↓
                  Log access
```

### Management Scripts

1. **claude-status.sh**: Shows current status
   ```bash
   ~/claude-workspace/scripts/claude-status.sh
   ```

2. **claude-enable.sh**: Enables temporary access
   ```bash
   ~/claude-workspace/scripts/claude-enable.sh
   # Default duration: 24 hours
   ```

3. **claude-disable.sh**: Disables access
   ```bash
   ~/claude-workspace/scripts/claude-disable.sh
   ```

### Access Logging

All access is logged in:
- `~/claude-workspace/logs/access.log`: Access logs
- `~/claude-workspace/logs/sync.log`: Sync logs
- `/var/log/auth.log`: System SSH logs

Log format:
```
[2025-01-06 10:30:45] ACCESS_GRANTED: laptop-nullrunner from 192.168.1.150
[2025-01-06 10:31:02] SYNC_START: laptop-nullrunner
[2025-01-06 10:31:15] SYNC_COMPLETE: laptop-nullrunner (1.2MB transferred)
```

## Best Practices

### 1. SSH Key Management

**DO**:
- Use different keys for each device
- Protect private keys with passphrase
- Rotate keys periodically (every 6 months)
- Secure backup of keys

**DON'T**:
- Share keys between devices
- Leave keys without passphrase
- Commit keys to Git repositories
- Use RSA keys < 2048 bits

**Key rotation**:
```bash
# On laptop
ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key_new
ssh-copy-id -i ~/.ssh/claude_workspace_key_new nullrunner@192.168.1.106

# On desktop PC - remove old key
sed -i '/OLD_KEY_FINGERPRINT/d' ~/.ssh/authorized_keys

# Update access_control.conf
```

### 2. Access Monitoring

**Regular checks**:
```bash
# Recent access
tail -50 ~/claude-workspace/logs/access.log | grep ACCESS

# Failed access attempts
grep "DENIED" ~/claude-workspace/logs/access.log

# Active devices
~/claude-workspace/scripts/claude-status.sh | grep ENABLED
```

**Automatic alerts** (optional):
```bash
# Add to crontab for notifications
*/30 * * * * ~/claude-workspace/scripts/check-suspicious.sh
```

### 3. Data Protection

**Sensitive data**:
- Don't save plain text passwords in projects
- Use `.gitignore` to exclude sensitive files
- Encrypt sensitive data before sync

**Example .gitignore**:
```
# Secrets
.env
*.key
*.pem
secrets/
credentials/

# Personal data
*.sqlite
*.db
personal/
```

**Sensitive file encryption**:
```bash
# Encrypt
gpg -c sensitive-file.txt

# Decrypt
gpg -d sensitive-file.txt.gpg
```

**System memory protection**:
```bash
# Memory may contain sensitive information
# Exclude from sync if necessary
echo ".claude/memory/projects/sensitive-project_*.json" >> .rsync-exclude

# Encrypted memory backup
tar -czf - .claude/memory/ | gpg -c > memory-backup-$(date +%Y%m%d).tar.gz.gpg

# Check memory content for sensitive information
grep -r "password\|secret\|key\|token" .claude/memory/ 2>/dev/null || echo "No sensitive data found"
```

### 4. Network Security

**Firewall** (on desktop PC):
```bash
# Allow only SSH from local network
sudo ufw allow from 192.168.1.0/24 to any port 22

# Block everything else
sudo ufw default deny incoming
sudo ufw enable
```

**SSH hardening**:
```bash
# In /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

### 5. Intelligent Memory System Security

The memory system may contain sensitive project information and requires special attention.

**Potential risks**:
- Sensitive project information saved in memory
- Credentials or tokens accidentally saved in notes
- Session history with confidential data
- Memory synchronization between unsecured devices

**Mitigations**:

**Memory content control**:
```bash
# Regular audit for sensitive data
claude-memory-cleaner stats | grep "sensitive patterns"

# Manual content verification
find .claude/memory -name "*.json" -exec grep -l "password\|secret\|token\|key" {} \; 2>/dev/null

# Targeted cleanup if sensitive data found
claude-memory-cleaner project active/sensitive-project --sanitize
```

**Memory security configuration**:
```bash
# Exclude sensitive projects from automatic sync
cat >> .rsync-exclude << EOF
.claude/memory/projects/*confidential*.json
.claude/memory/projects/*secret*.json
.claude/memory/projects/*private*.json
EOF

# Configure limited retention for sensitive projects
# In .claude/memory/workspace-memory.json
{
  "settings": {
    "sensitive_projects": ["confidential-client", "secret-research"],
    "max_retention_days": 7,
    "auto_sanitize": true
  }
}
```

**Secure memory backup**:
```bash
# Complete encrypted backup
tar -czf - .claude/memory/ | gpg --cipher-algo AES256 -c > \
    ~/secure-backups/memory-backup-$(date +%Y%m%d).tar.gz.gpg

# Selective backup (only non-sensitive projects)
tar -czf - .claude/memory/workspace-memory.json \
    $(find .claude/memory/projects -name "*.json" | grep -v -E "confidential|secret|private") | \
    gpg -c > memory-safe-backup-$(date +%Y%m%d).tar.gz.gpg
```

**Automatic sensitive data cleanup**:
```bash
# Automatic cleanup script to add to cron
#!/bin/bash
# ~/claude-workspace/scripts/memory-security-cleanup.sh

# Sensitive patterns to remove automatically
SENSITIVE_PATTERNS=(
    "password"
    "secret"
    "token"
    "api_key"
    "private_key"
    "credential"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    find .claude/memory -name "*.json" -exec sed -i "/$pattern/d" {} \; 2>/dev/null
done

echo "$(date): Memory security cleanup completed" >> logs/security.log
```

**Memory access control**:
```bash
# Restrictive permissions on memory directory
chmod 700 .claude/memory
chmod 600 .claude/memory/workspace-memory.json
chmod 600 .claude/memory/projects/*.json

# Verify permissions
find .claude/memory -type f ! -perm 600 -ls
find .claude/memory -type d ! -perm 700 -ls
```

### 6. Backup and Recovery

**Configuration backups**:
```bash
# Complete weekly backup (includes memory)
tar -czf ~/backups/claude-config-$(date +%Y%m%d).tar.gz \
    ~/.ssh/authorized_keys \
    ~/claude-workspace/configs/ \
    ~/claude-workspace/scripts/ \
    ~/claude-workspace/.claude/memory/

# Configuration-only backup (without memory)
tar -czf ~/backups/claude-config-minimal-$(date +%Y%m%d).tar.gz \
    ~/.ssh/authorized_keys \
    ~/claude-workspace/configs/ \
    ~/claude-workspace/scripts/
```

**Recovery plan**:
1. Restore configuration backups
2. Verify SSH keys
3. Check logs for suspicious activity
4. Verify system memory integrity
5. Re-sync projects
6. Test memory commands for functionality

## Emergency Management

### Compromised Device

1. **Disable immediately**:
   ```bash
   # On desktop PC
   ~/claude-workspace/scripts/claude-disable.sh
   ```

2. **Remove SSH key**:
   ```bash
   # Identify the key
   grep "laptop-name" ~/claude-workspace/configs/access_control.conf
   
   # Remove from authorized_keys
   sed -i '/COMPROMISED_KEY/d' ~/.ssh/authorized_keys
   ```

3. **Audit logs**:
   ```bash
   # Check recent access
   grep "laptop-name" ~/claude-workspace/logs/access.log | tail -100
   ```

4. **Change all keys**:
   - Generate new keys on all devices
   - Update authorized_keys
   - Update access_control.conf

### Unauthorized Access

**Indicators**:
- Access from unknown IPs
- Sync at unusual hours
- Unexpectedly modified files

**Response**:
```bash
# 1. Block access
~/claude-workspace/scripts/claude-disable.sh

# 2. Analyze logs
grep -E "DENIED|FAILED|ERROR" ~/claude-workspace/logs/*.log

# 3. Verify file integrity
find ~/claude-workspace -type f -mtime -1 -ls

# 4. Immediate backup
tar -czf ~/emergency-backup-$(date +%Y%m%d-%H%M%S).tar.gz ~/claude-workspace/
```

## Periodic Security Checklist

### Daily
- [ ] Check access logs for anomalies
- [ ] Verify syncs completed successfully
- [ ] Verify system memory size (< 10MB)

### Weekly
- [ ] Backup configurations (include memory)
- [ ] Review authorized devices
- [ ] Check disk space
- [ ] Audit memory content for sensitive data
- [ ] Test memory recovery from backup

### Monthly
- [ ] Complete log audit
- [ ] Verify all authorized devices
- [ ] Test recovery procedures
- [ ] Update operating system and SSH
- [ ] Complete intelligent memory cleanup
- [ ] Verify cross-device memory consistency

### Semi-annually
- [ ] SSH key rotation
- [ ] Security policy review
- [ ] Internal penetration test
- [ ] Documentation updates

## Useful Security Commands

```bash
# Verify SSH key fingerprint
ssh-keygen -lf ~/.ssh/claude_workspace_key.pub

# Check active SSH connections
ss -tan | grep :22

# Monitor SSH access attempts
sudo tail -f /var/log/auth.log | grep ssh

# Verify file permissions
find ~/claude-workspace -type f -perm /077 -ls

# Check suspicious processes
ps aux | grep -E "rsync|ssh" | grep -v grep

# Analyze network traffic (requires tcpdump)
sudo tcpdump -i any port 22 -n

# Verify integrity with checksums
find ~/claude-workspace -type f -exec md5sum {} \; > checksums.txt
md5sum -c checksums.txt

# System memory security commands
# Verify memory size
du -sh .claude/memory/

# Audit memory content for sensitive data
grep -r "password\|secret\|token\|key\|credential" .claude/memory/ 2>/dev/null

# Encrypted memory backup
tar -czf - .claude/memory/ | gpg -c > memory-secure-$(date +%Y%m%d).tar.gz.gpg

# Memory security statistics
claude-memory-cleaner stats | grep -E "size|sensitive|projects"

# Test memory recovery
cp -r .claude/memory .claude/memory.test.backup
rm -rf .claude/memory
cp -r .claude/memory.test.backup .claude/memory

# Verify memory permissions
find .claude/memory -type f ! -perm 600 -o -type d ! -perm 700
```

## Security Philosophy for Hobby Developers

This security system is designed to be:
- **Simple to understand**: Clear documentation, minimal configuration
- **Easy to maintain**: Automated monitoring, intelligent defaults
- **Appropriate for personal use**: Balanced security without enterprise overhead
- **Recoverable**: Clear recovery procedures, good backup practices

Perfect for developers who want solid security for their personal projects without needing a cybersecurity degree! 🔒