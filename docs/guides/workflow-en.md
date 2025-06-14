# Development Workflow - Claude Workspace

[🇺🇸 English](workflow-en.md) | [🇮🇹 Italiano](workflow-it.md)

This guide describes how to effectively use Claude Workspace for your development projects - perfect for vibecoders who want powerful tools without enterprise complexity.

## How to Create Projects

### 1. Basic Project Structure

Every project should follow this organization:

```
my-awesome-project/
├── README.md          # Project description
├── src/              # Source code
│   ├── main.py       # Entry point
│   └── modules/      # Project modules
├── tests/            # Unit and integration tests
├── docs/             # Detailed documentation
├── data/             # Sample data or datasets
├── scripts/          # Utility scripts
├── requirements.txt  # Python dependencies
└── .gitignore       # Files to exclude from git
```

### 2. Creating a New Project

**On laptop** (recommended workflow):
```bash
# Navigate to appropriate directory
cd ~/claude-workspace/projects/active  # For active development
# or
cd ~/claude-workspace/projects/sandbox  # For experiments

# Create the project
mkdir my-new-project
cd my-new-project

# Initialize project memory
claude-project-memory save "New project initialized"

# Initialize basic structure
mkdir -p src tests docs data scripts
touch README.md requirements.txt .gitignore

# Create initial README
cat > README.md << EOF
# My New Project

## Description
Brief project description.

## Setup
\`\`\`bash
pip install -r requirements.txt
\`\`\`

## Usage
\`\`\`bash
python src/main.py
\`\`\`

## Status
- [ ] Initial setup
- [ ] Core implementation
- [ ] Testing
- [ ] Documentation
EOF

# Set initial goals
claude-project-memory todo add "Initial setup"
claude-project-memory todo add "Core implementation"
claude-project-memory todo add "Testing"
claude-project-memory todo add "Documentation"

# Save state and sync (enterprise-grade)
claude-save "Created new project: my-new-project"
~/claude-workspace/scripts/sync-now.sh

# Optional: Use enhanced exit for session termination
# cexit-safe  # Graceful exit + keeps session open
```

### 3. Project Types and Where to Put Them

**active/** - Projects in active development
- Projects you're currently working on
- Need frequent synchronization
- Example: web app in development, automation scripts

**sandbox/** - Experimental projects
- Tests and proof of concepts
- Throwaway code
- Example: testing new libraries, experiments

**production/** - Completed/stable projects
- Production-ready code
- Infrequent changes
- Example: completed tools, deployed projects

## Development Workflows

### Workflow 1: Mobile-First Development (Laptop → Desktop)

Perfect when you start working away from home and want to continue on your desktop PC.

```bash
# 1. On laptop - start development
cd ~/claude-workspace/projects/active/my-project

# Resume context if existing
claude-project-memory resume

# ... code development ...
# Auto-save automatically during file modifications

# 2. Local commit (optional but recommended)
git add .
git commit -m "WIP: feature implementation"

# 3. Save state and sync with desktop (enterprise-grade)
claude-project-memory save "Implemented feature X, next: testing"
claude-save "Continue my-project development on desktop"
~/claude-workspace/scripts/sync-now.sh

# Enhanced exit options
# Use cexit-safe for proper session termination
# cexit-safe  # Graceful exit + keeps session open

# 4. On desktop - continue development
# Resume general context
claude-resume

cd ~/claude-workspace/projects/active/my-project

# Resume project-specific context
claude-project-memory resume

# ... continue development with full continuity ...

# 5. Sync again if returning to laptop
# From laptop:
~/claude-workspace/scripts/sync-now.sh
```

### Workflow 2: Desktop-First Development (Desktop → Laptop)

When main work is on desktop but you want to take code with you.

```bash
# 1. On desktop - main development
cd ~/claude-workspace/projects/active/big-project

# Resume previous work
claude-project-memory resume

# ... intensive development ...
# Save important progress
claude-project-memory save "Completed authentication module"

# 2. From laptop - sync before leaving
~/claude-workspace/scripts/sync-now.sh

# 3. On laptop - work offline
cd ~/claude-workspace/projects/active/big-project

# Resume synced context
claude-project-memory resume

# ... modifications and fixes ...
# Save even offline
claude-project-memory save "Fixed form validation bug"

# 4. When back online - sync
~/claude-workspace/scripts/sync-now.sh
```

### Workflow 3: Collaborative Development with Claude

Optimized for pair programming sessions with Claude AI.

```bash
# 1. Prepare project for Claude
cd ~/claude-workspace/projects/active/ai-assisted-project

# Initialize memory for AI session
claude-project-memory save "Starting Claude AI session"

# 2. Create context file for Claude
cat > .claude-context.md << EOF
## Project Context
- Language: Python 3.9
- Framework: FastAPI
- Database: PostgreSQL
- Current task: Implement user authentication

## Project Structure
\`\`\`
$(tree -L 2)
\`\`\`

## Recent Changes
$(git log --oneline -10)
EOF

# 3. Develop with Claude
# ... coding session ...

# During session, track progress
claude-project-memory todo add "Implement /login endpoint"
claude-project-memory todo add "Add JWT validation"

# Complete tasks as you go
claude-project-memory todo done 1

# 4. Save session and sync
claude-project-memory save "Claude session completed: implemented auth system"
claude-save "Next session: implement dashboard"
~/claude-workspace/scripts/sync-now.sh

# 5. On desktop - code review
# Resume context
claude-resume

cd ~/claude-workspace/projects/active/ai-assisted-project

# See project state
claude-project-memory resume

# Review code
git diff
```

## Practical Examples

### Example 1: Python Web Scraper

```bash
# Create project
cd ~/claude-workspace/projects/active
mkdir web-scraper
cd web-scraper

# Setup structure
mkdir -p src/{scrapers,utils} tests data/raw data/processed

# Main file
cat > src/main.py << 'EOF'
#!/usr/bin/env python3
"""
Web Scraper - Main entry point
"""
import argparse
from scrapers.base import BaseScraper

def main():
    parser = argparse.ArgumentParser(description='Web Scraper')
    parser.add_argument('url', help='URL to scrape')
    parser.add_argument('--output', '-o', default='data/raw/output.json')
    args = parser.parse_args()
    
    scraper = BaseScraper()
    data = scraper.scrape(args.url)
    scraper.save(data, args.output)

if __name__ == '__main__':
    main()
EOF

# Requirements
cat > requirements.txt << EOF
requests>=2.28.0
beautifulsoup4>=4.11.0
pandas>=1.5.0
pytest>=7.2.0
EOF

# Gitignore
cat > .gitignore << EOF
__pycache__/
*.pyc
.pytest_cache/
data/raw/*
data/processed/*
!data/raw/.gitkeep
!data/processed/.gitkeep
.env
*.log
EOF

# Create .gitkeep to maintain empty directories
touch data/raw/.gitkeep data/processed/.gitkeep

# Sync
~/claude-workspace/scripts/sync-now.sh
```

### Example 2: REST API with Node.js

```bash
# Create project
cd ~/claude-workspace/projects/active
mkdir rest-api
cd rest-api

# Initialize npm
npm init -y

# Install dependencies
npm install express cors dotenv
npm install -D nodemon jest supertest

# Structure
mkdir -p src/{routes,controllers,models,middleware} tests

# Main server
cat > src/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date() });
});

// Start server
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

module.exports = app;
EOF

# Package.json scripts
npm pkg set scripts.start="node src/server.js"
npm pkg set scripts.dev="nodemon src/server.js"
npm pkg set scripts.test="jest"

# Environment file
cat > .env.example << EOF
PORT=3000
NODE_ENV=development
DATABASE_URL=postgresql://user:pass@localhost/dbname
EOF

cp .env.example .env

# Sync
~/claude-workspace/scripts/sync-now.sh
```

### Example 3: Data Analysis with Jupyter

```bash
# Create project
cd ~/claude-workspace/projects/active
mkdir data-analysis
cd data-analysis

# Setup Python environment
python -m venv venv
source venv/bin/activate

# Install dependencies
pip install jupyter pandas numpy matplotlib seaborn scikit-learn

# Save requirements
pip freeze > requirements.txt

# Structure
mkdir -p notebooks data/{raw,processed,figures} src

# Initial notebook
cat > notebooks/01_exploratory_analysis.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Exploratory Data Analysis\n",
    "## Project: Data Analysis\n",
    "### Date: $(date +%Y-%m-%d)"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import pandas as pd\n",
    "import numpy as np\n",
    "import matplotlib.pyplot as plt\n",
    "import seaborn as sns\n",
    "\n",
    "# Configuration\n",
    "sns.set_style('whitegrid')\n",
    "plt.rcParams['figure.figsize'] = (10, 6)"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF

# Utility script
cat > src/data_loader.py << 'EOF'
"""
Data loading utilities
"""
import pandas as pd
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / 'data'

def load_raw_data(filename):
    """Load data from raw directory"""
    filepath = DATA_DIR / 'raw' / filename
    return pd.read_csv(filepath)

def save_processed_data(df, filename):
    """Save processed data"""
    filepath = DATA_DIR / 'processed' / filename
    df.to_csv(filepath, index=False)
    print(f"Data saved to {filepath}")
EOF

# Sync
~/claude-workspace/scripts/sync-now.sh
```

## Workflow Best Practices

### 1. Synchronization

**When to sync**:
- Before switching devices
- After significant changes
- Before Claude AI sessions
- End of work day

**Verify sync**:
```bash
# Check last sync
tail -10 ~/claude-workspace/logs/sync.log

# Dry run to see what will be synced
rsync -avzn ~/claude-workspace/projects/ nullrunner@192.168.1.106:~/claude-workspace/projects/
```

### 2. Project Organization

**Naming conventions**:
```
# Good
web-scraper-python
api-rest-nodejs
ml-classification-project

# Avoid
project1
test
new-project-final-v2-FINAL
```

**Minimal documentation**:
- README.md with setup and usage
- requirements.txt or package.json
- Appropriate .gitignore
- Code comments

### 3. Version Control

**Recommended git workflow**:
```bash
# Initialize git in every project
git init
git add .
git commit -m "Initial commit"

# Feature branches
git checkout -b feature/user-auth

# Frequent commits
git add -p  # For interactive review
git commit -m "Add user authentication endpoint"

# Before syncing
git status  # Verify state
```

### 4. Dependency Management

**Python**:
```bash
# Always use virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# or
venv\Scripts\activate  # Windows

# Exact version freeze
pip freeze > requirements.txt
```

**Node.js**:
```bash
# Always commit lock file
npm ci  # Instead of npm install for reproducible builds

# Separate dev dependencies
npm install --save express
npm install --save-dev jest
```

### 5. Testing

**Recommended test structure**:
```
tests/
├── unit/           # Unit tests
├── integration/    # Integration tests
├── fixtures/       # Test data
└── conftest.py    # Pytest config (Python)
```

**Run tests before sync**:
```bash
# Python
pytest

# Node.js
npm test

# Sync only if tests pass
if npm test; then
    ~/claude-workspace/scripts/sync-now.sh
else
    echo "Fix tests before syncing!"
fi
```

## Intelligent Memory System Integration

### Complete Workflow with Memory

The combination of synchronization and intelligent memory provides perfect continuity between devices and sessions.

#### Scenario 1: Long-Running Project

```bash
# === DAY 1 - On laptop ===
cd ~/claude-workspace/projects/active/ecommerce-app

# Initialize project with memory
claude-project-memory save "New e-commerce project" "Setting up architecture"
claude-project-memory todo add "Create database models"
claude-project-memory todo add "Implement product API"
claude-project-memory todo add "Create React frontend"

# Work on database
# ... implementation ...
claude-project-memory todo done 1
claude-project-memory save "Database models completed" "Next: product API"

# End of day
claude-save "Tomorrow: continue product API"
~/claude-workspace/scripts/sync-now.sh

# === DAY 2 - On desktop ===
# Resume all context
claude-resume
# Output: "Tomorrow: continue product API"

cd ~/claude-workspace/projects/active/ecommerce-app
claude-project-memory resume
# Output: ecommerce-app project, last task: "Next: product API", remaining TODOs...

# Continue work without losing anything
# ... API implementation ...
claude-project-memory todo done 2
claude-project-memory save "Product API completed" "Start frontend"

# === WEEK LATER - On laptop ===
cd ~/claude-workspace/projects/active/ecommerce-app
claude-project-memory resume
# Immediately sees project state, even after weeks!
```

#### Scenario 2: Multiple Active Projects

```bash
# Manage multiple projects with separate memory

# === Web App Project ===
cd ~/claude-workspace/projects/active/web-app
claude-project-memory save "Authentication bug fix" "Testing login flow"

# === Switch to Data Analysis ===
cd ~/claude-workspace/projects/active/data-analysis
claude-project-memory save "Dataset cleaned" "Start feature engineering"

# === Switch to API Project ===
cd ~/claude-workspace/projects/sandbox/new-api
claude-project-memory save "GraphQL proof of concept" "Decide whether to proceed"

# === Resume Web App after days ===
cd ~/claude-workspace/projects/active/web-app
claude-project-memory resume
# Immediately sees: "Authentication bug fix", "Testing login flow"
```

## 🚀 Enterprise-Grade Exit System

### Modern Exit Management

Claude Workspace now provides enterprise-level exit management with intelligent analysis and graceful termination:

**Exit Commands Available**:
```bash
# cexit - Complete workspace termination
cexit                    # Graceful exit + terminates Claude Code

# cexit-safe - Development-friendly (RECOMMENDED)
./scripts/cexit-safe     # Graceful exit + keeps session open

# exit - Traditional shell exit
exit                     # Normal exit (no workspace sync)
```

**Enterprise Exit Features**:
- **Activity Analysis**: Intelligent detection of work completion vs interruption
- **Memory Coordination**: Unified context save across all active projects  
- **File Integrity**: Atomic operations prevent data corruption
- **State Preservation**: Enhanced backup with automatic recovery markers
- **Performance Optimization**: Cache cleanup and memory optimization
- **Cross-Device Sync**: Automatic state synchronization with conflict detection

**Recommended Exit Workflow**:
```bash
# === Modern Development Session End ===
claude-project-memory save "Feature complete, ready for testing"
claude-save "Tomorrow: code review and deployment"

# Enterprise graceful exit (handles all cleanup automatically)
cexit-safe

# Result: Enterprise-grade reliability with zero data loss
```

**Exit vs Legacy Hook System**:
- ❌ **Old**: Automatic exit hooks (removed for reliability)
- ✅ **New**: Explicit exit commands with enterprise features
- ✅ **Benefits**: User control, better reliability, enhanced analytics

## Useful Automations

### Pre-sync Hook

Create `~/claude-workspace/scripts/pre-sync-hook.sh`:
```bash
#!/bin/bash
# Executed automatically before each sync

echo "Running pre-sync checks..."

# Look for temporary files
find ~/claude-workspace/projects -name "*.tmp" -o -name "*.swp" | while read f; do
    echo "Warning: Temporary file found: $f"
done

# Check disk space
USED=$(df ~/claude-workspace | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USED -gt 80 ]; then
    echo "Warning: Disk usage is ${USED}%"
fi

# Check large files
find ~/claude-workspace/projects -size +100M -type f | while read f; do
    echo "Warning: Large file: $f ($(du -h "$f" | cut -f1))"
done
```

### Post-sync Notification

For desktop notifications after sync:
```bash
# Add to sync-now.sh
if command -v notify-send &> /dev/null; then
    notify-send "Claude Workspace" "Sync completed successfully"
fi
```

### Project Template Generator

Script to create new projects: `~/claude-workspace/scripts/new-project.sh`:
```bash
#!/bin/bash
# Usage: new-project.sh <name> <type>

NAME=$1
TYPE=$2

if [ -z "$NAME" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <project-name> <python|node|data>"
    exit 1
fi

BASE_DIR="$HOME/claude-workspace/projects/active/$NAME"

case $TYPE in
    python)
        mkdir -p "$BASE_DIR"/{src,tests,docs}
        # ... setup Python project
        ;;
    node)
        mkdir -p "$BASE_DIR"/{src,tests}
        cd "$BASE_DIR" && npm init -y
        ;;
    data)
        mkdir -p "$BASE_DIR"/{notebooks,data/{raw,processed},src}
        # ... setup data project
        ;;
    *)
        echo "Unknown project type: $TYPE"
        exit 1
        ;;
esac

echo "Project $NAME created at $BASE_DIR"
```

## Common Troubleshooting

### Sync Conflicts

**Problem**: Files modified on both devices

**Solution**:
```bash
# Local backup
cp ~/claude-workspace/projects/active/my-project/conflicted-file.py ~/backup/

# Force sync from one direction
rsync -avz --delete nullrunner@192.168.1.106:~/claude-workspace/projects/ ~/claude-workspace/projects/

# Or manually resolve
vimdiff local-file.py remote-file.py
```

### Broken Projects After Sync

**Problem**: Dependencies or environment not synced

**Solution**:
```bash
# Python - recreate environment
cd project-dir
rm -rf venv
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Node.js - reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

### Slow Performance with Large Projects

**Solution 1**: Exclude unnecessary files

```bash
# In .rsync-exclude
node_modules/
venv/
*.pyc
__pycache__/
.git/objects/
*.log
coverage/
dist/
build/
```

**Solution 2**: Incremental sync of certain files only
```bash
# Sync only source code
rsync -avz --include="*.py" --include="*.js" --include="*/" --exclude="*" \
    ~/claude-workspace/projects/big-project/ \
    nullrunner@192.168.1.106:~/claude-workspace/projects/big-project/
