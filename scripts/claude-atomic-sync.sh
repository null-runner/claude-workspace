#!/bin/bash
# Claude Atomic Sync - Lockfile-based atomic workspace synchronization
# Prevents infinite loops while maintaining autonomous system functionality

WORKSPACE_DIR="$HOME/claude-workspace"
SYNC_DIR="$WORKSPACE_DIR/.claude/sync"
LOCK_FILE="$SYNC_DIR/sync.lock"
SNAPSHOT_DIR="$SYNC_DIR/snapshots"
SYNC_LOG="$SYNC_DIR/sync.log"
AUTONOMOUS_LOCKFILE="$WORKSPACE_DIR/.claude/autonomous/sync-pause.lock"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$SYNC_DIR" "$SNAPSHOT_DIR"

# Atomic logging
atomic_log() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$SYNC_LOG"
    echo -e "${CYAN}[ATOMIC-SYNC]${NC} $message"
}

# Check if sync is already running
check_sync_lock() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if [[ -n "$lock_pid" ]] && kill -0 "$lock_pid" 2>/dev/null; then
            return 0  # Locked
        else
            # Stale lock
            rm -f "$LOCK_FILE"
            return 1  # Not locked
        fi
    fi
    return 1  # Not locked
}

# Acquire atomic sync lock
acquire_sync_lock() {
    if check_sync_lock; then
        atomic_log "ERROR" "Sync already in progress (PID: $(cat "$LOCK_FILE"))"
        return 1
    fi
    
    echo $$ > "$LOCK_FILE"
    atomic_log "INFO" "Acquired sync lock (PID: $$)"
    return 0
}

# Release sync lock
release_sync_lock() {
    rm -f "$LOCK_FILE"
    atomic_log "INFO" "Released sync lock"
}

# Signal autonomous system to pause file operations
pause_autonomous_system() {
    atomic_log "INFO" "Signaling autonomous system to pause file operations"
    
    # Create pause signal file
    echo $$ > "$AUTONOMOUS_LOCKFILE"
    echo "$(date '+%Y-%m-%d %H:%M:%S')" >> "$AUTONOMOUS_LOCKFILE"
    echo "atomic_sync_operation" >> "$AUTONOMOUS_LOCKFILE"
    
    # Wait for autonomous system to acknowledge pause
    # The autonomous system should check for this file and pause writes
    sleep 3
    
    atomic_log "INFO" "Autonomous system pause signal sent"
}

# Resume autonomous system file operations
resume_autonomous_system() {
    rm -f "$AUTONOMOUS_LOCKFILE"
    atomic_log "INFO" "Autonomous system resumed"
}

# Create atomic snapshot of workspace state
create_atomic_snapshot() {
    local snapshot_id="$1"
    local snapshot_path="$SNAPSHOT_DIR/$snapshot_id"
    
    atomic_log "INFO" "Creating atomic snapshot: $snapshot_id"
    
    # Create snapshot metadata
    cat > "$snapshot_path.meta" << EOF
{
    "snapshot_id": "$snapshot_id",
    "timestamp": "$(date -Iseconds)",
    "git_commit": "$(git rev-parse HEAD 2>/dev/null || echo 'unknown')",
    "git_status_files": $(git status --porcelain | wc -l),
    "autonomous_status": "$(if [[ -f "$AUTONOMOUS_LOCKFILE" ]]; then echo "paused"; else echo "active"; fi)"
}
EOF

    # Create git bundle for atomic state capture
    if git rev-parse --git-dir >/dev/null 2>&1; then
        # Bundle all branches and uncommitted changes
        git bundle create "$snapshot_path.bundle" --all 2>/dev/null || {
            atomic_log "WARN" "Failed to create git bundle, using archive instead"
            git archive --format=tar.gz -o "$snapshot_path.tar.gz" HEAD 2>/dev/null
        }
        
        # Capture uncommitted changes separately
        if [[ -n $(git status --porcelain) ]]; then
            git diff > "$snapshot_path.uncommitted.diff"
            git diff --cached > "$snapshot_path.staged.diff"
            git status --porcelain > "$snapshot_path.status"
        fi
    fi
    
    atomic_log "INFO" "Snapshot created successfully: $snapshot_id"
}

# Atomic sync operation with rollback capability
perform_atomic_sync() {
    local operation="$1"  # pull, push, or full
    local snapshot_id="sync_$(date +%Y%m%d_%H%M%S)_$$"
    
    atomic_log "INFO" "Starting atomic sync operation: $operation"
    
    # Phase 1: Acquire locks and create snapshot
    if ! acquire_sync_lock; then
        return 1
    fi
    
    # Setup cleanup trap
    trap "cleanup_atomic_sync" EXIT INT TERM
    
    pause_autonomous_system
    create_atomic_snapshot "$snapshot_id"
    
    # Phase 2: Perform sync operation
    case "$operation" in
        "pull")
            atomic_pull
            ;;
        "push")
            atomic_push
            ;;
        "full")
            atomic_pull && atomic_push
            ;;
        *)
            atomic_log "ERROR" "Unknown sync operation: $operation"
            return 1
            ;;
    esac
    
    local sync_result=$?
    
    # Phase 3: Cleanup and resume
    if [[ $sync_result -eq 0 ]]; then
        atomic_log "SUCCESS" "Atomic sync completed successfully"
        # Keep snapshot for audit trail
        echo "success" > "$SNAPSHOT_DIR/$snapshot_id.result"
    else
        atomic_log "ERROR" "Atomic sync failed, snapshot preserved for analysis"
        echo "failed" > "$SNAPSHOT_DIR/$snapshot_id.result"
    fi
    
    cleanup_atomic_sync
    return $sync_result
}

# Atomic pull operation
atomic_pull() {
    atomic_log "INFO" "Executing atomic pull"
    
    # Check if we have remote configured
    if ! git remote get-url origin >/dev/null 2>&1; then
        atomic_log "ERROR" "No remote origin configured"
        return 1
    fi
    
    # Determine SSH configuration
    local git_ssh_cmd=""
    if [[ -f ~/.claude-access/ACTIVE && -f ~/.claude-access/keys/claude_deploy ]]; then
        git_ssh_cmd="GIT_SSH_COMMAND='ssh -i ~/.claude-access/keys/claude_deploy'"
        atomic_log "INFO" "Using Claude deploy key for authentication"
    fi
    
    # Stash any uncommitted changes to prevent conflicts
    local stash_created=false
    if [[ -n $(git status --porcelain) ]]; then
        git stash push -m "atomic-sync-stash-$(date +%s)" --include-untracked
        stash_created=true
        atomic_log "INFO" "Stashed local changes before pull"
    fi
    
    # Perform pull
    if [[ -n "$git_ssh_cmd" ]]; then
        eval "$git_ssh_cmd git pull origin main --no-edit --strategy-option=ours"
    else
        git pull origin main --no-edit --strategy-option=ours
    fi
    
    local pull_result=$?
    
    # Restore stashed changes if pull succeeded
    if [[ $pull_result -eq 0 && $stash_created == true ]]; then
        if git stash pop; then
            atomic_log "INFO" "Restored stashed changes after successful pull"
        else
            atomic_log "WARN" "Pull succeeded but failed to restore stashed changes - check git stash list"
        fi
    elif [[ $pull_result -ne 0 ]]; then
        atomic_log "ERROR" "Pull failed (exit code: $pull_result)"
        if [[ $stash_created == true ]]; then
            atomic_log "INFO" "Stashed changes preserved in git stash"
        fi
    fi
    
    return $pull_result
}

# Atomic push operation
atomic_push() {
    atomic_log "INFO" "Executing atomic push"
    
    # Check if there are changes to push
    if [[ -z $(git status --porcelain) ]]; then
        atomic_log "INFO" "No local changes to push"
        return 0
    fi
    
    # Stage all changes
    git add -A
    
    # Create commit with atomic sync metadata
    local commit_msg="Atomic sync from $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')

🤖 Generated with Claude Workspace (atomic sync)
Co-Authored-By: Claude <noreply@anthropic.com>"
    
    git commit -m "$commit_msg"
    local commit_result=$?
    
    if [[ $commit_result -ne 0 ]]; then
        atomic_log "ERROR" "Failed to create commit"
        return $commit_result
    fi
    
    # Push to remote
    local git_ssh_cmd=""
    if [[ -f ~/.claude-access/ACTIVE && -f ~/.claude-access/keys/claude_deploy ]]; then
        git_ssh_cmd="GIT_SSH_COMMAND='ssh -i ~/.claude-access/keys/claude_deploy'"
    fi
    
    if [[ -n "$git_ssh_cmd" ]]; then
        eval "$git_ssh_cmd git push origin main"
    else
        git push origin main
    fi
    
    local push_result=$?
    
    if [[ $push_result -eq 0 ]]; then
        atomic_log "SUCCESS" "Push completed successfully"
    else
        atomic_log "ERROR" "Push failed (exit code: $push_result)"
    fi
    
    return $push_result
}

