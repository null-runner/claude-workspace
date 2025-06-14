#!/bin/bash
# Claude Auto Context Daemon - Unified context monitoring + project detection
# Combines context auto-save with project detection for simplified architecture

WORKSPACE_DIR="$HOME/claude-workspace"
CONTEXT_DIR="$WORKSPACE_DIR/.claude/context"
DAEMON_LOG="$CONTEXT_DIR/auto-context.log"
PID_FILE="$CONTEXT_DIR/auto-context.pid"
STATUS_FILE="$CONTEXT_DIR/auto-context-status.json"

# Configuration
CONTEXT_SAVE_INTERVAL=300  # 5 minutes
PROJECT_CHECK_INTERVAL=30  # 30 seconds
MAX_LOG_SIZE=10485760     # 10MB

# Adaptive intervals
IDLE_THRESHOLD=600        # 10 minutes
DORMANT_THRESHOLD=1800    # 30 minutes
IDLE_MULTIPLIER=2         # 2x slower when idle
DORMANT_MULTIPLIER=4      # 4x slower when dormant

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$CONTEXT_DIR"

# Logging function
log_daemon() {
    local level="$1"
    local component="$2"
    local message="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] [$component] $message" >> "$DAEMON_LOG"
    
    # Rotate log if too large
    if [[ -f "$DAEMON_LOG" ]] && [[ $(stat -c%s "$DAEMON_LOG" 2>/dev/null || echo 0) -gt $MAX_LOG_SIZE ]]; then
        mv "$DAEMON_LOG" "${DAEMON_LOG}.old"
        echo "[$timestamp] [INFO] [DAEMON] Log rotated due to size" >> "$DAEMON_LOG"
    fi
}

# Update status
update_status() {
    local component="$1"
    local status="$2"
    local message="$3"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    cat > "$STATUS_FILE" << EOF
{
  "daemon": {
    "pid": $$,
    "status": "running",
    "last_update": "$timestamp"
  },
  "context_monitor": {
    "status": "$([[ "$component" == "context" ]] && echo "$status" || echo "running")",
    "message": "$([[ "$component" == "context" ]] && echo "$message" || echo "Context monitoring active")",
    "last_update": "$timestamp",
    "interval": "$CONTEXT_SAVE_INTERVAL"
  },
  "project_monitor": {
    "status": "$([[ "$component" == "project" ]] && echo "$status" || echo "running")",
    "message": "$([[ "$component" == "project" ]] && echo "$message" || echo "Project detection active")",
    "last_update": "$timestamp",
    "interval": "$PROJECT_CHECK_INTERVAL"
  }
}
EOF
}

# Check if daemon is running
check_daemon_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            # Stale PID file
            rm -f "$PID_FILE"
            return 1  # Not running
        fi
    fi
    return 1  # Not running
}

# Check for sync pause
check_sync_pause() {
    [[ -f "$WORKSPACE_DIR/.claude/autonomous/sync-pause.lock" ]]
}

# Wait for sync completion
wait_for_sync_completion() {
    local max_wait=60  # 1 minute max wait
    local wait_count=0
    
    while check_sync_pause && [[ $wait_count -lt $max_wait ]]; do
        sleep 2
        ((wait_count += 2))
    done
    
    return $([[ $wait_count -lt $max_wait ]] && echo 0 || echo 1)
}

