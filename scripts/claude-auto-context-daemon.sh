#!/bin/bash

# Claude Auto Context Daemon - Wrapper per claude-auto-context.sh
# Gestisce l'esecuzione in background del sistema di auto-context

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$SCRIPT_DIR/../.claude"
PID_FILE="$CLAUDE_DIR/pids/auto-context-daemon.pid"
LOG_FILE="$CLAUDE_DIR/logs/auto-context-daemon.log"
DAEMON_SCRIPT="$SCRIPT_DIR/claude-auto-context.sh"

# Crea directory se non esistono
mkdir -p "$(dirname "$PID_FILE")" "$(dirname "$LOG_FILE")"

# Funzioni utility
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

error() {
    log "ERROR: $*" >&2
}

is_running() {
    # Delega al script originale per il check dello stato
    "$DAEMON_SCRIPT" status >/dev/null 2>&1
}

start_daemon() {
    if is_running; then
        log "Auto-context daemon already running"
        return 0
    fi
    
    log "Starting auto-context daemon..."
    
    # Verifica che lo script esista
    if [[ ! -f "$DAEMON_SCRIPT" ]]; then
        error "Script not found: $DAEMON_SCRIPT"
        return 1
    fi
    
    # Rendi eseguibile se necessario
    chmod +x "$DAEMON_SCRIPT"
    
    # Delega direttamente al script originale
    "$DAEMON_SCRIPT" start
    
    if is_running; then
        log "Auto-context daemon started successfully"
        return 0
    else
        error "Failed to start auto-context daemon"
        return 1
    fi
}

stop_daemon() {
    if ! is_running; then
        log "Auto-context daemon not running"
        return 0
    fi
    
    log "Stopping auto-context daemon..."
    
    # Delega direttamente al script originale
    "$DAEMON_SCRIPT" stop
    
    log "Auto-context daemon stopped"
}

restart_daemon() {
    log "Restarting auto-context daemon..."
    stop_daemon
    sleep 1
    start_daemon
}

status_daemon() {
    # Delega direttamente al script originale
    "$DAEMON_SCRIPT" status
}

show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -n "${1:-20}" "$LOG_FILE"
    else
        echo "No log file found"
    fi
}

# Trigger manuale per update immediato
trigger_update() {
    log "Triggering manual auto-context update..."
    if [[ -x "$DAEMON_SCRIPT" ]]; then
        "$DAEMON_SCRIPT" auto-update
        log "Manual update completed"
    else
        error "Auto-context script not found or not executable"
        return 1
    fi
}

# Comando principale
case "${1:-status}" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        restart_daemon
        ;;
    status)
        status_daemon
        ;;
    logs)
        show_logs "${2:-20}"
        ;;
    update)
        trigger_update
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [lines]|update}"
        echo ""
        echo "Commands:"
        echo "  start   - Start auto-context daemon"
        echo "  stop    - Stop auto-context daemon"
        echo "  restart - Restart auto-context daemon"
        echo "  status  - Show daemon status"
        echo "  logs    - Show daemon logs (default: 20 lines)"
        echo "  update  - Trigger manual context update"
        exit 1
        ;;
esac