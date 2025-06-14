# Complete Setup Guide - Claude Workspace Enterprise

[🇺🇸 English](setup-en.md) | [🇮🇹 Italiano](setup-it.md)

This guide covers the complete setup of Claude Workspace Enterprise-Grade system for both desktop PC and laptop. The system now features enterprise components for maximum robustness and performance.

## Desktop PC Setup

### Prerequisites
- Ubuntu/Debian or compatible Linux system
- Git installed
- SSH access configured
- Python 3.x (required for enterprise components)
- **New**: jq (JSON processor) for coordinators
- **New**: flock utility for file locking
- **Minimum**: 2GB free RAM for autonomous system
- **Recommended**: SSD for optimal performance

### Step-by-Step Installation

1. **Clone or create base structure**:
   ```bash
   cd ~
   git clone <repository-url> claude-workspace
   # or
   mkdir -p ~/claude-workspace/{projects/{active,sandbox,production},scripts,configs,logs,docs}
   ```

2. **Run enterprise setup script**:
   ```bash
   cd ~/claude-workspace
   chmod +x setup.sh
   ./setup.sh --enterprise
   ```
   
   **Note**: The `--enterprise` flag enables advanced components:
   - Process coordination system
   - Advanced file locking
   - Enterprise automatic backup
   - Performance monitoring

3. **What setup.sh --enterprise does**:
   - Creates all necessary directories (including enterprise)
   - Sets correct permissions (755 for directories, 644 for files)
   - Creates access control file with process protection
   - Generates enterprise management scripts
   - Configures multi-level logging
   - **New**: Initializes coordinators (memory, sync, project)
   - **New**: Configures distributed lock system
   - **New**: Installs monitoring components
   - **New**: Sets up automatic log rotation

4. **Verify enterprise installation**:
   ```bash
   ~/claude-workspace/scripts/claude-startup.sh
   ```

   Expected enterprise output:
   ```
   🚀 CLAUDE WORKSPACE ENTERPRISE STARTUP
   =====================================
   📍 Autonomous System: ACTIVE
   🎯 Coordinators: OK (3/3)
   🔒 File Locking: ENABLED
   📊 Monitoring: HEALTHY
   🧠 Memory: LOADED
   🔄 Sync: READY
   
   ✅ Enterprise system fully operational
   ```

5. **Initialize enterprise memory system**:
   ```bash
   # Start memory coordinator
   ~/claude-workspace/scripts/claude-memory-coordinator.sh start
   
   # Initialize global workspace memory
   ~/claude-workspace/scripts/claude-simplified-memory.sh save "Claude Workspace Enterprise system initialized"
   
   # Verify functionality
   ~/claude-workspace/scripts/claude-simplified-memory.sh load
   ```

   Expected output:
   ```
   🧠 ENTERPRISE WORKSPACE MEMORY
   ===============================
   📍 LAST SESSION:
      When: A few seconds ago (hostname)
      Last note: Claude Workspace Enterprise system initialized
      Coordinator: ACTIVE
   ```

### SSH Configuration

1. **Generate SSH keys (if not existing)**:
   ```bash
   ssh-keygen -t ed25519 -C "claude-workspace"
   ```

2. **Configure authorized_keys**:
   ```bash
   # setup.sh should have already configured this
   cat ~/.ssh/authorized_keys | grep "claude-workspace"
   ```

3. **Test connection**:
   ```bash
   ssh nullrunner@localhost
   ```

## Laptop Setup

### Method 1: Quick Setup (Recommended)

1. **On desktop PC, start temporary server**:
   ```bash
   cd ~/claude-workspace
   python3 -m http.server 8000
   ```

2. **On laptop, download and execute**:
   ```bash
   curl -o laptop-setup.sh http://192.168.1.106:8000/scripts/setup-laptop.sh
   chmod +x laptop-setup.sh
   ./laptop-setup.sh
   ```

3. **Enter SSH key when prompted**

### Method 2: Manual Setup

1. **Create directory structure**:
   ```bash
   mkdir -p ~/claude-workspace/{projects/{active,sandbox,production},scripts,logs}
   ```

2. **Copy necessary scripts**:
   ```bash
   scp nullrunner@192.168.1.106:~/claude-workspace/scripts/{sync-now.sh,auto-sync.sh,sync-status.sh} ~/claude-workspace/scripts/
   chmod +x ~/claude-workspace/scripts/*.sh
   ```

3. **Configure SSH**:
   ```bash
   # Generate SSH key
   ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key -C "laptop-claude"
   
   # Copy public key to desktop PC
   ssh-copy-id -i ~/.ssh/claude_workspace_key nullrunner@192.168.1.106
   ```