# Context auto-save function
auto_save_context() {
    log_daemon "DEBUG" "CONTEXT" "Starting auto-save check"
    
    # Check for sync pause
    if check_sync_pause; then
        if ! wait_for_sync_completion; then
            log_daemon "WARN" "CONTEXT" "Sync pause timeout - skipping save"
            update_status "context" "warning" "Skipped due to sync pause timeout"
            return 1
        fi
    fi
    
    # Try to save context
    if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
        local result
        result=$("$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" save auto "Auto-save from daemon" "" "" 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_daemon "INFO" "CONTEXT" "Auto-save completed successfully"
            update_status "context" "active" "Auto-save completed successfully"
        elif [[ $exit_code -eq 2 ]]; then
            log_daemon "DEBUG" "CONTEXT" "Auto-save skipped - no significant changes"
            update_status "context" "active" "Auto-save skipped - no changes"
        else
            log_daemon "ERROR" "CONTEXT" "Auto-save failed: $result"
            update_status "context" "error" "Auto-save failed: $(echo "$result" | head -n1)"
        fi
    else
        log_daemon "ERROR" "CONTEXT" "Simplified memory script not found"
        update_status "context" "error" "Memory script not found"
    fi
}

# Project detection function
check_project_changes() {
    log_daemon "DEBUG" "PROJECT" "Checking project changes"
    
    # Check for sync pause
    if check_sync_pause; then
        if ! wait_for_sync_completion; then
            log_daemon "WARN" "PROJECT" "Sync pause timeout - skipping check"
            update_status "project" "warning" "Skipped due to sync pause timeout"
            return 1
        fi
    fi
    
    # Run project detection
    if [[ -f "$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" ]]; then
        local result
        result=$(WORKSPACE_DIR="$WORKSPACE_DIR" "$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" check 2>&1)
        local exit_code=$?
        
        if [[ $exit_code -eq 0 ]]; then
            log_daemon "DEBUG" "PROJECT" "Project detection completed"
            update_status "project" "active" "Project detection completed"
        elif [[ $exit_code -eq 1 ]]; then
            log_daemon "DEBUG" "PROJECT" "No project changes detected"
            update_status "project" "active" "No changes detected"
        else
            log_daemon "WARN" "PROJECT" "Project detection had issues: $result"
            update_status "project" "warning" "Detection issues: $(echo "$result" | head -n1)"
        fi
    else
        log_daemon "ERROR" "PROJECT" "Project detector script not found"
        update_status "project" "error" "Project detector script not found"
    fi
}

# Get last file modification time in workspace
get_last_activity_time() {
    # Find most recently modified file (excluding .claude and .git)
    local last_mod=$(find "$WORKSPACE_DIR" -type f \
        -not -path "*/.claude/*" \
        -not -path "*/.git/*" \
        -not -path "*/node_modules/*" \
        -not -path "*/__pycache__/*" \
        -printf '%T@\n' 2>/dev/null | sort -nr | head -1)
    
    if [[ -n "$last_mod" ]]; then
        echo "${last_mod%.*}"  # Remove decimal part
    else
        echo "0"
    fi
}

# Calculate adaptive interval
calculate_adaptive_interval() {
    local base_interval="$1"
    local current_time=$(date +%s)
    local last_activity=$(get_last_activity_time)
    local idle_time=$((current_time - last_activity))
    
    if [[ $idle_time -gt $DORMANT_THRESHOLD ]]; then
        echo $((base_interval * DORMANT_MULTIPLIER))
        log_daemon "DEBUG" "ADAPTIVE" "Dormant mode: interval ${base_interval}s -> $((base_interval * DORMANT_MULTIPLIER))s"
    elif [[ $idle_time -gt $IDLE_THRESHOLD ]]; then
        echo $((base_interval * IDLE_MULTIPLIER))
        log_daemon "DEBUG" "ADAPTIVE" "Idle mode: interval ${base_interval}s -> $((base_interval * IDLE_MULTIPLIER))s"
    else
        echo "$base_interval"
    fi
}

# Main daemon loop
run_daemon() {
    local context_counter=0
    local project_counter=0
    local current_project_interval=$PROJECT_CHECK_INTERVAL
    local current_context_interval=$CONTEXT_SAVE_INTERVAL
    
    log_daemon "INFO" "DAEMON" "Auto-context daemon started (PID: $$)"
    echo $$ > "$PID_FILE"
    
    # Initial status
    update_status "daemon" "running" "Auto-context daemon started"
    
    while true; do
        # Check if we should still be running
        if [[ ! -f "$PID_FILE" ]]; then
            log_daemon "INFO" "DAEMON" "PID file removed - shutting down"
            break
        fi
        
        # Update adaptive intervals every minute
        if [[ $((context_counter % 60)) -eq 0 ]]; then
            current_project_interval=$(calculate_adaptive_interval $PROJECT_CHECK_INTERVAL)
            current_context_interval=$(calculate_adaptive_interval $CONTEXT_SAVE_INTERVAL)
        fi
        
        # Context monitoring (adaptive interval)
        if [[ $context_counter -ge $current_context_interval ]]; then
            auto_save_context
            context_counter=0
        fi
        
        # Project monitoring (adaptive interval)  
        if [[ $project_counter -ge $current_project_interval ]]; then
            check_project_changes
            project_counter=0
        fi
        
        # Sleep 1 second and increment counters
        sleep 1
        ((context_counter++))
        ((project_counter++))
    done
    
    log_daemon "INFO" "DAEMON" "Auto-context daemon stopped"
    rm -f "$PID_FILE"
}

# Start daemon
start_daemon() {
    if check_daemon_running; then
        echo -e "${YELLOW}⚠️  Auto-context daemon already running${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🤖 Starting auto-context daemon...${NC}"
    echo -e "${BLUE}   📝 Context monitoring: ${CONTEXT_SAVE_INTERVAL}s intervals${NC}"
    echo -e "${BLUE}   📁 Project monitoring: ${PROJECT_CHECK_INTERVAL}s intervals${NC}"
    
    # Start in background
    nohup "$0" daemon >/dev/null 2>&1 &
    
    # Wait for startup
    sleep 2
    
    if check_daemon_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}✅ Auto-context daemon started (PID: $pid)${NC}"
        echo -e "${CYAN}   Log: $DAEMON_LOG${NC}"
        echo -e "${CYAN}   Status: $STATUS_FILE${NC}"
    else
        echo -e "${RED}❌ Failed to start auto-context daemon${NC}"
        return 1
    fi
}

# Stop daemon
stop_daemon() {
    if ! check_daemon_running; then
        echo -e "${YELLOW}⚠️  Auto-context daemon not running${NC}"
        return 1
    fi
    
    local pid=$(cat "$PID_FILE")
    echo -e "${YELLOW}🛑 Stopping auto-context daemon (PID: $pid)...${NC}"
    
    # Final context save before stopping
    echo -e "${BLUE}   💾 Final context save...${NC}"
    if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" save "daemon_shutdown" >/dev/null 2>&1
    fi
    
    # Graceful shutdown
    rm -f "$PID_FILE"
    
    # Wait for daemon to exit
    local count=0
    while kill -0 "$pid" 2>/dev/null && [[ $count -lt 10 ]]; do
        sleep 1
        ((count++))
    done
    
    if kill -0 "$pid" 2>/dev/null; then
        echo -e "${RED}⚠️  Force killing daemon...${NC}"
        kill -KILL "$pid" 2>/dev/null
    fi
    
    echo -e "${GREEN}✅ Auto-context daemon stopped${NC}"
}

# Show status
show_status() {
    echo -e "${CYAN}🤖 AUTO-CONTEXT DAEMON STATUS${NC}"
    echo ""
    
    if check_daemon_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}✅ Daemon: RUNNING (PID: $pid)${NC}"
        
        # Show detailed status if available
        if [[ -f "$STATUS_FILE" ]]; then
            echo ""
            echo -e "${BLUE}📊 Component Status:${NC}"
            
            # Parse status JSON
            local context_status=$(python3 -c "
import json
try:
    with open('$STATUS_FILE', 'r') as f:
        data = json.load(f)
    print(data['context_monitor']['status'])
    print(data['context_monitor']['message'])
    print(data['project_monitor']['status'])
    print(data['project_monitor']['message'])
except:
    print('unknown')
    print('Status file error')
    print('unknown')
    print('Status file error')
" 2>/dev/null)
            
            local lines=($context_status)
            echo -e "   📝 Context Monitor: ${lines[0]^^} - ${lines[1]}"
            echo -e "   📁 Project Monitor: ${lines[2]^^} - ${lines[3]}"
        fi
    else
        echo -e "${RED}❌ Daemon: NOT RUNNING${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📁 Files:${NC}"
    echo "   Log: $DAEMON_LOG"
    echo "   Status: $STATUS_FILE"
    echo "   PID: $PID_FILE"
}

# Show recent logs
show_logs() {
    local lines="${1:-20}"
    
    if [[ -f "$DAEMON_LOG" ]]; then
        echo -e "${CYAN}📋 RECENT AUTO-CONTEXT LOGS (last $lines lines):${NC}"
        echo ""
        tail -n "$lines" "$DAEMON_LOG"
    else
        echo -e "${YELLOW}⚠️  No log file found${NC}"
    fi
}

# Help
show_help() {
    echo "Claude Auto-Context Daemon - Unified context + project monitoring"
    echo ""
    echo "Usage: claude-auto-context [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start auto-context daemon"
    echo "  stop        Stop auto-context daemon"
    echo "  restart     Restart auto-context daemon"
    echo "  status      Show daemon status"
    echo "  logs [n]    Show recent logs (default: 20 lines)"
    echo "  daemon      Run daemon (internal use)"
    echo ""
    echo "Features:"
    echo "  • Context auto-save every 5 minutes"
    echo "  • Project detection every 30 seconds"
    echo "  • Sync-aware operations"
    echo "  • Automatic log rotation"
}

# Main logic
case "${1:-}" in
    "start")
        start_daemon
        ;;
    "stop")
        stop_daemon
        ;;
    "restart")
        stop_daemon
        sleep 2
        start_daemon
        ;;
    "status")
        show_status
        ;;
    "logs")
        show_logs "${2:-20}"
        ;;
    "daemon")
        # Internal command for daemon process
        trap "log_daemon 'INFO' 'DAEMON' 'Received shutdown signal'; exit 0" SIGTERM SIGINT
        run_daemon
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_status
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac