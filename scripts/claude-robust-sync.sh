#!/bin/bash
# Claude Workspace - Robust Multi-Tier Auto-Sync System
# Security-focused implementation with failure resilience

WORKSPACE_DIR="$HOME/claude-workspace"
SYNC_STATE_DIR="$WORKSPACE_DIR/.claude/sync"
LOG_FILE="$WORKSPACE_DIR/logs/robust-sync.log"
LOCK_FILE="$SYNC_STATE_DIR/sync.lock"

# Security and robustness configuration
MAX_COMMITS_PER_HOUR=10
MAX_AUTO_COMMITS_PER_DAY=50
SYNC_COOLDOWN_SECONDS=300  # 5 minutes between syncs
HEALTH_CHECK_INTERVAL=60   # 1 minute
MAX_RETRY_ATTEMPTS=3
BATCH_SYNC_INTERVAL=3600   # 1 hour for workspace files

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Setup
mkdir -p "$SYNC_STATE_DIR" "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Secure logging with rotation
log_secure() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Log rotation (keep last 1000 lines)
    if [[ $(wc -l < "$LOG_FILE") -gt 1000 ]]; then
        tail -n 500 "$LOG_FILE" > "$LOG_FILE.tmp"
        mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    
    # Critical errors to stderr
    if [[ "$level" == "ERROR" || "$level" == "CRITICAL" ]]; then
        echo -e "${RED}[SYNC-ERROR]${NC} $message" >&2
    fi
}

# Acquire exclusive lock with timeout
acquire_lock() {
    local timeout=${1:-30}
    local count=0
    
    while [[ -f "$LOCK_FILE" ]] && [[ $count -lt $timeout ]]; do
        if ! kill -0 "$(cat "$LOCK_FILE" 2>/dev/null)" 2>/dev/null; then
            log_secure "INFO" "Removing stale lock file"
            rm -f "$LOCK_FILE"
            break
        fi
        sleep 1
        ((count++))
    done
    
    if [[ -f "$LOCK_FILE" ]]; then
        log_secure "ERROR" "Could not acquire sync lock after ${timeout}s"
        return 1
    fi
    
    echo $$ > "$LOCK_FILE"
    return 0
}

# Release lock
release_lock() {
    if [[ -f "$LOCK_FILE" ]] && [[ "$(cat "$LOCK_FILE")" == "$$" ]]; then
        rm -f "$LOCK_FILE"
    fi
}

# Trap to ensure lock cleanup
trap 'release_lock; exit' EXIT INT TERM

# Rate limiting check
check_rate_limits() {
    local commits_last_hour=$(git log --since="1 hour ago" --grep="Auto-sync" --oneline 2>/dev/null | wc -l)
    local commits_today=$(git log --since="24 hours ago" --grep="Auto-sync" --oneline 2>/dev/null | wc -l)
    
    if [[ $commits_last_hour -ge $MAX_COMMITS_PER_HOUR ]]; then
        log_secure "WARN" "Rate limit exceeded: $commits_last_hour commits in last hour"
        return 1
    fi
    
    if [[ $commits_today -ge $MAX_AUTO_COMMITS_PER_DAY ]]; then
        log_secure "CRITICAL" "Daily rate limit exceeded: $commits_today auto-sync commits today"
        return 1
    fi
    
    return 0
}

# Check last sync time for cooldown
check_sync_cooldown() {
    local last_sync_file="$SYNC_STATE_DIR/last_sync"
    
    if [[ -f "$last_sync_file" ]]; then
        local last_sync=$(cat "$last_sync_file")
        local now=$(date +%s)
        local diff=$((now - last_sync))
        
        if [[ $diff -lt $SYNC_COOLDOWN_SECONDS ]]; then
            local remaining=$((SYNC_COOLDOWN_SECONDS - diff))
            log_secure "INFO" "Sync cooldown active, ${remaining}s remaining"
            return 1
        fi
    fi
    
    return 0
}

