# 🤖 Auto-Memory System

**Complete Autonomous Memory Management for Claude Workspace**

---

## 🎯 Overview

The Auto-Memory System is a revolutionary background daemon that provides **completely autonomous session persistence** for Claude Workspace. It monitors your work, intelligently detects when to save, and ensures you never lose context - even if Claude crashes unexpectedly.

### Key Features
- 🔄 **Automatic saving** every 5 minutes when significant activity detected
- 🛡️ **Crash recovery** - never lose work even during unexpected termination
- 🧠 **Smart detection** - only saves when meaningful work has been done
- ⚡ **Background operation** - works invisibly without interrupting workflow
- 🚨 **Emergency saves** - captures state on system signals (SIGTERM, SIGINT)
- 📊 **Activity scoring** - intelligent algorithm determines save worthiness

---

## 🏗️ Architecture

### Components

```
Auto-Memory System
├── 🤖 claude-auto-memory.sh     ← Main daemon controller
├── 🚀 claude-startup.sh         ← Auto-service launcher
├── 🧠 Activity Detection Engine  ← Monitors git, files, tools
├── 💾 Enhanced Save Integration  ← Uses existing save system
├── 🔄 Rate Limiting System      ← Prevents excessive saves
└── 📊 Recovery Manager          ← Handles crash restoration
```

### Data Flow

```
File Changes → Activity Detection → Score Calculation → Save Decision
     ↓              ↓                    ↓                 ↓
Git Activity   Tool Usage         Score ≥ Threshold?   Auto-Save
File Mods     Recent Activity      Rate Limit OK?      + Log Action
```

---

## 🔧 How It Works

### 1. Activity Detection

The system continuously monitors:

**Git Changes** (Score: 2x per file)
- Modified files (`git status --porcelain`)
- Staged changes
- New untracked files

**File Activity** (Score: 1x per file)
- Recently modified files (last 10 minutes)
- Creation/deletion events
- Cross-directory activity

**Tool Usage** (Score: 2x per tool)
- Log file modifications in `.claude/`
- Script executions
- System tool interactions

### 2. Intelligent Scoring

```python
total_score = (git_changes * 2) + file_activity + tool_usage

# Save thresholds:
# Score ≥ 3  → Auto-save triggered
# Score < 3  → Skip save (insufficient activity)
```

### 3. Rate Limiting

- **Maximum**: 12 auto-saves per hour
- **Minimum interval**: 2 minutes between saves
- **Fallback**: Forced save every 30 minutes if any changes exist

### 4. Emergency Recovery

**Signal Handlers**:
- `SIGTERM` → Emergency save + graceful exit
- `SIGINT` → Emergency save + immediate exit
- `EXIT` → Cleanup lock files

**Crash Detection**:
- Recovery marker created on startup
- Removed only on clean exit
- Next session detects marker → triggers recovery

---

## 🚀 Usage

### Starting the Auto-Memory Daemon

**Automatic** (Recommended):
```bash
# Claude automatically runs this on startup per CLAUDE.md
./scripts/claude-startup.sh
```

**Manual Control**:
```bash
# Start daemon in background
./scripts/claude-auto-memory.sh start

# Check daemon status
./scripts/claude-auto-memory.sh status

# Stop daemon
./scripts/claude-auto-memory.sh stop

# View real-time logs
./scripts/claude-auto-memory.sh logs
```

### Testing & Debugging

```bash
# Test activity detection algorithm
./scripts/claude-auto-memory.sh test

# Force immediate save (ignores rate limits)
./scripts/claude-auto-memory.sh force-save

# Check recent activity logs
tail -f ~/.claude/auto-memory/auto-memory.log
```

---

## 📊 Monitoring & Logs

### Log Locations

```
~/.claude/auto-memory/
├── auto-memory.log          ← Main activity log
├── auto-memory.lock         ← Daemon PID lock file
├── rate_limit_YYYYMMDDHH    ← Hourly rate counters
└── emergency_recovery_needed ← Crash recovery marker
```

### Log Format

```
[2025-06-13 16:00:24] [INFO] Auto-memory avviato (PID: 12345)
[2025-06-13 16:05:30] [SUCCESS] Auto-save completed: Significant activity detected (score: 15)
[2025-06-13 16:10:45] [WARN] Rate limit reached for hour 2025061316 (12 saves)
[2025-06-13 16:15:00] [EMERGENCY] Emergency save triggered
```

### Status Information

```bash
$ ./scripts/claude-auto-memory.sh status
Auto-memory daemon RUNNING (PID: 12345)
Log file: /home/user/.claude/auto-memory/auto-memory.log

Ultime attività:
  [2025-06-13 16:00:24] [INFO] Auto-memory avviato (PID: 12345)
  [2025-06-13 16:05:30] [SUCCESS] Auto-save completed: score 15
```

---

## ⚙️ Configuration

### Environment Variables

```bash
# Auto-save interval (seconds)
AUTO_SAVE_INTERVAL=300              # Default: 5 minutes

# Activity score threshold for auto-save
SIGNIFICANT_CHANGES_THRESHOLD=3     # Default: 3 points

# Maximum auto-saves per hour
MAX_AUTO_SAVES_PER_HOUR=12         # Default: 12 saves

# Message count threshold
MESSAGE_COUNT_THRESHOLD=5          # Default: 5 messages
```

### Customizing Thresholds

Edit `claude-auto-memory.sh` to adjust:

```bash
# More aggressive saving (saves more often)
SIGNIFICANT_CHANGES_THRESHOLD=2
MAX_AUTO_SAVES_PER_HOUR=20

# More conservative saving (saves less often)  
SIGNIFICANT_CHANGES_THRESHOLD=5
MAX_AUTO_SAVES_PER_HOUR=6
```

---

## 🛡️ Crash Recovery

### How Recovery Works

1. **Startup Detection**:
   ```bash
   # Recovery marker exists?
   if [[ -f "$recovery_dir/emergency_recovery_needed" ]]; then
       echo "🚨 Recovery necessario: rilevato crash sessione precedente"
   ```

2. **Automatic Recovery**:
   ```bash
   # Attempt auto-recovery
   ./scripts/claude-enhanced-save.sh "Emergency recovery - restoring from crash"
   ```

3. **Recovery Success**:
   - Marker removed
   - Last session context restored
   - Memory files updated
   - Normal operation resumed

### Manual Recovery

If automatic recovery fails:

```bash
# Check for recovery markers
ls ~/.claude/auto-memory/emergency_recovery_needed

# Manual recovery attempt
./scripts/claude-enhanced-save.sh "Manual recovery session"

# Clean up recovery markers
rm ~/.claude/auto-memory/emergency_recovery_needed
```

---

## 🔍 Troubleshooting

### Common Issues

**Daemon Won't Start**:
```bash
# Check for stale lock files
rm ~/.claude/auto-memory/auto-memory.lock

# Check permissions
chmod +x scripts/claude-auto-memory.sh

# Check dependencies
which python3 git
```

**No Auto-Saves Happening**:
```bash
# Test activity detection
./scripts/claude-auto-memory.sh test

# Check rate limits
ls ~/.claude/auto-memory/rate_limit_*

# Verify daemon is running
./scripts/claude-auto-memory.sh status
```

**High CPU Usage**:
```bash
# Increase monitoring interval
export AUTO_SAVE_INTERVAL=600  # 10 minutes

# Restart daemon with new settings
./scripts/claude-auto-memory.sh stop
./scripts/claude-auto-memory.sh start
```

### Debug Mode

Enable verbose logging:

```bash
# Edit claude-auto-memory.sh, uncomment:
# echo -e "${CYAN}[AUTO-MEMORY]${NC} $message"

# Restart daemon to see real-time activity
./scripts/claude-auto-memory.sh stop
./scripts/claude-auto-memory.sh start
```

---

## 🔮 Advanced Features

### Integration with Other Tools

**Activity Tracker Integration**:
```bash
# Auto-memory coordinates with activity tracker
# Shared activity detection prevents duplicate work
```

**Smart Exit Integration**:
```bash
# Smart exit uses auto-memory detection algorithms
# Provides consistent activity analysis across tools
```

**Enhanced Save Integration**:
```bash
# Auto-memory uses enhanced save for all operations
# Maintains consistency with manual saves
```

### Custom Activity Detection

Add custom activity sources by editing the `detect_significant_activity()` function:

```python
def check_custom_activity():
    """Add your custom activity detection here"""
    score = 0
    
    # Example: Check Docker container activity
    if docker_containers_running():
        score += 3
    
    # Example: Check VS Code workspace changes
    if vscode_workspace_modified():
        score += 2
        
    return score
```

---

## 📈 Performance

### Resource Usage

- **CPU**: Minimal (monitoring every 5 minutes)
- **Memory**: ~10MB for daemon process
- **Disk**: Log files auto-rotate daily
- **Network**: Zero (local operations only)

### Optimization Tips

1. **Adjust monitoring interval** for less frequent checking
2. **Increase score threshold** for fewer auto-saves
3. **Set lower rate limits** for reduced disk I/O
4. **Use SSD storage** for faster save operations

---

## 🎯 Best Practices

### Production Usage

1. **Always start via claude-startup.sh** for consistency
2. **Monitor logs regularly** for unusual activity
3. **Set appropriate rate limits** for your workflow
4. **Test recovery procedures** periodically
5. **Keep daemon logs** for troubleshooting

### Development Usage

1. **Use test mode** to understand activity detection
2. **Adjust thresholds** based on your work patterns
3. **Force saves** during critical work
4. **Monitor daemon status** during development

---

## 🤝 Contributing

### Adding Features

1. **Fork the repository**
2. **Create feature branch**
3. **Add your enhancement** to `claude-auto-memory.sh`
4. **Test thoroughly** with different scenarios
5. **Submit pull request** with documentation

### Reporting Issues

Include in bug reports:
- Daemon status output
- Recent log entries
- System information (OS, shell, Python version)
- Steps to reproduce the issue

---

**The Auto-Memory System ensures you never lose work again, operating silently in the background to preserve your development context across all sessions.** 🚀