#!/bin/bash
# Claude Workspace - Migration to Robust Sync System
# Safely transitions from problematic auto-sync to secure robust sync

WORKSPACE_DIR="$HOME/claude-workspace"
BACKUP_DIR="$WORKSPACE_DIR/backups/sync-migration-$(date +%Y%m%d-%H%M%S)"
MIGRATION_LOG="$WORKSPACE_DIR/logs/sync-migration.log"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Setup
mkdir -p "$BACKUP_DIR" "$(dirname "$MIGRATION_LOG")"

log_migration() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$MIGRATION_LOG"
    
    case "$level" in
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

# Pre-migration safety checks
safety_checks() {
    log_migration "INFO" "Performing pre-migration safety checks..."
    
    # Check if we're in the right directory
    if [[ ! -f "$WORKSPACE_DIR/CLAUDE.md" ]]; then
        log_migration "ERROR" "Not in Claude workspace directory"
        return 1
    fi
    
    # Check git repository health
    cd "$WORKSPACE_DIR"
    if ! git fsck --no-progress --quiet; then
        log_migration "ERROR" "Git repository has integrity issues"
        return 1
    fi
    
    # Check for uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        log_migration "WARN" "Uncommitted changes detected - will be backed up"
    fi
    
    # Check disk space (need at least 500MB for backup)
    local available=$(df "$WORKSPACE_DIR" | awk 'NR==2 {print $4}')
    if [[ $available -lt 512000 ]]; then
        log_migration "ERROR" "Insufficient disk space for migration backup"
        return 1
    fi
    
    log_migration "SUCCESS" "Pre-migration safety checks passed"
    return 0
}

# Create complete backup
create_backup() {
    log_migration "INFO" "Creating pre-migration backup..."
    
    # Backup current state
    cd "$WORKSPACE_DIR"
    
    # Git repository backup
    git bundle create "$BACKUP_DIR/repository.bundle" --all
    if [[ $? -eq 0 ]]; then
        log_migration "SUCCESS" "Git repository backed up to $BACKUP_DIR/repository.bundle"
    else
        log_migration "ERROR" "Failed to create git backup"
        return 1
    fi
    
    # Backup autonomous system state
    if [[ -d ".claude" ]]; then
        cp -r .claude "$BACKUP_DIR/claude-system-backup"
        log_migration "SUCCESS" "Autonomous system state backed up"
    fi
    
    # Backup current sync scripts
    if [[ -f "scripts/auto-sync.sh" ]]; then
        cp scripts/auto-sync.sh "$BACKUP_DIR/old-auto-sync.sh"
        log_migration "SUCCESS" "Old auto-sync script backed up"
    fi
    
    # Create backup manifest
    cat > "$BACKUP_DIR/BACKUP_MANIFEST.md" << EOF
# Claude Workspace Migration Backup
Created: $(date)
Migration: Auto-sync to Robust-sync

## Contents
- repository.bundle: Complete git repository backup
- claude-system-backup/: Autonomous system state
- old-auto-sync.sh: Original auto-sync script

## Recovery Instructions
To restore from this backup:
1. git clone repository.bundle workspace-restored
2. Copy claude-system-backup to .claude/
3. Restart autonomous system

Backup size: $(du -sh "$BACKUP_DIR" | cut -f1)
EOF

    log_migration "SUCCESS" "Backup manifest created"
    return 0
}

# Stop current auto-sync processes
stop_old_sync() {
    log_migration "INFO" "Stopping old auto-sync processes..."
    
    # Find and stop auto-sync processes
    local sync_pids=$(pgrep -f "auto-sync.sh\|inotifywait.*projects")
    
    if [[ -n "$sync_pids" ]]; then
        log_migration "INFO" "Found auto-sync processes: $sync_pids"
        echo "$sync_pids" | xargs kill -TERM 2>/dev/null
        sleep 5
        
        # Force kill if still running  
        local remaining_pids=$(pgrep -f "auto-sync.sh\|inotifywait.*projects")
        if [[ -n "$remaining_pids" ]]; then
            log_migration "WARN" "Force killing remaining processes: $remaining_pids"
            echo "$remaining_pids" | xargs kill -KILL 2>/dev/null
        fi
        
        log_migration "SUCCESS" "Old auto-sync processes stopped"
    else
        log_migration "INFO" "No running auto-sync processes found"
    fi
}

# Clean up problematic commits (optional)
cleanup_auto_commits() {
    log_migration "INFO" "Analyzing auto-sync commit pollution..."
    
    local auto_commits=$(git log --since="7 days ago" --grep="Auto-sync" --oneline | wc -l)
    
    if [[ $auto_commits -gt 50 ]]; then
        log_migration "WARN" "Found $auto_commits auto-sync commits in the last 7 days"
        
        echo -n "Do you want to squash recent auto-sync commits? (y/N): "
        read -r response
        
        if [[ "$response" =~ ^[Yy]$ ]]; then
            log_migration "INFO" "Squashing auto-sync commits (this may take a while)..."
            
            # Create a cleanup branch
            git checkout -b cleanup-auto-commits
            
            # Interactive rebase to squash auto-sync commits
            # Note: This is advanced and might need manual intervention
            log_migration "WARN" "Advanced git cleanup required - manual intervention may be needed"
            log_migration "INFO" "Created cleanup-auto-commits branch for manual cleanup"
            
            git checkout main
        fi
    else
        log_migration "SUCCESS" "Auto-commit pollution is manageable ($auto_commits commits)"
    fi
}

# Apply gitignore protection
apply_gitignore() {
    log_migration "INFO" "Applying gitignore protection for autonomous system..."
    
    # Remove currently tracked autonomous files from git
    local autonomous_files=(
        ".claude/autonomous/service-status.json"
        ".claude/autonomous/*.log"
        ".claude/memory/current-session-context.json" 
        ".claude/memory/enhanced-context.json"
        ".claude/activity/activity.json"
        ".claude/activity/activity.log"
    )
    
    for file_pattern in "${autonomous_files[@]}"; do
        # Use git rm --cached to untrack but keep files
        git rm --cached "$file_pattern" 2>/dev/null || true
    done
    
    # Add gitignore if not already added
    if [[ -f ".gitignore" ]]; then
        git add .gitignore
        log_migration "SUCCESS" "Gitignore protection applied"
    else
        log_migration "ERROR" "Gitignore file not found - security protection incomplete"
        return 1
    fi
    
    return 0
}

# Install robust sync system
install_robust_sync() {
    log_migration "INFO" "Installing robust sync system..."
    
    # Make robust sync executable
    chmod +x scripts/claude-robust-sync.sh
    
    # Test the robust sync system
    if scripts/claude-robust-sync.sh test; then
        log_migration "SUCCESS" "Robust sync system test passed"
    else
        log_migration "ERROR" "Robust sync system test failed"
        return 1
    fi
    
    # Create systemd service file (optional)
    if command -v systemctl >/dev/null; then
        cat > "$HOME/.config/systemd/user/claude-robust-sync.service" << EOF
[Unit]
Description=Claude Workspace Robust Sync
After=network.target

[Service]
Type=simple
ExecStart=$WORKSPACE_DIR/scripts/claude-robust-sync.sh monitor
Restart=always
RestartSec=30
Environment=HOME=$HOME

[Install]
WantedBy=default.target
EOF

        # Enable but don't start yet
        systemctl --user daemon-reload
        systemctl --user enable claude-robust-sync.service
        log_migration "SUCCESS" "Systemd service installed (not started yet)"
    fi
    
    return 0
}

# Commit migration changes
commit_migration() {
    log_migration "INFO" "Committing migration changes..."
    
    cd "$WORKSPACE_DIR"
    
    # Add migration files
    git add scripts/claude-robust-sync.sh
    git add scripts/claude-migrate-to-robust-sync.sh
    git add .gitignore
    
    # Commit migration
    git commit -m "🔒 SECURITY: Migrate to robust sync system

- Replace problematic auto-sync with security-focused robust sync
- Add gitignore protection for autonomous system files  
- Implement rate limiting and health checks
- Add backup and recovery capabilities
- Prevent infinite sync loops and repository pollution

Migration backup: $BACKUP_DIR
Security improvements: Rate limiting, health checks, tiered sync
Risk mitigation: Lock files, cooldown periods, failure recovery"
    
    if [[ $? -eq 0 ]]; then
        log_migration "SUCCESS" "Migration committed to git"
        return 0
    else
        log_migration "ERROR" "Failed to commit migration"
        return 1
    fi
}

# Main migration process
main() {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}Claude Workspace Robust Sync Migration${NC}"
    echo -e "${BLUE}=====================================${NC}"
    echo
    
    log_migration "INFO" "Starting migration to robust sync system"
    
    # Safety checks
    if ! safety_checks; then
        log_migration "ERROR" "Migration aborted due to safety check failures"
        exit 1
    fi
    
    # Create backup
    if ! create_backup; then
        log_migration "ERROR" "Migration aborted - backup failed"
        exit 1
    fi
    
    # Stop old processes
    stop_old_sync
    
    # Optional commit cleanup
    cleanup_auto_commits
    
    # Apply security protections
    if ! apply_gitignore; then
        log_migration "ERROR" "Failed to apply gitignore protection"
        exit 1
    fi
    
    # Install new system
    if ! install_robust_sync; then
        log_migration "ERROR" "Failed to install robust sync system"
        exit 1
    fi
    
    # Commit changes
    if ! commit_migration; then
        log_migration "ERROR" "Failed to commit migration changes"
        exit 1  
    fi
    
    echo
    echo -e "${GREEN}=====================================${NC}"
    echo -e "${GREEN}Migration Completed Successfully!${NC}"
    echo -e "${GREEN}=====================================${NC}"
    echo
    echo -e "${BLUE}Next Steps:${NC}"
    echo "1. Test the new system: ./scripts/claude-robust-sync.sh test"
    echo "2. Start monitoring: ./scripts/claude-robust-sync.sh monitor &"
    echo "3. Check status: ./scripts/claude-robust-sync.sh status"
    echo
    echo -e "${BLUE}Backup Location:${NC} $BACKUP_DIR"
    echo -e "${BLUE}Migration Log:${NC} $MIGRATION_LOG"
    echo
    echo -e "${YELLOW}Important:${NC} Review the backup and test the new system before relying on it"
    
    log_migration "SUCCESS" "Migration completed successfully"
}

# Run migration
main "$@"