# Health check before sync
pre_sync_health_check() {
    # Check git repository health
    if ! git fsck --no-progress --quiet 2>/dev/null; then
        log_secure "CRITICAL" "Git repository corruption detected"
        return 1
    fi
    
    # Check disk space (require at least 100MB free)
    local available=$(df "$WORKSPACE_DIR" | awk 'NR==2 {print $4}')
    if [[ $available -lt 102400 ]]; then  # 100MB in KB
        log_secure "CRITICAL" "Insufficient disk space: ${available}KB available"
        return 1
    fi
    
    # Check if autonomous system is stable
    if [[ -f "$WORKSPACE_DIR/.claude/autonomous/service-status.json" ]]; then
        local services_healthy=$(python3 -c "
import json, sys
try:
    with open('$WORKSPACE_DIR/.claude/autonomous/service-status.json') as f:
        status = json.load(f)
    unhealthy = [s for s, info in status.get('services', {}).items() 
                if info.get('status') not in ['healthy', 'active', 'running']]
    if unhealthy:
        print(f'Unhealthy services: {unhealthy}')
        sys.exit(1)
    sys.exit(0)
except Exception as e:
    print(f'Status check failed: {e}')
    sys.exit(1)
" 2>&1)
        
        if [[ $? -ne 0 ]]; then
            log_secure "WARN" "Autonomous system health check failed: $services_healthy"
            return 1
        fi
    fi
    
    return 0
}

# Secure git operations with retry logic
git_operation_with_retry() {
    local operation="$1"
    local max_attempts="$2"
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_secure "INFO" "Git $operation attempt $attempt/$max_attempts"
        
        case "$operation" in
            "pull")
                if timeout 60 git pull origin main --no-edit --no-rebase; then
                    return 0
                fi
                ;;
            "push")
                if timeout 60 git push origin main; then
                    return 0
                fi
                ;;
        esac
        
        log_secure "WARN" "Git $operation failed on attempt $attempt"
        ((attempt++))
        
        if [[ $attempt -le $max_attempts ]]; then
            sleep $((attempt * 2))  # Exponential backoff
        fi
    done
    
    log_secure "ERROR" "Git $operation failed after $max_attempts attempts"
    return 1
}

# Project files sync (immediate)
sync_project_files() {
    local changes=$(git status --porcelain -- projects/ | wc -l)
    
    if [[ $changes -eq 0 ]]; then
        return 0
    fi
    
    log_secure "INFO" "Syncing $changes project file changes"
    
    # Add only project files
    git add projects/
    
    # Create focused commit message
    local files_changed=$(git diff --cached --name-only | head -5 | tr '\n' ' ')
    git commit -m "🚀 Project sync: $changes files ($files_changed...)"
    
    return $?
}

# Workspace files batch sync (hourly)
sync_workspace_files() {
    local last_workspace_sync="$SYNC_STATE_DIR/last_workspace_sync"
    local now=$(date +%s)
    
    # Check if it's time for workspace sync
    if [[ -f "$last_workspace_sync" ]]; then
        local last_sync=$(cat "$last_workspace_sync")
        local diff=$((now - last_sync))
        
        if [[ $diff -lt $BATCH_SYNC_INTERVAL ]]; then
            return 0  # Not time yet
        fi
    fi
    
    # Check for workspace changes (excluding system files)
    local workspace_changes=$(git status --porcelain | grep -E '^[AM] (scripts/|docs/|templates/|CLAUDE\.md|README\.md)' | wc -l)
    
    if [[ $workspace_changes -eq 0 ]]; then
        echo "$now" > "$last_workspace_sync"
        return 0
    fi
    
    log_secure "INFO" "Batch syncing $workspace_changes workspace changes"
    
    # Add workspace files (excluding autonomous system files)
    git add scripts/ docs/ templates/ CLAUDE.md README.md *.md 2>/dev/null || true
    
    # Commit workspace changes
    git commit -m "🔧 Workspace sync: $workspace_changes changes ($(date '+%H:%M'))"
    
    echo "$now" > "$last_workspace_sync"
    return $?
}