4. **Configure SSH config**:
   ```bash
   cat >> ~/.ssh/config << EOF
   Host claude-desktop
       HostName 192.168.1.106
       User nullrunner
       IdentityFile ~/.ssh/claude_workspace_key
       StrictHostKeyChecking no
       UserKnownHostsFile /dev/null
   EOF
   ```

5. **Initial test**:
   ```bash
   ~/claude-workspace/scripts/sync-now.sh
   ```

6. **Initialize memory on laptop**:
   ```bash
   # After first sync, memory should already be synced
   # Verify functionality
   claude-resume
   
   # If not working, initialize manually
   claude-save "Laptop setup completed"
   
   # Test per-project memory
   cd ~/claude-workspace/projects/active
   mkdir test-project
   cd test-project
   claude-project-memory save "Test project initialized"
   ```

### Automatic Sync Configuration

1. **Enable automatic sync**:
   ```bash
   ~/claude-workspace/scripts/auto-sync.sh enable
   ```

2. **Verify crontab**:
   ```bash
   crontab -l | grep claude-workspace
   ```

   Should show:
   ```
   */5 * * * * ~/claude-workspace/scripts/sync-now.sh >> ~/claude-workspace/logs/auto-sync.log 2>&1
   ```

3. **Monitor logs**:
   ```bash
   tail -f ~/claude-workspace/logs/auto-sync.log
   ```

## Safe Exit Enterprise System

### 🗂️ cexit Command (Recommended)

To safely exit the enterprise system:

```bash
# Safe exit keeping session open (recommended)
~/claude-workspace/scripts/cexit-safe

# Complete exit with Claude Code termination
~/claude-workspace/scripts/cexit

# Exit with forced sync
~/claude-workspace/scripts/cexit --force-sync
```

**Important**: 
- **DO NOT use** normal `exit` - doesn't trigger graceful shutdown
- **Always use** `cexit` or `cexit-safe` to preserve system state
- Enterprise system requires coordinated shutdown

### What cexit does
1. 💾 Automatically saves session state
2. 🔄 Final intelligent sync
3. 📊 Updates performance statistics
4. 🔒 Releases all locks
5. 🚫 Terminates background services
6. 🔍 Analyzes session activity for insights

## Enterprise Troubleshooting

### Problem: Enterprise memory system not working

**Symptoms**: Memory coordinator not responding or memory not syncing

**Enterprise Solutions**:
```bash
# Verify memory coordinator
~/claude-workspace/scripts/claude-memory-coordinator.sh status

# Restart coordinator if needed
~/claude-workspace/scripts/claude-memory-coordinator.sh restart

# Verify enterprise structure
ls -la ~/claude-workspace/.claude/memory-coordination/
ls -la ~/claude-workspace/.claude/logs/

# Test memory with coordinator
~/claude-workspace/scripts/claude-simplified-memory.sh save "Enterprise memory test"
~/claude-workspace/scripts/claude-simplified-memory.sh load

# Verify lock files
ls -la ~/claude-workspace/.claude/*.lock

# Clean locks if stuck
~/claude-workspace/scripts/claude-sync-lock.sh cleanup
```

### Problem: Memory doesn't sync between devices

**Cause**: `.claude/memory/` directory not included in sync

**Solution**:
```bash
# Check .rsync-exclude file
cat ~/claude-workspace/.rsync-exclude | grep -v "^#" | grep "claude"

# If .claude is excluded, remove it
sed -i '/\.claude/d' ~/claude-workspace/.rsync-exclude

# Force memory sync
rsync -avz ~/claude-workspace/.claude/ nullrunner@192.168.1.106:~/claude-workspace/.claude/
```

### Problem: "Permission denied" during SSH

**Cause**: SSH key not recognized or wrong permissions

**Solution**:
```bash
# On laptop
ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key
cat ~/.ssh/claude_workspace_key.pub

# On desktop PC
echo "PUBLIC_KEY_HERE" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Problem: "Connection refused" on port 22

**Cause**: SSH server not active on desktop PC

**Solution**:
```bash
# On desktop PC
sudo systemctl status ssh
sudo systemctl start ssh
sudo systemctl enable ssh
```

### Problem: Sync fails silently

**Cause**: Network or configuration issues

**Debug**:
```bash
# Test direct connection
ssh -v nullrunner@192.168.1.106

# Test manual rsync
rsync -avz --dry-run ~/claude-workspace/projects/ nullrunner@192.168.1.106:~/claude-workspace/projects/
```

### Problem: Lock file stuck

**Symptom**: "Another sync is already running" message

**Solution**:
```bash
# On laptop
rm ~/claude-workspace/.sync.lock

# Check for zombie rsync processes
ps aux | grep rsync
# If necessary: killall rsync
```

### Problem: Insufficient disk space

**Check**:
```bash
# On both systems
df -h ~/claude-workspace
du -sh ~/claude-workspace/*
```

**Cleanup**:
```bash
# Remove old logs
find ~/claude-workspace/logs -name "*.log" -mtime +30 -delete

# Archive old projects
tar -czf ~/backups/old-projects-$(date +%Y%m%d).tar.gz ~/claude-workspace/projects/production/old-project
rm -rf ~/claude-workspace/projects/production/old-project
```

## Advanced Configurations

### Exclude files from sync

Create `~/claude-workspace/.rsync-exclude`:
```
*.tmp
*.log
node_modules/
__pycache__/
.git/
*.swp
.DS_Store
```

### Modify sync frequency

Edit crontab:
```bash
crontab -e
# Change */5 to */10 for sync every 10 minutes
```

### Automatic backup

Add to crontab on desktop PC:
```bash
0 2 * * * tar -czf ~/backups/claude-workspace-$(date +\%Y\%m\%d).tar.gz ~/claude-workspace/
```

## Post-Setup Verification

### Desktop PC Enterprise Checklist
- [ ] Directory structure created (including enterprise)
- [ ] Scripts executable (all coordinators)
- [ ] SSH server active
- [ ] Access control configured
- [ ] Log directory writable + rotation
- [ ] **Autonomous system started**: `claude-startup.sh`
- [ ] **Coordinators active**: memory, sync, project
- [ ] **Enterprise memory system**: `claude-simplified-memory.sh`
- [ ] **File locking system**: `claude-sync-lock.sh`
- [ ] **Performance monitoring**: `claude-autonomous-system.sh status`
- [ ] **Safe exit**: `cexit` and `cexit-safe` working
- [ ] **Backup cleaner**: `claude-backup-cleaner.sh` configured
- [ ] **Log rotator**: `claude-log-rotator.sh` active

### Laptop Enterprise Checklist
- [ ] SSH key configured
- [ ] SSH connection working
- [ ] **Enterprise sync coordinators active**
- [ ] **Smart sync enterprise**: `claude-smart-sync.sh`
- [ ] **Autonomous system synchronized**
- [ ] **Cross-device coordinated memory**
- [ ] **Enterprise locks working**
- [ ] **Safe exit configured**: `cexit-safe`
- [ ] **Automatic recovery**: `claude-startup.sh --recovery`
- [ ] **Performance monitoring**: enterprise logs
- [ ] **Test project with coordinators completed**

## Useful Debug Commands

```bash
# Verify connectivity
ping -c 3 192.168.1.106
nc -zv 192.168.1.106 22

# Debug SSH
ssh -vvv nullrunner@192.168.1.106

# Test rsync with verbose output
rsync -avz --dry-run --progress ~/claude-workspace/projects/ nullrunner@192.168.1.106:~/claude-workspace/projects/

# Check system logs
journalctl -u ssh -f  # On desktop PC
tail -f /var/log/auth.log  # On desktop PC

# Monitor sync in real time
watch -n 1 'ls -la ~/claude-workspace/.sync.lock; tail -5 ~/claude-workspace/logs/sync.log'

# Debug memory system
# Verify memory structure
find ~/claude-workspace/.claude/memory -type f -name "*.json" | head -10

# Test memory commands
claude-save "Memory system test" && claude-resume

# Verify memory size
du -sh ~/claude-workspace/.claude/memory/

# List projects with memory
claude-project-memory list

# Memory statistics
claude-memory-cleaner stats

# Test cross-device memory sync
rsync -avz --dry-run ~/claude-workspace/.claude/ nullrunner@192.168.1.106:~/claude-workspace/.claude/
```

## Setup Philosophy for Hobby Developers

This setup is designed to be:
- **Beginner-friendly**: Clear instructions, sensible defaults
- **Low maintenance**: Automated operations, intelligent monitoring
- **Recoverable**: Good backup practices, clear troubleshooting
- **Scalable**: Easy to add new devices or projects

Perfect for developers who want professional-grade tools without enterprise complexity! 🚀

## Next Steps

After successful setup:
1. Read the [Workflow Guide](../guides/workflow-en.md) to learn development patterns
2. Review [Security Guide](../guides/security/security-en.md) for protection best practices  
3. Explore the [Memory System Guide](../guides/memory-system-en.md) for advanced features
4. Create your first project and enjoy seamless multi-device development!

Welcome to the Claude Workspace family - where your code follows you everywhere! 🎉