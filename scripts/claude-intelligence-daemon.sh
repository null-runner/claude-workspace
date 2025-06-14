#!/bin/bash

# Claude Intelligence Daemon - Wrapper per claude-intelligence-enhanced.sh
# Gestisce l'esecuzione in background del sistema di intelligence

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_DIR="$SCRIPT_DIR/../.claude"
PID_FILE="$CLAUDE_DIR/pids/intelligence-daemon.pid"
LOG_FILE="$CLAUDE_DIR/logs/intelligence-daemon.log"
DAEMON_SCRIPT="$SCRIPT_DIR/claude-intelligence-enhanced.sh"

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
    "$DAEMON_SCRIPT" daemon status >/dev/null 2>&1
}

start_daemon() {
    if is_running; then
        log "Intelligence daemon already running"
        return 0
    fi
    
    log "Starting intelligence daemon..."
    
    # Verifica che lo script esista
    if [[ ! -x "$DAEMON_SCRIPT" ]]; then
        error "Script not found or not executable: $DAEMON_SCRIPT"
        return 1
    fi
    
    # Delega direttamente al script originale
    "$DAEMON_SCRIPT" daemon start
    
    if is_running; then
        log "Intelligence daemon started successfully"
        return 0
    else
        error "Failed to start intelligence daemon"
        return 1
    fi
}

stop_daemon() {
    if ! is_running; then
        log "Intelligence daemon not running"
        return 0
    fi
    
    log "Stopping intelligence daemon..."
    
    # Delega direttamente al script originale
    "$DAEMON_SCRIPT" daemon stop
    
    log "Intelligence daemon stopped"
}

restart_daemon() {
    log "Restarting intelligence daemon..."
    stop_daemon
    sleep 1
    start_daemon
}

status_daemon() {
    # Delega direttamente al script originale
    "$DAEMON_SCRIPT" daemon status
}

show_logs() {
    if [[ -f "$LOG_FILE" ]]; then
        tail -n "${1:-20}" "$LOG_FILE"
    else
        echo "No log file found"
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
    *)
        echo "Usage: $0 {start|stop|restart|status|logs [lines]}"
        echo ""
        echo "Commands:"
        echo "  start   - Start intelligence daemon"
        echo "  stop    - Stop intelligence daemon"
        echo "  restart - Restart intelligence daemon"
        echo "  status  - Show daemon status"
        echo "  logs    - Show daemon logs (default: 20 lines)"
        exit 1
        ;;
esac