#!/bin/bash

# claude-sync-smart.sh - Smart Git Sync without Coordinator Overhead
# Intelligent device-aware git sync with natural timing and conflict resolution

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$WORKSPACE_ROOT/.claude"
CONFIG_FILE="$CLAUDE_DIR/sync-smart-config.json"
STATE_FILE="$CLAUDE_DIR/sync-smart-state.json"
LOCK_FILE="/tmp/claude-sync-smart.lock"
LOG_FILE="$CLAUDE_DIR/logs/sync-smart.log"

# Device detection
DEVICE_TYPE="unknown"
HOSTNAME=$(hostname)
case "$HOSTNAME" in
    *desktop*|*DESKTOP*) DEVICE_TYPE="desktop" ;;
    *laptop*|*LAPTOP*|*book*|*BOOK*) DEVICE_TYPE="laptop" ;;
    *server*|*SERVER*) DEVICE_TYPE="server" ;;
    *) DEVICE_TYPE="workstation" ;;
esac

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    case "$level" in
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" >&2 ;;
        "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[SUCCESS]${NC} $message" ;;
        "INFO") echo -e "${CYAN}[INFO]${NC} $message" ;;
        *) echo "$message" ;;
    esac
}

# Initialize config and state files
init_config() {
    mkdir -p "$CLAUDE_DIR/logs"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
    "sync_intervals": {
        "desktop": 1800,
        "laptop": 3600,
        "server": 900,
        "workstation": 1800
    },
    "natural_breakpoints": {
        "commit_keywords": ["feat:", "fix:", "docs:", "refactor:", "test:", "chore:"],
        "milestone_patterns": ["release", "version", "milestone", "complete"],
        "break_indicators": ["TODO", "FIXME", "NOTE", "REVIEW"]
    },
    "conflict_resolution": {
        "auto_merge_safe_files": [".md", ".txt", ".json", ".yml", ".yaml"],
        "manual_review_files": [".sh", ".py", ".js", ".ts"],
        "always_backup": true
    },
    "intelligence": {
        "learn_patterns": true,
        "avoid_deep_work": true,
        "batch_small_changes": true,
        "priority_files": ["CLAUDE.md", "README.md", "scripts/"]
    }
}
EOF
        log "INFO" "Created default config file"
    fi
    
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" << EOF
{
    "device": "$DEVICE_TYPE",
    "hostname": "$HOSTNAME",
    "last_sync": 0,
    "sync_count": 0,
    "patterns": {
        "typical_sync_times": [],
        "deep_work_periods": [],
        "preferred_intervals": []
    },
    "stats": {
        "successful_syncs": 0,
        "conflicts_resolved": 0,
        "auto_merges": 0,
        "manual_interventions": 0
    }
}
EOF
        log "INFO" "Created initial state file"
    fi
}

# Check if we're in deep work mode
is_deep_work() {
    local current_time=$(date +%s)
    local git_activity=$(git log --since="30 minutes ago" --oneline | wc -l)
    local file_activity=$(find "$WORKSPACE_ROOT" -name "*.sh" -o -name "*.py" -o -name "*.js" -mmin -30 | wc -l)
    
    # High activity = deep work
    if [[ $git_activity -gt 5 ]] || [[ $file_activity -gt 10 ]]; then
        return 0
    fi
    
    return 1
}

# Detect natural breakpoints
is_natural_breakpoint() {
    local last_commit=$(git log -1 --pretty=format:"%s" 2>/dev/null || echo "")
    
    # Check for milestone commits
    if echo "$last_commit" | grep -qE "(complete|finish|done|release|version|milestone)"; then
        return 0
    fi
    
    # Check for conventional commit types
    if echo "$last_commit" | grep -qE "^(feat|fix|docs|refactor|test|chore):"; then
        return 0
    fi
    
    # Check if we're not actively coding (no recent file changes)
    local recent_changes=$(find "$WORKSPACE_ROOT" -name "*.sh" -o -name "*.py" -o -name "*.js" -mmin -10 | wc -l)
    if [[ $recent_changes -eq 0 ]]; then
        return 0
    fi
    
    return 1
}

# Smart conflict detection
detect_conflicts() {
    local conflicts=()
    
    # Check for merge conflicts
    if git ls-files -u | head -1 | grep -q .; then
        log "WARN" "Git merge conflicts detected"
        return 1
    fi
    
    # Check for divergent branches
    local behind=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
    local ahead=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo 0)
    
    if [[ $behind -gt 0 ]] && [[ $ahead -gt 0 ]]; then
        log "INFO" "Branches diverged: $ahead ahead, $behind behind"
        return 2
    fi
    
    return 0
}

