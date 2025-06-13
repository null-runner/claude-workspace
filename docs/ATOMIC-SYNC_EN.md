# Atomic Workspace Sync - Technical Design

## Overview

The Atomic Workspace Sync system solves the critical problem of **infinite loops** that occur when trying to sync a workspace where an autonomous system continuously updates files every 30 seconds.

## Problem Statement

- **Autonomous System**: Updates files every 30s (project detection), 5min (context), 15min (intelligence)
- **Sync Requirements**: Full bi-directional sync between devices
- **Core Conflict**: Sync operations and autonomous system both modify workspace state simultaneously
- **Result**: Infinite loops, data corruption, sync failures

## Solution Architecture

### **Atomic Coordination Strategy**

The solution implements **Lockfile-Based Snapshots** with **Event Queue Coordination**:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Autonomous     │    │   Atomic Sync   │    │   Remote Repo   │
│  System         │    │   Coordinator   │    │                 │
│                 │    │                 │    │                 │
│ • Context (5m)  │◄──►│ • Lock Manager  │◄──►│ • Git Remote    │
│ • Projects (30s)│    │ • Snapshots     │    │ • Deploy Keys   │
│ • Intel (15m)   │    │ • Rollback      │    │ • Audit Trail   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Key Components**

1. **`claude-atomic-sync.sh`** - Core atomic operations
2. **`claude-full-workspace-sync.sh`** - Smart sync orchestration  
3. **Modified `claude-autonomous-system.sh`** - Lockfile awareness
4. **Snapshot System** - Atomic state capture with rollback

## Atomic Operations Flow

### **Phase 1: Lock Acquisition**
```bash
1. Check for existing sync lock → Exit if locked
2. Create sync lock file with PID
3. Signal autonomous system to pause
4. Wait for autonomous system acknowledgment
```

### **Phase 2: Snapshot Creation**
```bash
1. Create git bundle of current state
2. Capture uncommitted changes (diff)
3. Record metadata (timestamp, commit hash, file count)
4. Store in atomic snapshot directory
```

### **Phase 3: Sync Operation**
```bash
1. Stash uncommitted changes
2. Perform git pull with conflict resolution
3. Restore stashed changes with merge
4. Add/commit/push if changes exist
```

### **Phase 4: Cleanup & Resume**
```bash
1. Remove pause signal for autonomous system
2. Release sync lock
3. Log operation results
4. Clean up old snapshots
```

## Conflict Prevention Mechanisms

### **1. Lockfile Coordination**
- **Sync Lock**: `/.claude/sync/sync.lock` prevents concurrent sync operations
- **Pause Signal**: `/.claude/autonomous/sync-pause.lock` signals autonomous system to pause
- **Timeout Protection**: 5-minute maximum pause duration

### **2. Autonomous System Integration**
The autonomous system now checks for sync pause before file operations:

```bash
# Check for sync pause before file operations
if check_sync_pause; then
    wait_for_sync_completion "SERVICE_NAME"
fi
```

### **3. Smart Sync Decision Engine**
```bash
# Intelligent sync decisions based on:
- File change threshold (default: 50 files)
- Time since last sync (default: 5 minutes minimum)  
- Sync reason (startup, scheduled, manual, threshold)
- Configuration settings
```

## Usage Examples

### **Manual Sync Operations**
```bash
# Basic atomic sync (pull + push)
./scripts/claude-atomic-sync.sh sync

# Pull only
./scripts/claude-atomic-sync.sh pull

# Push only  
./scripts/claude-atomic-sync.sh push

# Check status
./scripts/claude-atomic-sync.sh status
```

### **Smart Sync with Decision Engine**
```bash
# Smart sync with reason
./scripts/claude-full-workspace-sync.sh sync startup

# Force sync (bypass timing constraints)
./scripts/claude-full-workspace-sync.sh force-sync

# Enable auto-sync every 60 minutes
./scripts/claude-full-workspace-sync.sh config enable
./scripts/claude-full-workspace-sync.sh config interval 60
./scripts/claude-full-workspace-sync.sh start-scheduler
```

### **Configuration Management**
```bash
# View current configuration
./scripts/claude-full-workspace-sync.sh config show

# Configure sync behavior
./scripts/claude-full-workspace-sync.sh config enable
./scripts/claude-full-workspace-sync.sh config interval 30

# Start/stop automatic sync scheduler
./scripts/claude-full-workspace-sync.sh start-scheduler
./scripts/claude-full-workspace-sync.sh stop-scheduler
```

## Safety Mechanisms

### **1. Rollback Capability**
Every sync operation creates an atomic snapshot that can be used for rollback:
```bash
# Snapshots stored in /.claude/sync/snapshots/
# Format: sync_YYYYMMDD_HHMMSS_PID.{bundle,meta,diff}
```

### **2. Error Recovery**
- Automatic stash restoration on pull failures
- Graceful handling of network timeouts
- Preservation of uncommitted changes
- Cleanup of stale lock files

### **3. Audit Trail**
Complete logging of all sync operations:
```bash
# Atomic sync log
tail -f /.claude/sync/sync.log

# Autonomous system log
tail -f /.claude/autonomous/autonomous-system.log
```

## Performance Characteristics

### **Timing Constraints**
- **Sync Lock Timeout**: 10 minutes maximum
- **Autonomous Pause**: 5 minutes maximum
- **Minimum Sync Interval**: 5 minutes (configurable)
- **Snapshot Cleanup**: Keep 10 most recent (configurable)

### **Resource Usage**
- **Disk**: ~50MB per snapshot (varies by workspace size)
- **Memory**: Minimal (background processes)
- **Network**: Only during actual sync operations
- **CPU**: Low impact (pause/resume coordination)

## Advanced Features

### **1. Conflict Resolution Strategies**
```json
{
    "conflict_resolution": {
        "strategy": "manual",           // manual, auto-ours, auto-theirs
        "auto_commit_threshold": 10     // max files for auto-commit
    }
}
```

### **2. Sync Filters**
```json
{
    "filters": {
        "exclude_patterns": [
            "*.tmp", "*.log", ".DS_Store",
            "node_modules/", ".git/hooks/",
            ".claude/autonomous/*.pid"
        ]
    }
}
```

### **3. Monitoring & Alerting**
```json
{
    "monitoring": {
        "max_file_changes_before_sync": 50,
        "min_time_between_syncs": 300,
        "alert_on_sync_failure": true
    }
}
```

## Troubleshooting

### **Common Issues**

1. **Sync Lock Stuck**
   ```bash
   # Emergency stop all sync operations
   ./scripts/claude-full-workspace-sync.sh emergency-stop
   ```

2. **Autonomous System Not Pausing**
   ```bash
   # Check autonomous system status
   ./scripts/claude-autonomous-system.sh status
   
   # Restart autonomous system
   ./scripts/claude-autonomous-system.sh restart
   ```

3. **Snapshot Disk Usage**
   ```bash
   # Clean up old snapshots (keep last 5)
   ./scripts/claude-atomic-sync.sh cleanup 5
   ```

4. **Network/Authentication Issues**
   ```bash
   # Check SSH key configuration
   ls -la ~/.claude-access/keys/
   
   # Test manual git operations
   git pull origin main
   ```

## Integration Points

### **Startup Sequence**
1. `claude-startup.sh` → Starts autonomous system
2. `claude-full-workspace-sync.sh sync startup` → Initial sync
3. `claude-full-workspace-sync.sh start-scheduler` → Auto-sync scheduling

### **Exit Sequence**  
1. `claude-autonomous-exit.sh` → Triggers exit sync
2. `claude-full-workspace-sync.sh sync exit` → Final sync
3. `claude-full-workspace-sync.sh stop-scheduler` → Stop auto-sync

## Technical Specifications

### **File Structure**
```
/.claude/sync/
├── sync-config.json          # Configuration
├── sync.lock                 # Active sync lock  
├── schedule.pid              # Scheduler PID
├── last-sync-timestamp       # Timing control
├── sync.log                  # Operation log
└── snapshots/                # Atomic snapshots
    ├── sync_20250613_195805_1234.bundle
    ├── sync_20250613_195805_1234.meta
    ├── sync_20250613_195805_1234.diff
    └── sync_20250613_195805_1234.result
```

### **Lock File Format**
```bash
# Sync lock: /.claude/sync/sync.lock
<PID>

# Pause signal: /.claude/autonomous/sync-pause.lock  
<SYNC_PID>
<TIMESTAMP>
<REASON>
```

### **Snapshot Metadata**
```json
{
    "snapshot_id": "sync_20250613_195805_1234",
    "timestamp": "2025-06-13T19:58:05Z",
    "git_commit": "9e015b5a1...",
    "git_status_files": 16,
    "autonomous_status": "paused"
}
```

This atomic sync system provides **zero data loss**, **system continuity**, and **performance** while maintaining **simplicity** and **recoverability** - solving the infinite loop problem through careful coordination between autonomous and sync operations.