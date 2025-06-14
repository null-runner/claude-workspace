#!/bin/bash

# =============================================================================
# Claude Workspace - Simplified Startup
# =============================================================================
# Fast, reliable startup with only 3 essential daemons
# No enterprise theater, no complex orchestration
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$BASE_DIR/.claude"
LOG_FILE="$CLAUDE_DIR/logs/startup-simple.log"

# Create directories
mkdir -p "$CLAUDE_DIR/logs" "$CLAUDE_DIR/auto-memory" "$CLAUDE_DIR/pids"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if daemon is running
is_daemon_running() {
    local daemon_name="$1"
    local pid_file="$CLAUDE_DIR/pids/${daemon_name}.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$pid_file"
        fi
    fi
    
    return 1
}

# Start daemon
start_daemon() {
    local daemon_name="$1"
    local daemon_script="$2"
    
    if is_daemon_running "$daemon_name"; then
        log "✓ $daemon_name already running"
        return 0
    fi
    
    log "🚀 Starting $daemon_name..."
    
    if [[ -f "$daemon_script" ]]; then
        "$daemon_script" start &
        local pid=$!
        echo "$pid" > "$CLAUDE_DIR/pids/${daemon_name}.pid"
        
        # Quick health check
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then
            log "✓ $daemon_name started successfully (PID: $pid)"
        else
            log "❌ $daemon_name failed to start"
            rm -f "$CLAUDE_DIR/pids/${daemon_name}.pid"
            return 1
        fi
    else
        log "⚠️  $daemon_script not found, skipping $daemon_name"
    fi
}

# Main startup function
main() {
    log "🌟 Claude Workspace Simple Startup"
    log "========================================"
    
    # Essential daemons only
    local -a ESSENTIAL_DAEMONS=(
        "memory:$SCRIPT_DIR/claude-simplified-memory.sh"
        "intelligence:$SCRIPT_DIR/claude-intelligence-extractor.sh" 
        "sync:$SCRIPT_DIR/claude-smart-sync.sh"
    )
    
    local failed_count=0
    
    for daemon_spec in "${ESSENTIAL_DAEMONS[@]}"; do
        IFS=':' read -r daemon_name daemon_script <<< "$daemon_spec"
        
        if ! start_daemon "$daemon_name" "$daemon_script"; then
            ((failed_count++))
        fi
    done
    
    # Summary
    log "========================================"
    if [[ $failed_count -eq 0 ]]; then
        log "🎉 All essential daemons started successfully"
        log "💡 Use 'cexit' for graceful shutdown"
    else
        log "⚠️  $failed_count daemons failed to start"
        log "🔧 Check logs for details"
    fi
    
    # Show status
    "$SCRIPT_DIR/claude-health-basic.sh" status 2>/dev/null || true
}

# Handle script arguments
case "${1:-start}" in
    "start")
        main
        ;;
    "status")
        "$SCRIPT_DIR/claude-health-basic.sh" status
        ;;
    "stop")
        "$SCRIPT_DIR/cexit-enhanced.sh" shutdown
        ;;
    *)
        echo "Usage: $0 {start|status|stop}"
        exit 1
        ;;
esac