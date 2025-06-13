# 🧠 Intelligent Memory System - Claude Workspace

[🇺🇸 English](memory-system-en.md) | [🇮🇹 Italiano](memory-system-it.md)

## 📖 Overview

Claude Workspace's memory system provides seamless continuity between sessions and projects, maintaining context without cluttering your system thanks to intelligent automatic cleanup - perfect for hobby developers who want powerful features without complexity.

## 🏗️ Architecture

### Global Workspace Memory
```
.claude/memory/
├── workspace-memory.json     # Global workspace memory
└── projects/                 # Project-specific memory
    ├── active_website-bar.json
    ├── sandbox_test-app.json
    └── production_api.json
```

### Per-Project Memory
Each project maintains:
- **Current state**: last activity, active files, recent notes
- **Session history**: work chronology
- **TODOs and goals**: active and completed tasks
- **Technical notes**: setup, architecture, dependencies
- **Archived data**: intelligently compacted information

## 🔄 Intelligent Cleanup System

### What's ALWAYS Kept (Core Memory)
- ✅ **Current project state** (last save)
- ✅ **Main objective** and current milestone
- ✅ **Active TODOs** (not completed)
- ✅ **Technical notes** (architecture, setup)
- ✅ **Main existing files**

### What's Gradually Cleaned (Sliding Memory)
- 🔄 **Session history**: keeps last 20 → compacts old ones
- 🔄 **Temporary notes**: keeps last 10 → archives important ones
- 🔄 **Completed TODOs**: keeps last 15 → archives statistics
- 🔄 **Active files**: verifies existence → removes deleted files

### Compaction Algorithm
1. **Analyzes patterns**: detects recurring behaviors
2. **Extracts key information**: important notes, reached milestones
3. **Creates summaries**: summaries of archived sessions
4. **Maintains metrics**: completion statistics
5. **Preserves context**: essential information for continuity

## 📱 Available Commands

### Global Memory
```bash
claude-save "session note"           # Save current state
claude-resume                        # Resume last session
claude-memory                        # Manage global memory
claude-memory context "objective"    # Update objectives
```

### Project Memory
```bash
claude-project-memory save "note"     # Save project state
claude-project-memory resume          # Resume current project
claude-project-memory todo add "task" # Add TODO
claude-project-memory todo list       # List TODOs
claude-project-memory todo done 1     # Complete TODO
```

### Memory Cleanup
```bash
claude-memory-cleaner auto            # Automatic cleanup
claude-memory-cleaner stats           # Memory statistics
claude-memory-cleaner project name    # Clean specific project
```

## 🤖 Automation

### Auto-Save
- **Trigger**: every file modification (via auto-sync)
- **Frequency**: when detecting changes
- **Scope**: both global and per-project memory

### Auto-Cleanup
- **Frequency**: once daily
- **Trigger**: during auto-sync
- **Intelligence**: preserves important information
- **Thresholds**: 
  - Files > 50KB → compaction
  - Last cleanup > 7 days → re-compaction

## 💾 Data Format

### Project Memory Example
```json
{
  "project_info": {
    "name": "website-bar",
    "type": "active", 
    "created_at": "2025-06-13T01:00:00Z"
  },
  "current_context": {
    "last_activity": "2025-06-13T01:30:00Z",
    "current_task": "Menu implementation",
    "active_files": ["index.html", "menu.css"],
    "notes": [
      {
        "content": "Completed homepage, now working on menu",
        "timestamp": "2025-06-13T01:30:00Z"
      }
    ],
    "todo": [
      {
        "id": 1,
        "description": "Add contact form",
        "status": "pending"
      }
    ]
  },
  "session_history": [...],
  "archived_data": {
    "session_summaries": [...],
    "important_notes": [...],
    "completion_stats": {...}
  }
}
```

## 🎯 Typical Workflow

### Starting Session
```bash
# On desktop
claude-resume                     # See last project
cd ~/claude-workspace/projects/active/website-bar
claude-project-memory resume     # Project-specific context
```

### During Work
```bash
# Auto-save automatic on each modification
# Or manual:
claude-project-memory save "Completed header"
claude-project-memory todo add "Test responsive design"
```

### End Session
```bash
claude-save "Tomorrow: implement shopping cart"
claude-project-memory save "Menu completed, only footer missing"
```

### Resume on Laptop
```bash
# On laptop (after automatic sync)
claude-resume                     # See: "Tomorrow: implement shopping cart"
cd ~/claude-workspace/projects/active/website-bar  
claude-project-memory resume     # See: "Menu completed, only footer missing"
```

## 🔧 Configuration

### Cleanup Settings
Modify `.claude/memory/workspace-memory.json`:
```json
{
  "settings": {
    "auto_save_interval": 300,        # seconds between auto-saves
    "max_history_days": "infinite",   # base retention
    "context_retention": "detailed",  # detail level
    "cleanup_frequency": "daily"      # cleanup frequency
  }
}
```

### Compaction Thresholds
Modify `scripts/claude-memory-cleaner.sh`:
```bash
# Thresholds for compaction
MAX_SESSIONS=20          # sessions per project
MAX_NOTES=10            # temporary notes
MAX_COMPLETED_TODOS=15  # completed TODOs
MAX_FILE_SIZE=50000     # bytes before compaction
```

## 🛠️ Maintenance

### Memory Backup
```bash
# Complete backup
cp -r .claude/memory .claude/memory.backup.$(date +%Y%m%d)

# Specific project backup
cp .claude/memory/projects/active_website-bar.json /backup/
```

### Recovery
```bash
# Restore from backup
cp -r .claude/memory.backup.20250613 .claude/memory

# Restore specific project
cp /backup/active_website-bar.json .claude/memory/projects/
```

### Debug
```bash
# Verify memory state
claude-memory-cleaner stats

# Check cleanup logs
tail -f logs/sync.log | grep "memory"

# Test single project compaction
claude-memory-cleaner project active/website-bar
```

## 🚨 Troubleshooting

### Corrupted Memory
```bash
# Complete reset (WARNING: deletes everything)
rm -rf .claude/memory
claude-save "Memory reinitialization"
```

### Project Not Detected
```bash
# Verify path
pwd  # Must be in ~/claude-workspace/projects/type/name

# Initialize manually
claude-project-memory save "Manual initialization"
```

### Cleanup Not Working
```bash
# Force cleanup
claude-memory-cleaner auto --force

# Verify permissions
ls -la .claude/memory/
chmod 755 .claude/memory/
```

## 📊 Monitoring

### Key Metrics
- **Total memory size**: < 10MB recommended
- **Active projects**: memory < 100KB per project
- **Cleanup frequency**: once daily
- **Compaction ratio**: ~70% reduction after cleanup

### Automatic Alerts
The system warns when:
- Project memory > 200KB (suggests cleanup)
- Total memory > 20MB (forced cleanup)
- Last cleanup > 14 days (scheduled cleanup)

## 🎯 Best Practices

### For Performance
- ✅ Use `claude-save` with descriptive notes
- ✅ Complete TODOs when finished  
- ✅ Let automatic cleanup work
- ❌ Don't disable auto-cleanup
- ❌ Don't accumulate non-existent active files

### For Continuity
- ✅ Always save before switching projects
- ✅ Use technical notes for complex setups
- ✅ Keep objectives updated
- ✅ Document important architectural decisions

## 🔄 Advanced Memory Features

### Cross-Device Memory Sync

The memory system automatically syncs between your devices:

```bash
# === On laptop ===
claude-project-memory save "Mobile-first implementation" "Testing responsive"
# Auto-sync brings memory to desktop

# === On desktop (after automatic sync) ===
claude-project-memory resume
# Immediately sees: "Mobile-first implementation", "Testing responsive"
# Active files synced, TODOs updated
```

### Smart Context Preservation

The system intelligently preserves context across long breaks:

```bash
# === Week ago ===
claude-project-memory save "API endpoints working" "Need to add authentication"

# === Today ===
claude-project-memory resume
# Immediately recalls: where you left off, what's next, current TODOs
```

### Multi-Project Intelligence

Manage multiple projects without losing track:

```bash
# === Switch between projects seamlessly ===
cd ~/claude-workspace/projects/active/web-app
claude-project-memory resume  # Web app context

cd ~/claude-workspace/projects/active/data-analysis  
claude-project-memory resume  # Data analysis context

cd ~/claude-workspace/projects/sandbox/experiment
claude-project-memory resume  # Experiment context

# Each project maintains its own memory and context
```

## 🧪 Advanced Usage Examples

### Long-term Project Tracking

```bash
# === Month 1 ===
claude-project-memory save "Project started" "Setting up basic structure"
claude-project-memory todo add "Create user authentication"
claude-project-memory todo add "Design database schema"
claude-project-memory todo add "Build API endpoints"

# === Month 2 ===
claude-project-memory todo done 1  # Auth completed
claude-project-memory save "Authentication working" "Now implementing core features"

# === Month 3 ===
claude-project-memory resume
# System shows: progression from start, completed milestones, current focus
```

### Collaborative Session Memory

```bash
# === Before Claude AI session ===
claude-project-memory save "Preparing for AI pair programming" "Focus on optimization"

# === During AI session ===
# AI can see project context automatically
claude-project-memory todo add "Optimize database queries"
claude-project-memory todo add "Add caching layer"  
claude-project-memory save "AI session progress" "Identified performance bottlenecks"

# === After AI session ===
claude-project-memory save "AI session completed" "Performance improved 40%"
```

### Learning and Experimentation

```bash
# === In sandbox project ===
cd ~/claude-workspace/projects/sandbox/learning-rust
claude-project-memory save "Learning Rust basics" "Trying ownership concepts"
claude-project-memory todo add "Understand borrowing"
claude-project-memory todo add "Practice with structs"

# === Days later ===
claude-project-memory resume
# Immediately see: what you were learning, progress made, next steps
```

## 🛡️ Memory Security

### Sensitive Data Handling

```bash
# Exclude sensitive projects from sync
echo ".claude/memory/projects/*secret*.json" >> .rsync-exclude

# Check for accidentally saved sensitive data
grep -r "password\|secret\|token" .claude/memory/ 2>/dev/null

# Clean sensitive data if found
claude-memory-cleaner project sensitive-project --sanitize
```

### Privacy Protection

```bash
# Create encrypted backups of memory
tar -czf - .claude/memory/ | gpg -c > memory-backup-encrypted.tar.gz.gpg

# Verify no personal information in memory
claude-memory-cleaner stats | grep "privacy-check"
```

## 🚀 Performance Optimization

The memory system is designed to stay fast and lightweight:

- **Automatic compaction** prevents memory bloat
- **Intelligent caching** speeds up frequent operations  
- **Lazy loading** only loads what you need
- **Background cleanup** maintains performance

Perfect for hobby developers who want enterprise-level features with zero maintenance overhead!

The intelligent memory system ensures perfect continuity between sessions while maintaining optimal performance! 🚀