# Main sync orchestration
perform_robust_sync() {
    log_secure "INFO" "Starting robust sync process"
    
    # Acquire exclusive lock
    if ! acquire_lock 30; then
        return 1
    fi
    
    # Pre-sync health checks
    if ! pre_sync_health_check; then
        log_secure "ERROR" "Pre-sync health check failed"
        return 1
    fi
    
    # Rate limiting
    if ! check_rate_limits; then
        return 1
    fi
    
    # Cooldown check
    if ! check_sync_cooldown; then
        return 0  # Not an error, just waiting
    fi
    
    cd "$WORKSPACE_DIR" || {
        log_secure "CRITICAL" "Cannot access workspace directory"
        return 1
    }
    
    # Pull first with retry
    if ! git_operation_with_retry "pull" $MAX_RETRY_ATTEMPTS; then
        log_secure "ERROR" "Failed to pull from remote"
        return 1
    fi
    
    # Sync project files (immediate priority)
    local project_sync_needed=false
    if sync_project_files; then
        project_sync_needed=true
        log_secure "INFO" "Project files staged for sync"
    fi
    
    # Sync workspace files (batch)
    local workspace_sync_needed=false  
    if sync_workspace_files; then
        workspace_sync_needed=true
        log_secure "INFO" "Workspace files staged for sync"
    fi
    
    # Push if we have changes
    if [[ "$project_sync_needed" == true ]] || [[ "$workspace_sync_needed" == true ]]; then
        if git_operation_with_retry "push" $MAX_RETRY_ATTEMPTS; then
            log_secure "INFO" "Sync completed successfully"
            echo $(date +%s) > "$SYNC_STATE_DIR/last_sync"
        else
            log_secure "ERROR" "Failed to push changes"
            return 1
        fi
    else
        log_secure "INFO" "No changes to sync"
    fi
    
    return 0
}

# Monitoring mode
monitor_mode() {
    log_secure "INFO" "Starting robust sync monitoring"
    
    # Monitor projects directory with inotify
    inotifywait -m -r -e modify,create,delete,move "$WORKSPACE_DIR/projects" \
        --exclude '\.git|\.swp|\.tmp|~$|\.#|node_modules' \
        --format '%w%f %e' |
    while read file event; do
        log_secure "INFO" "File event: $event on $file"
        
        # Debounce - wait for file operations to complete
        sleep 5
        
        # Trigger sync
        perform_robust_sync
        
        # Rate limiting delay
        sleep 10
    done
}

# Health monitoring daemon
health_daemon() {
    while true; do
        # Check sync process health
        if pgrep -f "claude-robust-sync.sh monitor" >/dev/null; then
            log_secure "DEBUG" "Sync monitor healthy"
        else
            log_secure "WARN" "Sync monitor not running"
        fi
        
        # Check git repository health
        if ! git fsck --no-progress --quiet 2>/dev/null; then
            log_secure "CRITICAL" "Git repository health check failed"
        fi
        
        sleep $HEALTH_CHECK_INTERVAL
    done
}

# Command handling
case "${1:-monitor}" in
    "monitor")
        monitor_mode
        ;;
    "sync")
        perform_robust_sync
        ;;
    "health")
        health_daemon
        ;;
    "status")
        echo -e "${GREEN}Robust Sync Status:${NC}"
        echo "Lock file: $(test -f "$LOCK_FILE" && echo "LOCKED" || echo "FREE")"
        echo "Last sync: $(test -f "$SYNC_STATE_DIR/last_sync" && date -d "@$(cat "$SYNC_STATE_DIR/last_sync")" || echo "NEVER")"
        echo "Commits last hour: $(git log --since="1 hour ago" --grep="Auto-sync\|Project sync\|Workspace sync" --oneline 2>/dev/null | wc -l)"
        echo "Repository health: $(git fsck --no-progress --quiet 2>/dev/null && echo "OK" || echo "ISSUES")"
        ;;
    "test")
        echo "Testing robust sync system..."
        if pre_sync_health_check; then
            echo -e "${GREEN}✓ Health checks passed${NC}"
        else
            echo -e "${RED}✗ Health checks failed${NC}"
        fi
        
        if check_rate_limits; then
            echo -e "${GREEN}✓ Rate limits OK${NC}"
        else
            echo -e "${YELLOW}⚠ Rate limits exceeded${NC}"
        fi
        ;;
    *)
        echo "Usage: $0 {monitor|sync|health|status|test}"
        exit 1
        ;;
esac