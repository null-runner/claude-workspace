#!/bin/bash
# Claude Simple Startup - Avvia solo i 3 daemon essenziali
# Fast boot: target < 2 secondi

set -euo pipefail

# Environment
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
LOGS_DIR="$WORKSPACE_DIR/.claude/logs"
PIDS_DIR="$WORKSPACE_DIR/.claude/pids"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure dirs exist
mkdir -p "$LOGS_DIR" "$PIDS_DIR"

# Helper: check if daemon is running
is_daemon_running() {
    local daemon_name="$1"
    local pid_file="$PIDS_DIR/${daemon_name}.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file" 2>/dev/null)
        if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi
    return 1
}

# Helper: start daemon
start_daemon() {
    local daemon_name="$1"
    local script_path="$2"
    
    # Check if already running
    if is_daemon_running "$daemon_name"; then
        echo -e "  ${GREEN}✓${NC} $daemon_name already running"
        return 0
    fi
    
    # Check script exists
    if [[ ! -f "$script_path" ]]; then
        echo -e "  ${RED}✗${NC} $daemon_name script not found: $script_path"
        return 1
    fi
    
    # Start daemon
    echo -en "  Starting $daemon_name..."
    if "$script_path" start >/dev/null 2>&1; then
        # Quick verification (0.5s max)
        local retries=5
        while ((retries > 0)); do
            if is_daemon_running "$daemon_name"; then
                echo -e "\r  ${GREEN}✓${NC} $daemon_name started"
                return 0
            fi
            sleep 0.1
            ((retries--))
        done
    fi
    
    echo -e "\r  ${RED}✗${NC} $daemon_name failed to start"
    return 1
}

# Main startup
main() {
    local start_time=$(date +%s.%N)
    
    echo -e "${BLUE}Claude Simple Startup${NC}"
    echo ""
    
    local failed=0
    
    # Start daemons in parallel with subshells
    (
        start_daemon "claude-auto-context" "$WORKSPACE_DIR/scripts/claude-auto-context.sh" || exit 1
    ) &
    local pid1=$!
    
    (
        start_daemon "claude-intelligence-daemon" "$WORKSPACE_DIR/scripts/claude-intelligence-daemon.sh" || exit 1
    ) &
    local pid2=$!
    
    (
        start_daemon "claude-sync-daemon" "$WORKSPACE_DIR/scripts/claude-sync-daemon.sh" || exit 1
    ) &
    local pid3=$!
    
    # Wait for all to complete
    wait $pid1 || ((failed++))
    wait $pid2 || ((failed++))
    wait $pid3 || ((failed++))
    
    # Calculate startup time
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    local duration_fmt=$(printf "%.2f" "$duration")
    
    echo ""
    
    # Summary
    if [[ $failed -eq 0 ]]; then
        echo -e "${GREEN}✓ All daemons started${NC} (${duration_fmt}s)"
    else
        echo -e "${YELLOW}⚠ Started with $failed failures${NC} (${duration_fmt}s)"
        echo -e "${YELLOW}  Run 'claude-startup-simple.sh status' for details${NC}"
    fi
    
    # Quick tip
    echo ""
    echo -e "${BLUE}Tips:${NC}"
    echo "  • Use 'cexit' for graceful exit"
    echo "  • Run './scripts/claude-simplified-memory.sh load' to restore context"
}

# Status command
show_status() {
    echo -e "${BLUE}Daemon Status:${NC}"
    echo ""
    
    local daemons=(
        "claude-auto-context:Unified context + project monitoring"
        "claude-intelligence-daemon:Background learning"
        "claude-sync-daemon:Periodic smart sync"
    )
    
    for daemon_info in "${daemons[@]}"; do
        local daemon_name="${daemon_info%%:*}"
        local daemon_desc="${daemon_info#*:}"
        
        if is_daemon_running "$daemon_name"; then
            local pid=$(cat "$PIDS_DIR/${daemon_name}.pid" 2>/dev/null)
            echo -e "  ${GREEN}✓${NC} $daemon_name (PID: $pid)"
            echo -e "    $daemon_desc"
        else
            echo -e "  ${RED}✗${NC} $daemon_name"
            echo -e "    $daemon_desc"
        fi
    done
}

# Stop all daemons
stop_all() {
    echo -e "${BLUE}Stopping all daemons...${NC}"
    
    local scripts=(
        "$WORKSPACE_DIR/scripts/claude-auto-context.sh"
        "$WORKSPACE_DIR/scripts/claude-intelligence-daemon.sh"
        "$WORKSPACE_DIR/scripts/claude-sync-daemon.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$script" ]]; then
            "$script" stop >/dev/null 2>&1 || true
        fi
    done
    
    echo -e "${GREEN}✓ All daemons stopped${NC}"
}

# Command handling
case "${1:-start}" in
    "start"|"")
        main
        ;;
    "status")
        show_status
        ;;
    "stop")
        stop_all
        ;;
    "restart")
        stop_all
        echo ""
        main
        ;;
    "help"|"-h"|"--help")
        echo "Usage: claude-startup-simple.sh [command]"
        echo ""
        echo "Commands:"
        echo "  start    Start essential daemons (default)"
        echo "  status   Show daemon status"
        echo "  stop     Stop all daemons"
        echo "  restart  Restart all daemons"
        echo "  help     Show this help"
        echo ""
        echo "This is a simplified startup that only starts 3 essential daemons:"
        echo "  • claude-auto-context (unified context + project monitoring)"
        echo "  • claude-intelligence-daemon (background learning)"
        echo "  • claude-sync-daemon (periodic smart sync)"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use 'claude-startup-simple.sh help' for usage"
        exit 1
        ;;
esac