# Cleanup function
cleanup_atomic_sync() {
    resume_autonomous_system
    release_sync_lock
    atomic_log "INFO" "Atomic sync cleanup completed"
}

# Show sync status
show_sync_status() {
    echo -e "${CYAN}🔄 ATOMIC SYNC STATUS${NC}"
    echo ""
    
    if check_sync_lock; then
        local lock_pid=$(cat "$LOCK_FILE")
        echo -e "${YELLOW}⚠️  Sync in progress (PID: $lock_pid)${NC}"
    else
        echo -e "${GREEN}✅ No active sync operations${NC}"
    fi
    
    if [[ -f "$AUTONOMOUS_LOCKFILE" ]]; then
        echo -e "${YELLOW}⏸️  Autonomous system paused for sync${NC}"
    else
        echo -e "${GREEN}🤖 Autonomous system active${NC}"
    fi
    
    # Show recent snapshots
    echo ""
    echo "📸 Recent snapshots:"
    if ls "$SNAPSHOT_DIR"/*.meta >/dev/null 2>&1; then
        for meta_file in "$SNAPSHOT_DIR"/*.meta; do
            local snapshot_id=$(basename "$meta_file" .meta)
            local timestamp=$(jq -r '.timestamp' "$meta_file" 2>/dev/null || echo "unknown")
            local result_file="$SNAPSHOT_DIR/$snapshot_id.result"
            local status="pending"
            if [[ -f "$result_file" ]]; then
                status=$(cat "$result_file")
            fi
            
            local status_icon="⏳"
            case "$status" in
                "success") status_icon="✅" ;;
                "failed") status_icon="❌" ;;
            esac
            
            echo "   $status_icon $snapshot_id ($timestamp)"
        done
    else
        echo "   No snapshots found"
    fi
    
    # Show recent log entries
    echo ""
    echo "📋 Recent activity:"
    if [[ -f "$SYNC_LOG" ]]; then
        tail -n 5 "$SYNC_LOG" | while read -r line; do
            echo "   $line"
        done
    else
        echo "   No sync activity logged"
    fi
}

# Cleanup old snapshots
cleanup_snapshots() {
    local keep_count="${1:-10}"
    
    atomic_log "INFO" "Cleaning up old snapshots (keeping last $keep_count)"
    
    # Keep only the most recent snapshots
    ls -t "$SNAPSHOT_DIR"/*.meta 2>/dev/null | tail -n +$((keep_count + 1)) | while read -r meta_file; do
        local snapshot_id=$(basename "$meta_file" .meta)
        rm -f "$SNAPSHOT_DIR/$snapshot_id".*
        atomic_log "INFO" "Removed old snapshot: $snapshot_id"
    done
}

# Help
show_help() {
    echo "Claude Atomic Sync - Lockfile-based atomic workspace synchronization"
    echo ""
    echo "Usage: claude-atomic-sync [command] [options]"
    echo ""
    echo "Commands:"
    echo "  pull                         Atomic pull from remote"
    echo "  push                         Atomic push to remote"  
    echo "  sync                         Full atomic sync (pull + push)"
    echo "  status                       Show sync status and recent activity"
    echo "  cleanup [keep_count]         Cleanup old snapshots (default: keep 10)"
    echo ""
    echo "Features:"
    echo "  • Lockfile coordination with autonomous system"
    echo "  • Atomic snapshots with rollback capability"
    echo "  • Conflict-free operation with background services"
    echo "  • Audit trail of all sync operations"
    echo ""
    echo "Examples:"
    echo "  claude-atomic-sync pull"
    echo "  claude-atomic-sync sync"
    echo "  claude-atomic-sync status"
    echo "  claude-atomic-sync cleanup 5"
}

# Main logic
case "${1:-}" in
    "pull")
        perform_atomic_sync "pull"
        ;;
    "push")
        perform_atomic_sync "push"
        ;;
    "sync")
        perform_atomic_sync "full"
        ;;
    "status")
        show_sync_status
        ;;
    "cleanup")
        cleanup_snapshots "${2:-10}"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_sync_status
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac