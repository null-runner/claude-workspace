#!/bin/bash
# Claude Auto Memory - Sistema autonomo di salvataggio memoria
# Monitora attività e salva automaticamente senza intervento utente

WORKSPACE_DIR="$HOME/claude-workspace"
MEMORY_DIR="$WORKSPACE_DIR/.claude/memory"
AUTO_MEMORY_DIR="$WORKSPACE_DIR/.claude/auto-memory"
LOCK_FILE="$AUTO_MEMORY_DIR/auto-memory.lock"
LOG_FILE="$AUTO_MEMORY_DIR/auto-memory.log"

# Colori per log
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurazione
AUTO_SAVE_INTERVAL=300        # 5 minuti
SIGNIFICANT_CHANGES_THRESHOLD=3
MAX_AUTO_SAVES_PER_HOUR=12
MESSAGE_COUNT_THRESHOLD=5     # Auto-save ogni 5 messaggi/comandi significativi

# Setup directories
mkdir -p "$AUTO_MEMORY_DIR"
mkdir -p "$MEMORY_DIR"

# Logging function
log_auto() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Optional: echo to stdout per debug (commentare in produzione)
    # echo -e "${CYAN}[AUTO-MEMORY]${NC} $message"
}

# Controlla se il processo è già in esecuzione
check_if_running() {
    if [[ -f "$LOCK_FILE" ]]; then
        local old_pid=$(cat "$LOCK_FILE")
        if kill -0 "$old_pid" 2>/dev/null; then
            log_auto "INFO" "Auto-memory già in esecuzione (PID: $old_pid)"
            exit 0
        else
            log_auto "WARN" "Rimuovo lock file orfano (PID: $old_pid)"
            rm -f "$LOCK_FILE"
        fi
    fi
}

# Crea lock file
create_lock() {
    echo $$ > "$LOCK_FILE"
    log_auto "INFO" "Auto-memory avviato (PID: $$)"
}

# Rimuovi lock file all'exit
cleanup() {
    rm -f "$LOCK_FILE"
    log_auto "INFO" "Auto-memory terminato (PID: $$)"
}
trap cleanup EXIT

# Rileva attività significativa
detect_significant_activity() {
    python3 << 'EOF'
import subprocess
import json
import os
from datetime import datetime, timedelta
from pathlib import Path

def get_git_changes():
    """Conta modifiche git"""
    try:
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True,
                              cwd=os.environ.get('WORKSPACE_DIR'))
        if result.returncode == 0:
            lines = [line for line in result.stdout.strip().split('\n') if line]
            return len(lines)
    except:
        pass
    return 0

def check_recent_file_activity():
    """Verifica se ci sono stati file modificati di recente"""
    try:
        workspace_dir = Path(os.environ.get('WORKSPACE_DIR'))
        recent_threshold = datetime.now() - timedelta(minutes=10)
        
        recent_files = 0
        for file_path in workspace_dir.rglob('*'):
            if file_path.is_file() and not '/.git/' in str(file_path):
                try:
                    mtime = datetime.fromtimestamp(file_path.stat().st_mtime)
                    if mtime > recent_threshold:
                        recent_files += 1
                except:
                    pass
        
        return min(recent_files, 10)  # Cap a 10 per non inflazionare score
    except:
        return 0

def check_tool_usage():
    """Controlla se ci sono stati comandi/tool usage recenti"""
    try:
        # Controlla se ci sono nuovi file di log degli strumenti
        tools_dir = Path(os.environ.get('WORKSPACE_DIR')) / '.claude'
        score = 0
        
        recent_threshold = datetime.now() - timedelta(minutes=10)
        
        for log_file in tools_dir.rglob('*.log'):
            try:
                mtime = datetime.fromtimestamp(log_file.stat().st_mtime)
                if mtime > recent_threshold:
                    score += 2
            except:
                pass
        
        return min(score, 6)  # Cap a 6
    except:
        return 0

def should_auto_save():
    """Determina se dovremmo fare auto-save ora"""
    
    # Controlla ultima sessione salvata
    try:
        current_session_file = Path(os.environ.get('MEMORY_DIR')) / 'current-session-context.json'
        if current_session_file.exists():
            with open(current_session_file) as f:
                current_session = json.load(f)
            
            last_save_time = datetime.fromisoformat(
                current_session.get('timestamp', '').replace('Z', '+00:00')
            )
            time_since_save = datetime.now().replace(tzinfo=last_save_time.tzinfo) - last_save_time
            
            # Non salvare se l'ultimo save è troppo recente (< 2 minuti)
            if time_since_save < timedelta(minutes=2):
                print("SKIP:Too recent")
                return
        
    except:
        pass
    
    # Calcola activity score
    git_changes = get_git_changes()
    file_activity = check_recent_file_activity()
    tool_usage = check_tool_usage()
    
    total_score = git_changes * 2 + file_activity + tool_usage
    
    print(f"SCORE:{total_score}")
    print(f"GIT_CHANGES:{git_changes}")
    print(f"FILE_ACTIVITY:{file_activity}")
    print(f"TOOL_USAGE:{tool_usage}")
    
    # Soglie per auto-save
    threshold = int(os.environ.get('SIGNIFICANT_CHANGES_THRESHOLD', '3'))
    
    if total_score >= threshold:
        print("RECOMMENDATION:SAVE")
        print(f"REASON:Significant activity detected (score: {total_score})")
    else:
        print("RECOMMENDATION:SKIP")
        print(f"REASON:Insufficient activity (score: {total_score})")

should_auto_save()
EOF
}

# Esegui auto-save intelligente
perform_auto_save() {
    local reason="$1"
    
    log_auto "INFO" "Performing auto-save: $reason"
    
    # Genera nota automatica
    local auto_note="Auto-save: $reason"
    
    # Usa enhanced save ma in modalità silent
    if [[ -f "$WORKSPACE_DIR/scripts/claude-enhanced-save.sh" ]]; then
        # Salva in background senza output verbose
        "$WORKSPACE_DIR/scripts/claude-enhanced-save.sh" "$auto_note" >/dev/null 2>&1
        
        if [[ $? -eq 0 ]]; then
            log_auto "SUCCESS" "Auto-save completed: $auto_note"
        else
            log_auto "ERROR" "Auto-save failed"
        fi
    else
        log_auto "ERROR" "Enhanced save script not found"
    fi
}

# Controlla rate limiting per auto-save
check_rate_limit() {
    local current_hour=$(date +%Y%m%d%H)
    local rate_file="$AUTO_MEMORY_DIR/rate_limit_$current_hour"
    
    if [[ -f "$rate_file" ]]; then
        local save_count=$(cat "$rate_file")
        if [[ $save_count -ge $MAX_AUTO_SAVES_PER_HOUR ]]; then
            log_auto "WARN" "Rate limit reached for hour $current_hour ($save_count saves)"
            return 1
        fi
    fi
    
    return 0
}

# Incrementa contatore rate limit
increment_rate_limit() {
    local current_hour=$(date +%Y%m%d%H)
    local rate_file="$AUTO_MEMORY_DIR/rate_limit_$current_hour"
    
    local count=1
    if [[ -f "$rate_file" ]]; then
        count=$(($(cat "$rate_file") + 1))
    fi
    
    echo $count > "$rate_file"
    
    # Cleanup vecchi file rate limit
    find "$AUTO_MEMORY_DIR" -name "rate_limit_*" -mtime +1 -delete 2>/dev/null || true
}

# Daemon principale - monitoring loop
run_auto_memory_daemon() {
    log_auto "INFO" "Starting auto-memory daemon"
    
    local last_forced_save=$(date +%s)
    
    while true; do
        # Controlla se dovremmo uscire (file lock rimosso esternamente)
        if [[ ! -f "$LOCK_FILE" ]]; then
            log_auto "INFO" "Lock file removed, exiting daemon"
            break
        fi
        
        # Analizza attività
        local activity_output=$(detect_significant_activity)
        local recommendation=$(echo "$activity_output" | grep "^RECOMMENDATION:" | cut -d: -f2)
        local reason=$(echo "$activity_output" | grep "^REASON:" | cut -d: -f2-)
        local score=$(echo "$activity_output" | grep "^SCORE:" | cut -d: -f2)
        
        # Auto-save se attività significativa
        if [[ "$recommendation" == "SAVE" ]]; then
            if check_rate_limit; then
                perform_auto_save "$reason"
                increment_rate_limit
            fi
        fi
        
        # Forced save periodico (fallback) - ogni 30 minuti se ci sono cambiamenti
        local current_time=$(date +%s)
        local time_since_forced=$((current_time - last_forced_save))
        
        if [[ $time_since_forced -gt 1800 ]] && [[ ${score:-0} -gt 0 ]]; then
            if check_rate_limit; then
                perform_auto_save "Periodic checkpoint (${score} changes detected)"
                increment_rate_limit
                last_forced_save=$current_time
            fi
        fi
        
        # Sleep prima del prossimo check
        sleep $AUTO_SAVE_INTERVAL
    done
}

# Emergency save on signal
emergency_save() {
    log_auto "EMERGENCY" "Emergency save triggered"
    perform_auto_save "Emergency save before exit"
    exit 0
}

# Setup signal handlers per emergency save
trap emergency_save SIGTERM SIGINT

# Comandi
case "${1:-daemon}" in
    "daemon")
        check_if_running
        create_lock
        run_auto_memory_daemon
        ;;
    "start")
        if [[ -f "$LOCK_FILE" ]]; then
            echo "Auto-memory già in esecuzione"
            exit 1
        fi
        
        # Avvia daemon in background
        nohup "$0" daemon > /dev/null 2>&1 &
        echo "Auto-memory daemon avviato in background"
        ;;
    "stop")
        if [[ -f "$LOCK_FILE" ]]; then
            local pid=$(cat "$LOCK_FILE")
            if kill "$pid" 2>/dev/null; then
                echo "Auto-memory daemon fermato"
            else
                echo "Processo non trovato, rimuovo lock file"
                rm -f "$LOCK_FILE"
            fi
        else
            echo "Auto-memory daemon non in esecuzione"
        fi
        ;;
    "status")
        if [[ -f "$LOCK_FILE" ]]; then
            local pid=$(cat "$LOCK_FILE")
            if kill -0 "$pid" 2>/dev/null; then
                echo "Auto-memory daemon RUNNING (PID: $pid)"
                echo "Log file: $LOG_FILE"
                
                # Mostra ultime righe di log
                if [[ -f "$LOG_FILE" ]]; then
                    echo ""
                    echo "Ultime attività:"
                    tail -5 "$LOG_FILE" | while read line; do
                        echo "  $line"
                    done
                fi
            else
                echo "Auto-memory daemon STOPPED (stale lock)"
                rm -f "$LOCK_FILE"
            fi
        else
            echo "Auto-memory daemon NOT RUNNING"
        fi
        ;;
    "test")
        echo "Testing activity detection..."
        detect_significant_activity
        ;;
    "force-save")
        perform_auto_save "Manual force save"
        ;;
    "logs")
        if [[ -f "$LOG_FILE" ]]; then
            tail -f "$LOG_FILE"
        else
            echo "No log file found"
        fi
        ;;
    "help")
        echo "Claude Auto Memory - Sistema autonomo salvataggio"
        echo ""
        echo "Uso: claude-auto-memory [comando]"
        echo ""
        echo "Comandi:"
        echo "  start       Avvia daemon in background"
        echo "  stop        Ferma daemon"
        echo "  status      Mostra stato daemon"
        echo "  test        Testa detection attività"
        echo "  force-save  Forza salvataggio immediato"
        echo "  logs        Mostra log in tempo reale"
        echo "  daemon      Esegui daemon (uso interno)"
        echo ""
        echo "Il daemon monitora automaticamente:"
        echo "- Modifiche file git"
        echo "- Attività tool usage"
        echo "- File modificati di recente"
        echo ""
        echo "Auto-salva quando rileva attività significativa"
        echo "senza richiedere intervento manuale."
        ;;
    *)
        echo "Comando sconosciuto: $1"
        echo "Usa 'claude-auto-memory help' per vedere i comandi disponibili"
        exit 1
        ;;
esac