```

## 🧠 Enterprise Memory Coordinator + Workflow Integration

### Unified Memory Coordination System

Claude Workspace now features an enterprise-grade unified memory coordinator that manages all memory types with advanced reliability and performance:

#### Enterprise-Grade Auto-save

The unified memory coordinator provides enterprise-level automation:

```bash
# Enable unified memory coordinator (manages all memory types)
~/claude-workspace/scripts/claude-memory-coordinator.sh start

# Enterprise auto-save features:
# 1. Unified memory coordination (global + project + session memory)
# 2. Atomic file operations with file locking (no corruption risk)
# 3. Intelligent conflict resolution across devices
# 4. Performance-optimized caching system
# 5. Automatic backup rotation with retention policies
# 6. Cross-device state synchronization with integrity checks
# 7. Enterprise-grade error recovery and rollback
# 8. Process protection and deadlock prevention

# Monitor coordinator status
~/claude-workspace/scripts/claude-memory-coordinator.sh status

# View coordination logs
tail -f .claude/memory-coordination/coordinator.log
```

**Memory Coordinator Benefits**:
- **Unified Management**: Single system handles all memory types
- **Enterprise Reliability**: Atomic operations, file locking, process protection
- **Performance Optimization**: Intelligent caching, batch operations
- **Automatic Recovery**: Enterprise-grade error handling and rollback
- **Conflict Resolution**: Smart handling of cross-device conflicts

#### Enterprise Multi-Device Memory Management

The unified coordinator ensures seamless cross-device continuity with enterprise-grade reliability:

```bash
# === On laptop ===
claude-project-memory save "Mobile-first implementation" "Testing responsive"
# Unified coordinator automatically handles:
# - Atomic memory updates with file locking
# - Cross-device sync with conflict detection  
# - Performance-optimized state caching
# - Automatic backup with retention policies
# - Enterprise-grade integrity validation

