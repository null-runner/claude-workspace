#!/bin/bash
# Claude Full Workspace Sync - Complete bi-directional sync with autonomous system coordination
# Handles auto-sync scheduling and prevents infinite loops

WORKSPACE_DIR="$HOME/claude-workspace"
SYNC_CONFIG="$WORKSPACE_DIR/.claude/sync/sync-config.json"
SYNC_SCHEDULE_PID="$WORKSPACE_DIR/.claude/sync/schedule.pid"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Setup
mkdir -p "$(dirname "$SYNC_CONFIG")"

# Initialize sync configuration
init_sync_config() {
    if [[ ! -f "$SYNC_CONFIG" ]]; then
        cat > "$SYNC_CONFIG" << 'EOF'
{
    "auto_sync": {
        "enabled": false,
        "interval_minutes": 60,
        "sync_on_startup": false,
        "sync_on_exit": true
    },
    "conflict_resolution": {
        "strategy": "manual",
        "auto_commit_threshold": 10
    },
    "filters": {
        "exclude_patterns": [
            "*.tmp",
            "*.log",
            ".DS_Store",
            "node_modules/",
            ".git/hooks/",
            ".claude/autonomous/*.pid",
            ".claude/sync/sync.lock"
        ]
    },
    "monitoring": {
        "max_file_changes_before_sync": 50,
        "min_time_between_syncs": 300
    }
}
EOF
        echo -e "${GREEN}✅ Initialized sync configuration${NC}"
    fi
}

# Load sync configuration
load_sync_config() {
    if [[ -f "$SYNC_CONFIG" ]]; then
        export SYNC_CONFIG
        python3 << 'EOF'
import json
import os
config_file = os.environ.get('SYNC_CONFIG')
with open(config_file, 'r') as f:
    config = json.load(f)

# Export configuration as environment variables
print(f"export AUTO_SYNC_ENABLED={str(config['auto_sync']['enabled']).lower()}")
print(f"export AUTO_SYNC_INTERVAL={config['auto_sync']['interval_minutes']}")
print(f"export SYNC_ON_STARTUP={str(config['auto_sync']['sync_on_startup']).lower()}")
print(f"export SYNC_ON_EXIT={str(config['auto_sync']['sync_on_exit']).lower()}")
print(f"export MAX_CHANGES_BEFORE_SYNC={config['monitoring']['max_file_changes_before_sync']}")
print(f"export MIN_TIME_BETWEEN_SYNCS={config['monitoring']['min_time_between_syncs']}")
EOF
    fi
}

# Check if automatic sync scheduler is running
check_scheduler_running() {
    if [[ -f "$SYNC_SCHEDULE_PID" ]]; then
        local pid=$(cat "$SYNC_SCHEDULE_PID")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            rm -f "$SYNC_SCHEDULE_PID"
            return 1  # Not running
        fi
    fi
    return 1
}

# Intelligent sync decision engine
should_perform_sync() {
    local reason="$1"
    
    # Load configuration
    eval "$(load_sync_config)"
    
    case "$reason" in
        "startup")
            [[ "$SYNC_ON_STARTUP" == "true" ]]
            ;;
        "exit")
            [[ "$SYNC_ON_EXIT" == "true" ]]
            ;;
        "scheduled")
            [[ "$AUTO_SYNC_ENABLED" == "true" ]]
            ;;
        "manual")
            true  # Always allow manual sync
            ;;
        "threshold")
            # Check if we've exceeded change threshold
            local change_count=$(git status --porcelain | wc -l)
            [[ $change_count -ge $MAX_CHANGES_BEFORE_SYNC ]]
            ;;
        *)
            false
            ;;
    esac
}

# Check sync timing constraints
check_sync_timing() {
    local last_sync_file="$WORKSPACE_DIR/.claude/sync/last-sync-timestamp"
    
    if [[ ! -f "$last_sync_file" ]]; then
        return 0  # No previous sync
    fi
    
    eval "$(load_sync_config)"
    local last_sync=$(cat "$last_sync_file")
    local current_time=$(date +%s)
    local time_diff=$((current_time - last_sync))
    
    [[ $time_diff -ge $MIN_TIME_BETWEEN_SYNCS ]]
}

# Record sync timestamp
record_sync_timestamp() {
    local last_sync_file="$WORKSPACE_DIR/.claude/sync/last-sync-timestamp"
    date +%s > "$last_sync_file"
}

# Smart sync with decision logic
smart_sync() {
    local reason="${1:-manual}"
    local force="${2:-false}"
    
    echo -e "${CYAN}🧠 Smart Sync Decision Engine${NC}"
    echo "   Reason: $reason"
    echo "   Force: $force"
    
    # Check if sync should be performed
    if [[ "$force" != "true" ]]; then
        if ! should_perform_sync "$reason"; then
            echo -e "${YELLOW}⏭️  Sync skipped: Not required for reason '$reason'${NC}"
            return 0
        fi
        
        if ! check_sync_timing; then
            echo -e "${YELLOW}⏭️  Sync skipped: Too soon since last sync${NC}"
            return 0
        fi
    fi
    
    # Check workspace state before sync
    local change_count=$(git status --porcelain | wc -l)
    echo "   Local changes: $change_count files"
    
    if [[ $change_count -eq 0 && "$reason" != "startup" ]]; then
        echo -e "${GREEN}✅ No changes to sync${NC}"
        return 0
    fi
    
    # Perform atomic sync
    echo -e "${BLUE}🔄 Initiating atomic sync...${NC}"
    
    if "$WORKSPACE_DIR/scripts/claude-atomic-sync.sh" sync; then
        record_sync_timestamp
        echo -e "${GREEN}✅ Smart sync completed successfully${NC}"
        
        # Log sync event
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS Smart sync completed (reason: $reason, changes: $change_count)" >> "$WORKSPACE_DIR/.claude/sync/sync.log"
        
        return 0
    else
        echo -e "${RED}❌ Smart sync failed${NC}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR Smart sync failed (reason: $reason, changes: $change_count)" >> "$WORKSPACE_DIR/.claude/sync/sync.log"
        return 1
    fi
}

# Background sync scheduler
run_sync_scheduler() {
    eval "$(load_sync_config)"
    
    if [[ "$AUTO_SYNC_ENABLED" != "true" ]]; then
        echo -e "${YELLOW}⚠️  Auto-sync disabled in configuration${NC}"
        return 1
    fi
    
    echo -e "${CYAN}⏰ Starting sync scheduler (interval: ${AUTO_SYNC_INTERVAL}min)${NC}"
    echo $$ > "$SYNC_SCHEDULE_PID"
    
    # Sync scheduler loop
    while true; do
        sleep $((AUTO_SYNC_INTERVAL * 60))
        
        # Check if scheduler PID file still exists (shutdown signal)
        if [[ ! -f "$SYNC_SCHEDULE_PID" ]]; then
            break
        fi
        
        # Perform scheduled sync
        echo -e "${BLUE}⏰ Scheduled sync triggered${NC}"
        smart_sync "scheduled"
    done
    
    # Cleanup
    rm -f "$SYNC_SCHEDULE_PID"
    echo -e "${GREEN}✅ Sync scheduler stopped${NC}"
}

# Start sync scheduler in background
start_scheduler() {
    if check_scheduler_running; then
        echo -e "${YELLOW}⚠️  Sync scheduler already running${NC}"
        return 1
    fi
    
    init_sync_config
    eval "$(load_sync_config)"
    
    if [[ "$AUTO_SYNC_ENABLED" != "true" ]]; then
        echo -e "${YELLOW}⚠️  Auto-sync disabled. Enable with: $0 config enable${NC}"
        return 1
    fi
    
    nohup "$0" _scheduler >/dev/null 2>&1 &
    sleep 1
    
    if check_scheduler_running; then
        echo -e "${GREEN}✅ Sync scheduler started${NC}"
    else
        echo -e "${RED}❌ Failed to start sync scheduler${NC}"
        return 1
    fi
}

# Stop sync scheduler
stop_scheduler() {
    if ! check_scheduler_running; then
        echo -e "${YELLOW}⚠️  Sync scheduler not running${NC}"
        return 1
    fi
    
    local pid=$(cat "$SYNC_SCHEDULE_PID")
    if kill "$pid" 2>/dev/null; then
        rm -f "$SYNC_SCHEDULE_PID"
        echo -e "${GREEN}✅ Sync scheduler stopped${NC}"
    else
        echo -e "${RED}❌ Failed to stop sync scheduler${NC}"
        return 1
    fi
}

# Configure sync settings
configure_sync() {
    local action="$1"
    local value="$2"
    
    init_sync_config
    
    case "$action" in
        "enable")
            jq '.auto_sync.enabled = true' "$SYNC_CONFIG" > "$SYNC_CONFIG.tmp" && mv "$SYNC_CONFIG.tmp" "$SYNC_CONFIG"
            echo -e "${GREEN}✅ Auto-sync enabled${NC}"
            ;;
        "disable")
            jq '.auto_sync.enabled = false' "$SYNC_CONFIG" > "$SYNC_CONFIG.tmp" && mv "$SYNC_CONFIG.tmp" "$SYNC_CONFIG"
            echo -e "${YELLOW}⚠️  Auto-sync disabled${NC}"
            ;;
        "interval")
            if [[ -n "$value" && "$value" =~ ^[0-9]+$ ]]; then
                jq ".auto_sync.interval_minutes = $value" "$SYNC_CONFIG" > "$SYNC_CONFIG.tmp" && mv "$SYNC_CONFIG.tmp" "$SYNC_CONFIG"
                echo -e "${GREEN}✅ Sync interval set to $value minutes${NC}"
            else
                echo -e "${RED}❌ Invalid interval. Use a number (minutes)${NC}"
                return 1
            fi
            ;;
        "show")
            echo -e "${PURPLE}🔧 SYNC CONFIGURATION${NC}"
            jq . "$SYNC_CONFIG"
            ;;
        *)
            echo -e "${RED}❌ Unknown config action: $action${NC}"
            return 1
            ;;
    esac
}

