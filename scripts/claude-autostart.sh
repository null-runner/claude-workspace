#!/bin/bash
# Claude Workspace - Auto-start Service
# Avvia automaticamente auto-sync quando WSL si apre

WORKSPACE_DIR="$HOME/claude-workspace"
SCRIPTS_DIR="$WORKSPACE_DIR/scripts"
LOG_FILE="$WORKSPACE_DIR/logs/autostart.log"
PID_FILE="$HOME/.claude-access/auto-sync.pid"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Crea log directory
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$HOME/.claude-access"

log_message() {
    echo "[$(date)] $1" >> "$LOG_FILE"
    echo -e "$1"
}

# Verifica se Claude è attivo
check_claude_active() {
    if [[ ! -f ~/.claude-access/ACTIVE ]]; then
        log_message "${YELLOW}⚠️  Claude non attivo. Usa 'claude-enable' per attivare${NC}"
        return 1
    fi
    return 0
}

# Verifica se auto-sync è già in esecuzione
check_auto_sync_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            log_message "${GREEN}✅ Auto-sync già in esecuzione (PID: $pid)${NC}"
            return 0
        else
            # PID file esiste ma processo morto, pulisci
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Avvia auto-sync in background
start_auto_sync() {
    log_message "${BLUE}🚀 Avvio auto-sync in background...${NC}"
    
    # Avvia auto-sync e salva PID
    nohup "$SCRIPTS_DIR/auto-sync.sh" > "$LOG_FILE.sync" 2>&1 &
    local sync_pid=$!
    
    echo $sync_pid > "$PID_FILE"
    log_message "${GREEN}✅ Auto-sync avviato (PID: $sync_pid)${NC}"
    
    # Verifica che si sia avviato correttamente
    sleep 2
    if ps -p $sync_pid > /dev/null 2>&1; then
        log_message "${GREEN}✅ Auto-sync confermato attivo${NC}"
        return 0
    else
        log_message "${RED}❌ Errore nell'avvio auto-sync${NC}"
        rm -f "$PID_FILE"
        return 1
    fi
}

# Ferma auto-sync
stop_auto_sync() {
    if [[ -f "$PID_FILE" ]]; then
        local pid=$(cat "$PID_FILE")
        if ps -p $pid > /dev/null 2>&1; then
            log_message "${YELLOW}🛑 Fermando auto-sync (PID: $pid)...${NC}"
            kill $pid
            sleep 2
            
            # Forza kill se necessario
            if ps -p $pid > /dev/null 2>&1; then
                kill -9 $pid
                log_message "${YELLOW}⚡ Auto-sync forzatamente terminato${NC}"
            else
                log_message "${GREEN}✅ Auto-sync fermato correttamente${NC}"
            fi
        fi
        rm -f "$PID_FILE"
    else
        log_message "${YELLOW}⚠️  Auto-sync non in esecuzione${NC}"
    fi
}

# Stato auto-sync
status_auto_sync() {
    echo -e "${BLUE}📊 STATO AUTO-SYNC${NC}"
    echo "=================="
    
    if check_claude_active; then
        echo -e "${GREEN}✅ Claude attivo${NC}"
    else
        echo -e "${RED}❌ Claude non attivo${NC}"
    fi
    
    if check_auto_sync_running; then
        local pid=$(cat "$PID_FILE")
        echo -e "${GREEN}✅ Auto-sync attivo (PID: $pid)${NC}"
        
        # Mostra ultimi log
        echo ""
        echo "📝 Ultimi eventi sync:"
        tail -5 "$WORKSPACE_DIR/logs/sync.log" 2>/dev/null || echo "Nessun log disponibile"
    else
        echo -e "${RED}❌ Auto-sync non attivo${NC}"
    fi
    
    echo ""
    echo "📁 File di controllo:"
    echo "   Claude active: $([ -f ~/.claude-access/ACTIVE ] && echo "✅" || echo "❌")"
    echo "   PID file: $([ -f "$PID_FILE" ] && echo "✅ ($(cat "$PID_FILE"))" || echo "❌")"
    echo "   Log file: $LOG_FILE"
}

# Main script
case "$1" in
    "start")
        if check_claude_active; then
            if ! check_auto_sync_running; then
                start_auto_sync
            fi
        fi
        ;;
    "stop")
        stop_auto_sync
        ;;
    "restart")
        stop_auto_sync
        sleep 1
        if check_claude_active; then
            start_auto_sync
        fi
        ;;
    "status")
        status_auto_sync
        ;;
    "auto")
        # Modalità automatica per .bashrc
        if check_claude_active; then
            if ! check_auto_sync_running; then
                log_message "${BLUE}🔄 Auto-start: avvio auto-sync...${NC}"
                start_auto_sync
            fi
        fi
        ;;
    "--help"|"-h")
        echo "Uso: claude-autostart [comando]"
        echo ""
        echo "Comandi:"
        echo "  start     Avvia auto-sync"
        echo "  stop      Ferma auto-sync"
        echo "  restart   Riavvia auto-sync"
        echo "  status    Mostra stato"
        echo "  auto      Modalità automatica (per .bashrc)"
        echo ""
        echo "Auto-start gestisce automaticamente l'avvio di auto-sync"
        echo "quando WSL viene aperto, se Claude è attivo."
        ;;
    *)
        echo "🔄 Claude Auto-start - Help disponibile con --help"
        echo ""
        echo "Comandi rapidi:"
        echo "  claude-autostart start    # Avvia auto-sync"
        echo "  claude-autostart status   # Controlla stato"
        ;;
esac