# === On desktop (after enterprise sync) ===
claude-project-memory resume
# Enterprise features active:
# - Instant context restoration (performance-cached)
# - Automatic conflict resolution with rollback capability
# - Enterprise-grade data integrity verification
# - Optimized loading with intelligent prefetching
# - Automatic state validation and error recovery

# Check coordination status across devices
~/claude-workspace/scripts/claude-memory-coordinator.sh health
```

**Enterprise Coordination Features**:
- **Atomic Operations**: File locking prevents corruption during updates
- **Conflict Detection**: Intelligent resolution of simultaneous device updates  
- **Performance Caching**: Optimized loading and state management
- **Backup Automation**: Automatic rotation with configurable retention
- **Error Recovery**: Enterprise-grade rollback and state restoration

### Memory + Workflow Best Practices

#### 1. Strategic Notes

```bash
# Status notes for continuity
claude-project-memory save "API works but slow" "Optimize DB queries"

# Technical notes for complex setup
claude-project-memory save "Docker setup: port 3000->8080" "Configure ENV variables"

# Decision notes for review
claude-project-memory save "Chose PostgreSQL vs MongoDB" "Better performance for relations"
```

#### 2. TODO Management

```bash
# Granular TODOs for precise tracking
claude-project-memory todo add "Fix email validation regex"
claude-project-memory todo add "Add test cases edge cases"
claude-project-memory todo add "Document API endpoint /users"

# Categorized TODOs
claude-project-memory todo add "BUG: Login doesn't work on Safari"
claude-project-memory todo add "FEATURE: Implement dark mode"
claude-project-memory todo add "PERFORMANCE: Optimize dashboard queries"
```

## 🏢 Enterprise-Grade Features

### Performance Optimization

Claude Workspace now includes enterprise-level performance enhancements:

**Caching System**:
```bash
# Intelligent caching for faster operations
~/claude-workspace/scripts/claude-memory-coordinator.sh optimize

# Cache statistics
~/claude-workspace/scripts/claude-memory-coordinator.sh cache-stats

# Manual cache refresh (if needed)
~/claude-workspace/scripts/claude-memory-coordinator.sh cache-refresh
```

**Batch Operations**:
- Memory updates processed in optimized batches
- Reduced I/O overhead for better performance
- Intelligent grouping of related operations

### Automated Backup Management

**Enterprise Backup Features**:
```bash
# Automatic backup with retention policies
~/claude-workspace/scripts/claude-backup-cleaner.sh status

# Configure backup retention (default: 30 days)
~/claude-workspace/scripts/claude-backup-cleaner.sh set-retention 60

# Manual cleanup of old backups
~/claude-workspace/scripts/claude-backup-cleaner.sh clean

# View backup statistics
~/claude-workspace/scripts/claude-backup-cleaner.sh stats
```

**Backup Policies**:
- Automatic cleanup of backups older than configured retention period
- Intelligent backup prioritization (keeps important milestones longer)
- Space-efficient backup compression and deduplication

### Error Recovery System

**Enterprise-Grade Recovery**:
```bash
# Check system integrity
~/claude-workspace/scripts/claude-memory-coordinator.sh integrity-check

# Automatic recovery from corruption
~/claude-workspace/scripts/claude-memory-coordinator.sh auto-recover

# Manual recovery with rollback options
~/claude-workspace/scripts/claude-memory-coordinator.sh manual-recover
```

**Recovery Features**:
- Automatic detection and recovery from file corruption
- Enterprise-grade rollback capabilities with state validation
- Comprehensive error logging and diagnostics
- Preventive integrity monitoring

The combination of enterprise-grade memory coordination, intelligent synchronization, and automated management provides a robust, high-performance development experience across devices and sessions, with enterprise-level reliability and zero data loss! 🚀