# Automatic conflict resolution
resolve_conflicts() {
    local resolution_strategy="$1"
    
    case "$resolution_strategy" in
        "auto_merge")
            log "INFO" "Attempting automatic merge"
            if git merge origin/main --no-edit 2>/dev/null; then
                log "SUCCESS" "Automatic merge successful"
                return 0
            else
                log "WARN" "Automatic merge failed, needs manual intervention"
                return 1
            fi
            ;;
        "rebase")
            log "INFO" "Attempting rebase"
            if git rebase origin/main 2>/dev/null; then
                log "SUCCESS" "Rebase successful"
                return 0
            else
                log "WARN" "Rebase failed, needs manual intervention"
                git rebase --abort 2>/dev/null || true
                return 1
            fi
            ;;
        "manual")
            log "INFO" "Manual intervention required"
            echo -e "${YELLOW}Conflicts detected. Please resolve manually:${NC}"
            echo "  git status"
            echo "  git add <resolved-files>"
            echo "  git commit"
            echo "  $0 sync  # retry sync"
            return 1
            ;;
    esac
}

# Intelligent sync decision
should_sync_now() {
    local current_time=$(date +%s)
    local last_sync=$(jq -r '.last_sync // 0' "$STATE_FILE")
    local device_interval=$(jq -r ".sync_intervals.$DEVICE_TYPE // 1800" "$CONFIG_FILE")
    
    # Force sync if manual override
    if [[ "${1:-}" == "force" ]]; then
        return 0
    fi
    
    # Don't sync during deep work
    if is_deep_work; then
        log "INFO" "Skipping sync: deep work detected"
        return 1
    fi
    
    # Sync at natural breakpoints
    if is_natural_breakpoint; then
        log "INFO" "Natural breakpoint detected, syncing"
        return 0
    fi
    
    # Time-based fallback
    local time_since_sync=$((current_time - last_sync))
    if [[ $time_since_sync -gt $device_interval ]]; then
        log "INFO" "Time-based sync triggered (${time_since_sync}s since last sync)"
        return 0
    fi
    
    return 1
}

# Update patterns and learning
update_patterns() {
    local current_time=$(date +%s)
    local hour=$(date +%H)
    
    # Update typical sync times
    jq --argjson time "$current_time" --argjson hour "$hour" '
        .patterns.typical_sync_times += [$hour] |
        .patterns.typical_sync_times |= unique |
        .last_sync = $time |
        .sync_count += 1 |
        .stats.successful_syncs += 1
    ' "$STATE_FILE" > "$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

# Main sync function
perform_sync() {
    local force_sync="${1:-false}"
    
    # Check if sync is needed
    if [[ "$force_sync" != "true" ]] && ! should_sync_now "$force_sync"; then
        return 0
    fi
    
    log "INFO" "Starting smart sync for $DEVICE_TYPE"
    
    # Ensure we're in the workspace
    cd "$WORKSPACE_ROOT"
    
    # Check git status
    if ! git status &>/dev/null; then
        log "ERROR" "Not in a git repository"
        return 1
    fi
    
    # Fetch latest changes
    log "INFO" "Fetching latest changes"
    if ! git fetch origin; then
        log "ERROR" "Failed to fetch from origin"
        return 1
    fi
    
    # Check for conflicts
    conflict_status=0
    detect_conflicts || conflict_status=$?
    
    case $conflict_status in
        0)
            log "INFO" "No conflicts detected"
            ;;
        1)
            log "WARN" "Merge conflicts detected"
            resolve_conflicts "manual"
            return 1
            ;;
        2)
            log "INFO" "Branches diverged, attempting resolution"
            if ! resolve_conflicts "auto_merge"; then
                if ! resolve_conflicts "rebase"; then
                    resolve_conflicts "manual"
                    return 1
                fi
            fi
            ;;
    esac
    
    # Stage and commit local changes if any
    if ! git diff-index --quiet HEAD --; then
        log "INFO" "Staging local changes"
        git add .
        
        local commit_msg="Auto-sync: $(date '+%Y-%m-%d %H:%M:%S') on $HOSTNAME"
        if git commit -m "$commit_msg"; then
            log "SUCCESS" "Local changes committed"
        fi
    fi
    
    # Pull latest changes
    log "INFO" "Pulling latest changes"
    if git pull origin main; then
        log "SUCCESS" "Pull successful"
    else
        log "ERROR" "Pull failed"
        return 1
    fi
    
    # Push local changes
    log "INFO" "Pushing local changes"
    if git push origin main; then
        log "SUCCESS" "Push successful"
    else
        log "WARN" "Push failed, will retry later"
        return 1
    fi
    
    # Update patterns and stats
    update_patterns
    
    log "SUCCESS" "Smart sync completed successfully"
    return 0
}