# Show comprehensive sync status
show_sync_status() {
    echo -e "${PURPLE}🔄 FULL WORKSPACE SYNC STATUS${NC}"
    echo ""
    
    # Scheduler status
    if check_scheduler_running; then
        local pid=$(cat "$SYNC_SCHEDULE_PID")
        echo -e "${GREEN}✅ Sync scheduler: RUNNING (PID: $pid)${NC}"
    else
        echo -e "${YELLOW}⏸️  Sync scheduler: STOPPED${NC}"
    fi
    
    # Configuration status
    eval "$(load_sync_config)"
    echo -e "${BLUE}⚙️  Auto-sync: $AUTO_SYNC_ENABLED (${AUTO_SYNC_INTERVAL}min intervals)${NC}"
    
    # Atomic sync status
    echo ""
    "$WORKSPACE_DIR/scripts/claude-atomic-sync.sh" status
    
    # Recent sync history
    echo ""
    echo "📋 Recent sync history:"
    if [[ -f "$WORKSPACE_DIR/.claude/sync/sync.log" ]]; then
        tail -n 5 "$WORKSPACE_DIR/.claude/sync/sync.log" | while read -r line; do
            echo "   $line"
        done
    else
        echo "   No sync history available"
    fi
}

# Emergency stop all sync operations
emergency_stop() {
    echo -e "${RED}🚨 EMERGENCY STOP - Halting all sync operations${NC}"
    
    # Stop scheduler
    stop_scheduler 2>/dev/null
    
    # Remove any sync locks
    rm -f "$WORKSPACE_DIR/.claude/sync/sync.lock"
    rm -f "$WORKSPACE_DIR/.claude/autonomous/sync-pause.lock"
    
    # Safely terminate any running sync processes
    local process_manager="$WORKSPACE_DIR/scripts/claude-process-manager.sh"
    if [[ -f "$process_manager" ]]; then
        echo -e "${CYAN}🔒 Using safe process manager to stop sync processes${NC}"
        local pids
        mapfile -t pids < <("$process_manager" find-processes "claude-atomic-sync" 2>/dev/null)
        for pid in "${pids[@]}"; do
            "$process_manager" kill-pid "$pid" "claude-atomic-sync" 5 >/dev/null 2>&1
        done
    else
        # Fallback with ownership validation
        local current_uid=$(id -u)
        local pids
        mapfile -t pids < <(pgrep -f "claude-atomic-sync" 2>/dev/null)
        for pid in "${pids[@]}"; do
            local owner=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')
            if [[ "$owner" == "$current_uid" ]]; then
                kill "$pid" 2>/dev/null
            fi
        done
    fi
    
    echo -e "${GREEN}✅ Emergency stop completed${NC}"
}

# Help
show_help() {
    echo "Claude Full Workspace Sync - Complete bi-directional sync with autonomous coordination"
    echo ""
    echo "Usage: claude-full-workspace-sync [command] [options]"
    echo ""
    echo "Sync Commands:"
    echo "  sync [reason]                Manual smart sync (default: manual)"
    echo "  force-sync                   Force sync regardless of timing/rules"
    echo "  pull                         Pull-only sync from remote"
    echo "  push                         Push-only sync to remote"
    echo ""
    echo "Scheduler Commands:"
    echo "  start-scheduler              Start automatic sync scheduler"
    echo "  stop-scheduler               Stop automatic sync scheduler"
    echo "  restart-scheduler            Restart sync scheduler"
    echo ""
    echo "Configuration:"
    echo "  config enable                Enable auto-sync"
    echo "  config disable               Disable auto-sync"
    echo "  config interval [minutes]    Set sync interval"
    echo "  config show                  Show current configuration"
    echo ""
    echo "Status & Control:"
    echo "  status                       Show comprehensive sync status"
    echo "  emergency-stop               Emergency stop all sync operations"
    echo ""
    echo "Examples:"
    echo "  claude-full-workspace-sync sync startup"
    echo "  claude-full-workspace-sync config enable"
    echo "  claude-full-workspace-sync start-scheduler"
    echo "  claude-full-workspace-sync status"
}

# Main logic
case "${1:-}" in
    "sync")
        smart_sync "${2:-manual}"
        ;;
    "force-sync")
        smart_sync "manual" "true"
        ;;
    "pull")
        "$WORKSPACE_DIR/scripts/claude-atomic-sync.sh" pull
        ;;
    "push")
        "$WORKSPACE_DIR/scripts/claude-atomic-sync.sh" push
        ;;
    "start-scheduler")
        start_scheduler
        ;;
    "stop-scheduler")
        stop_scheduler
        ;;
    "restart-scheduler")
        stop_scheduler
        sleep 2
        start_scheduler
        ;;
    "_scheduler")
        # Internal command for background scheduler
        run_sync_scheduler
        ;;
    "config")
        configure_sync "$2" "$3"
        ;;
    "status")
        show_sync_status
        ;;
    "emergency-stop")
        emergency_stop
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