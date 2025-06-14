#!/bin/bash

# =============================================================================
# Claude Workspace - Enhanced Graceful Exit
# =============================================================================
# Smart exit that saves context and shuts down gracefully
# No coordinator overhead, just essential cleanup
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(dirname "$SCRIPT_DIR")"
CLAUDE_DIR="$BASE_DIR/.claude"
LOG_FILE="$CLAUDE_DIR/logs/cexit.log"

# Create directories
mkdir -p "$CLAUDE_DIR/logs" "$CLAUDE_DIR/auto-memory"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Save context before exit
save_context() {
    log "💾 Saving context..."
    
    # Use simplified memory system
    if [[ -f "$SCRIPT_DIR/claude-simplified-memory.sh" ]]; then
        "$SCRIPT_DIR/claude-simplified-memory.sh" save &>/dev/null || {
            log "⚠️  Context save had issues (may be normal)"
        }
    fi
    
    # Mark clean exit
    echo "clean_exit:$(date '+%Y-%m-%d %H:%M:%S')" > "$CLAUDE_DIR/auto-memory/exit_type"
    
    log "✓ Context saved"
}

# Stop daemon
stop_daemon() {
    local daemon_name="$1"
    local pid_file="$CLAUDE_DIR/pids/${daemon_name}.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log "🛑 Stopping $daemon_name (PID: $pid)..."
            kill -TERM "$pid" 2>/dev/null || true
            
            # Wait for graceful shutdown
            for i in {1..5}; do
                if ! kill -0 "$pid" 2>/dev/null; then
                    log "✓ $daemon_name stopped gracefully"
                    rm -f "$pid_file"
                    return 0
                fi
                sleep 1
            done
            
            # Force kill if needed
            kill -KILL "$pid" 2>/dev/null || true
            log "⚠️  $daemon_name force-killed"
        fi
        rm -f "$pid_file"
    else
        log "ℹ️  $daemon_name not running"
    fi
}

# Graceful shutdown
graceful_shutdown() {
    log "🌙 Starting graceful shutdown..."
    
    # Save context first
    save_context
    
    # Stop essential daemons
    local -a DAEMONS=(
        "sync"
        "intelligence" 
        "memory"
    )
    
    for daemon in "${DAEMONS[@]}"; do
        stop_daemon "$daemon"
    done
    
    # Final cleanup
    log "🧹 Final cleanup..."
    
    # Remove stale files
    find "$CLAUDE_DIR/pids" -name "*.pid" -delete 2>/dev/null || true
    
    # Quick status
    local running_processes=$(pgrep -f "claude-" | wc -l)
    if [[ $running_processes -gt 0 ]]; then
        log "⚠️  $running_processes Claude processes still running"
    else
        log "✓ All Claude processes stopped"
    fi
    
    log "🎯 Graceful shutdown completed"
}

# Force shutdown (for script shutdown mode)
force_shutdown() {
    log "⚡ Force shutdown requested"
    
    # Kill all Claude processes
    pkill -f "claude-" 2>/dev/null || true
    
    # Clean PID files
    rm -rf "$CLAUDE_DIR/pids"/*.pid 2>/dev/null || true
    
    log "🔥 Force shutdown completed"
}

# Main function
main() {
    local mode="${1:-graceful}"
    
    case "$mode" in
        "graceful"|"")
            graceful_shutdown
            ;;
        "shutdown")
            force_shutdown
            ;;
        "save-only")
            save_context
            ;;
        *)
            echo "Usage: $0 {graceful|shutdown|save-only}"
            exit 1
            ;;
    esac
}

# Handle arguments
main "$@"

# If we're in interactive mode, offer to exit Claude Code
if [[ -t 0 ]] && [[ "${1:-}" != "shutdown" ]]; then
    echo
    echo "🤖 Graceful shutdown completed."
    echo "💡 You can now safely close Claude Code or continue working."
    echo
    read -p "Exit Claude Code now? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "🚪 User requested Claude Code exit"
        exit 0
    else
        log "📝 User chose to continue session"
    fi
fi