# Start sync daemon
start_daemon() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "INFO" "Sync daemon already running (PID: $pid)"
            return 0
        else
            rm -f "$LOCK_FILE"
        fi
    fi
    
    echo $$ > "$LOCK_FILE"
    log "INFO" "Starting sync daemon for $DEVICE_TYPE"
    
    trap 'rm -f "$LOCK_FILE"; exit' INT TERM EXIT
    
    while true; do
        if should_sync_now; then
            perform_sync
        fi
        
        # Adaptive sleep based on device type and patterns
        local sleep_time=$(jq -r ".sync_intervals.$DEVICE_TYPE // 1800" "$CONFIG_FILE")
        sleep $((sleep_time / 10))  # Check every 1/10 of sync interval
    done
}

# Stop sync daemon
stop_daemon() {
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$LOCK_FILE"
            log "SUCCESS" "Sync daemon stopped"
        else
            rm -f "$LOCK_FILE"
            log "INFO" "Sync daemon was not running"
        fi
    else
        log "INFO" "No sync daemon running"
    fi
}

# Show status
show_status() {
    local current_time=$(date +%s)
    local last_sync=$(jq -r '.last_sync // 0' "$STATE_FILE")
    local sync_count=$(jq -r '.sync_count // 0' "$STATE_FILE")
    local successful_syncs=$(jq -r '.stats.successful_syncs // 0' "$STATE_FILE")
    
    echo -e "${CYAN}Smart Sync Status${NC}"
    echo "==================="
    echo -e "Device: ${GREEN}$DEVICE_TYPE${NC} ($HOSTNAME)"
    echo -e "Total syncs: ${GREEN}$sync_count${NC}"
    echo -e "Successful: ${GREEN}$successful_syncs${NC}"
    
    if [[ $last_sync -gt 0 ]]; then
        local time_ago=$((current_time - last_sync))
        echo -e "Last sync: ${GREEN}$time_ago${NC} seconds ago"
    else
        echo -e "Last sync: ${YELLOW}Never${NC}"
    fi
    
    if [[ -f "$LOCK_FILE" ]]; then
        local pid=$(cat "$LOCK_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "Daemon: ${GREEN}Running${NC} (PID: $pid)"
        else
            echo -e "Daemon: ${RED}Stale lock${NC}"
            rm -f "$LOCK_FILE"
        fi
    else
        echo -e "Daemon: ${RED}Not running${NC}"
    fi
    
    echo
    if is_deep_work; then
        echo -e "Status: ${YELLOW}Deep work detected - sync paused${NC}"
    elif is_natural_breakpoint; then
        echo -e "Status: ${GREEN}Natural breakpoint - ready to sync${NC}"
    else
        echo -e "Status: ${BLUE}Normal operation${NC}"
    fi
}

# Main command dispatcher
main() {
    init_config
    
    case "${1:-status}" in
        "sync")
            perform_sync true
            ;;
        "start")
            start_daemon
            ;;
        "stop")
            stop_daemon
            ;;
        "status")
            show_status
            ;;
        "force")
            perform_sync true
            ;;
        "test")
            echo "Testing sync conditions..."
            echo "Deep work: $(is_deep_work && echo 'Yes' || echo 'No')"
            echo "Natural breakpoint: $(is_natural_breakpoint && echo 'Yes' || echo 'No')"
            echo "Should sync: $(should_sync_now && echo 'Yes' || echo 'No')"
            ;;
        *)
            echo "Usage: $0 {sync|start|stop|status|force|test}"
            echo
            echo "Commands:"
            echo "  sync   - Perform intelligent sync now"
            echo "  start  - Start sync daemon"
            echo "  stop   - Stop sync daemon"
            echo "  status - Show sync status"
            echo "  force  - Force sync regardless of conditions"
            echo "  test   - Test sync conditions"
            exit 1
            ;;
    esac
}

main "$@"