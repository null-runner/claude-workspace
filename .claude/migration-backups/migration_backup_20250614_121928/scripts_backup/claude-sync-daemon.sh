#!/bin/bash
# Claude Sync Daemon - Background process to handle sync coordination queue
# Runs as a daemon and processes queued sync operations automatically

WORKSPACE_DIR="$HOME/claude-workspace"
DAEMON_DIR="$WORKSPACE_DIR/.claude/sync-coordination"
DAEMON_PID_FILE="$DAEMON_DIR/sync-daemon.pid"
DAEMON_LOG="$DAEMON_DIR/daemon.log"
COORDINATOR_SCRIPT="$WORKSPACE_DIR/scripts/claude-sync-coordinator.sh"

# Daemon configuration
PROCESS_INTERVAL=30      # Process queue every 30 seconds
HEALTH_CHECK_INTERVAL=300 # Health check every 5 minutes
MAX_QUEUE_AGE=3600       # Maximum age for queued operations (1 hour)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$DAEMON_DIR"

# Logging function with rotation
daemon_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$DAEMON_LOG"
    
    # Rotate log if too large (keep last 200 lines)
    if [[ $(wc -l < "$DAEMON_LOG" 2>/dev/null || echo 0) -gt 500 ]]; then
        tail -n 200 "$DAEMON_LOG" > "$DAEMON_LOG.tmp" && mv "$DAEMON_LOG.tmp" "$DAEMON_LOG"
    fi
    
    # Echo to stdout for systemd/monitoring
    echo -e "${CYAN}[SYNC-DAEMON]${NC} [$level] $message"
}

# Check if daemon is already running
is_daemon_running() {
    if [[ -f "$DAEMON_PID_FILE" ]]; then
        local pid=$(cat "$DAEMON_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            # Stale PID file
            rm -f "$DAEMON_PID_FILE"
            return 1  # Not running
        fi
    else
        return 1  # Not running
    fi
}

# Start daemon
start_daemon() {
    if is_daemon_running; then
        echo -e "${YELLOW}Sync daemon is already running (PID: $(cat "$DAEMON_PID_FILE"))${NC}"
        return 1
    fi
    
    echo -e "${GREEN}Starting sync coordination daemon...${NC}"
    
    # Start in background
    nohup "$0" run > "$DAEMON_LOG" 2>&1 &
    local daemon_pid=$!
    
    # Save PID
    echo "$daemon_pid" > "$DAEMON_PID_FILE"
    
    # Wait a moment to check if it started successfully
    sleep 2
    
    if is_daemon_running; then
        echo -e "${GREEN}✅ Sync daemon started successfully (PID: $daemon_pid)${NC}"
        echo "Logs: $DAEMON_LOG"
        return 0
    else
        echo -e "${RED}❌ Failed to start sync daemon${NC}"
        return 1
    fi
}

# Stop daemon
stop_daemon() {
    if ! is_daemon_running; then
        echo -e "${YELLOW}Sync daemon is not running${NC}"
        return 1
    fi
    
    local pid=$(cat "$DAEMON_PID_FILE")
    echo -e "${YELLOW}Stopping sync daemon (PID: $pid)...${NC}"
    
    # Send TERM signal
    kill -TERM "$pid" 2>/dev/null
    
    # Wait for graceful shutdown
    local count=0
    while [[ $count -lt 10 ]] && kill -0 "$pid" 2>/dev/null; do
        sleep 1
        ((count++))
    done
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        daemon_log "WARN" "Force killing daemon process $pid"
        kill -KILL "$pid" 2>/dev/null
    fi
    
    # Clean up PID file
    rm -f "$DAEMON_PID_FILE"
    
    echo -e "${GREEN}✅ Sync daemon stopped${NC}"
}

# Restart daemon
restart_daemon() {
    stop_daemon
    sleep 2
    start_daemon
}

# Main daemon loop
run_daemon() {
    daemon_log "INFO" "Sync coordination daemon starting (PID: $$)"
    
    # Set up signal handlers for graceful shutdown
    trap 'daemon_log "INFO" "Received shutdown signal, exiting gracefully"; exit 0' SIGTERM SIGINT
    
    local last_health_check=0
    local queue_process_count=0
    
    while true; do
        local current_time=$(date +%s)
        
        # Process sync queue
        daemon_log "DEBUG" "Processing sync queue (iteration $((++queue_process_count)))"
        
        if [[ -x "$COORDINATOR_SCRIPT" ]]; then
            # Process the queue (capture output for logging)
            local process_output
            process_output=$("$COORDINATOR_SCRIPT" process 2>&1)
            local process_result=$?
            
            if [[ $process_result -eq 0 ]]; then
                # Only log if there was actual activity
                if echo "$process_output" | grep -q "Processed [1-9]"; then
                    daemon_log "SYNC" "Queue processing completed: $process_output"
                fi
            else
                daemon_log "ERROR" "Queue processing failed: $process_output"
            fi
        else
            daemon_log "ERROR" "Sync coordinator script not found or not executable"
            sleep 60  # Wait longer if coordinator is missing
            continue
        fi
        
        # Health checks (every 5 minutes)
        if [[ $((current_time - last_health_check)) -gt $HEALTH_CHECK_INTERVAL ]]; then
            daemon_log "HEALTH" "Performing health checks"
            
            # Check coordinator status
            local coordinator_status
            coordinator_status=$("$COORDINATOR_SCRIPT" status 2>&1 | tail -10)
            daemon_log "HEALTH" "Coordinator status check completed"
            
            # Check for stuck operations (older than MAX_QUEUE_AGE)
            python3 << EOF
import json
import os
from datetime import datetime, timedelta

try:
    queue_file = os.path.join("$DAEMON_DIR", "sync-queue.json")
    if os.path.exists(queue_file):
        with open(queue_file, "r") as f:
            queue_data = json.load(f)
        
        operations = queue_data.get("operations", [])
        current_time = datetime.now()
        stuck_operations = []
        
        for op in operations:
            if op.get("status") == "processing":
                op_time = datetime.fromisoformat(op["timestamp"].replace('Z', ''))
                age_seconds = (current_time - op_time).total_seconds()
                
                if age_seconds > $MAX_QUEUE_AGE:
                    stuck_operations.append(op["id"])
        
        if stuck_operations:
            print(f"WARN: Found {len(stuck_operations)} stuck operations")
            for op_id in stuck_operations[:3]:  # Log first 3
                print(f"WARN: Stuck operation: {op_id}")
        else:
            print("INFO: No stuck operations found")
            
except Exception as e:
    print(f"ERROR: Health check failed: {e}")
EOF
            
            last_health_check=$current_time
        fi
        
        # Sleep between iterations
        sleep $PROCESS_INTERVAL
    done
}

# Show daemon status
show_daemon_status() {
    echo -e "${CYAN}🔄 Sync Daemon Status${NC}"
    echo ""
    
    if is_daemon_running; then
        local pid=$(cat "$DAEMON_PID_FILE")
        echo -e "${GREEN}✅ Status: RUNNING${NC} (PID: $pid)"
        
        # Show uptime
        local start_time=$(stat -c %Y "$DAEMON_PID_FILE" 2>/dev/null || echo 0)
        local current_time=$(date +%s)
        local uptime=$((current_time - start_time))
        local uptime_str=$(date -d "@$uptime" -u +"%H:%M:%S")
        echo "   Uptime: $uptime_str"
        
        # Show memory usage
        local mem_usage=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ')
        if [[ -n "$mem_usage" ]]; then
            echo "   Memory: $((mem_usage / 1024)) MB"
        fi
    else
        echo -e "${RED}❌ Status: STOPPED${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📊 Activity Summary:${NC}"
    
    if [[ -f "$DAEMON_LOG" ]]; then
        echo "   Log file: $DAEMON_LOG"
        local log_lines=$(wc -l < "$DAEMON_LOG" 2>/dev/null || echo 0)
        echo "   Log entries: $log_lines"
        
        # Show recent activity
        echo ""
        echo "   Recent activity (last 5 entries):"
        tail -5 "$DAEMON_LOG" 2>/dev/null | while read -r line; do
            echo "     $line"
        done
    else
        echo "   No log file found"
    fi
    
    # Show coordinator status
    echo ""
    if [[ -x "$COORDINATOR_SCRIPT" ]]; then
        echo -e "${BLUE}📋 Coordinator Status:${NC}"
        "$COORDINATOR_SCRIPT" status | sed 's/^/   /'
    else
        echo -e "${RED}❌ Coordinator script not available${NC}"
    fi
}

# Show daemon logs
show_logs() {
    if [[ -f "$DAEMON_LOG" ]]; then
        if [[ "$1" == "follow" || "$1" == "-f" ]]; then
            tail -f "$DAEMON_LOG"
        else
            cat "$DAEMON_LOG"
        fi
    else
        echo "No daemon log file found"
    fi
}

# Help
show_help() {
    echo "Claude Sync Daemon - Background Sync Coordination"
    echo ""
    echo "Usage: claude-sync-daemon [command]"
    echo ""
    echo "Commands:"
    echo "  start       Start the sync daemon"
    echo "  stop        Stop the sync daemon"
    echo "  restart     Restart the sync daemon"
    echo "  status      Show daemon status"
    echo "  logs        Show daemon logs"
    echo "  logs -f     Follow daemon logs in real-time"
    echo "  run         Run daemon in foreground (internal use)"
    echo ""
    echo "The daemon automatically processes queued sync operations every $PROCESS_INTERVAL seconds"
    echo "and performs health checks every $((HEALTH_CHECK_INTERVAL / 60)) minutes."
}

# Main command handling
case "${1:-status}" in
    "start")
        start_daemon
        ;;
    "stop")
        stop_daemon
        ;;
    "restart")
        restart_daemon
        ;;
    "status")
        show_daemon_status
        ;;
    "logs")
        show_logs "$2"
        ;;
    "run")
        # Internal command - run daemon in foreground
        run_daemon
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac