#!/bin/bash
# Claude Startup - Auto-avvio servizi essenziali
# Questo script viene chiamato automaticamente all'inizio di ogni sessione Claude

WORKSPACE_DIR="$HOME/claude-workspace"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Avvia sistema autonomo se non è già in esecuzione
start_autonomous_system() {
    if [[ -f "$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" ]]; then
        # Controlla se è già in esecuzione
        local status_output=$("$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" status 2>/dev/null)
        
        if echo "$status_output" | grep -q "RUNNING"; then
            echo -e "${GREEN}🤖 Autonomous system: già attivo${NC}"
        else
            echo -e "${YELLOW}🤖 Avvio autonomous system...${NC}"
            "$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" start
            
            # Verifica che sia partito
            sleep 2
            local verify_output=$("$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" status 2>/dev/null)
            if echo "$verify_output" | grep -q "RUNNING"; then
                echo -e "${GREEN}✅ Autonomous system avviato${NC}"
            else
                echo -e "${RED}❌ Errore avvio autonomous system${NC}"
            fi
        fi
    else
        echo -e "${RED}❌ Autonomous system script non trovato${NC}"
    fi
}

# Migrazione da vecchio sistema auto-memory
migrate_from_old_auto_memory() {
    # Ferma vecchio auto-memory se presente
    if [[ -f "$WORKSPACE_DIR/scripts/claude-auto-memory.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-auto-memory.sh" stop >/dev/null 2>&1
    fi
    
    # Migra enhanced sessions to simplified format
    if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" migrate >/dev/null 2>&1
    fi
}

# Recovery check - verifica se ci sono stati crash
recovery_check() {
    local crash_indicator="$WORKSPACE_DIR/.claude/auto-memory/emergency_recovery_needed"
    local exit_type_file="$WORKSPACE_DIR/.claude/auto-memory/exit_type"
    
    if [[ -f "$crash_indicator" ]]; then
        # Controlla se è stato un exit normale o un crash
        local exit_type=""
        if [[ -f "$exit_type_file" ]]; then
            exit_type=$(cat "$exit_type_file" 2>/dev/null)
        fi
        
        if [[ "$exit_type" == "graceful_exit" ]]; then
            # Exit normale - pulizia semplice
            echo -e "${GREEN}✅ Sessione precedente chiusa correttamente${NC}"
            rm -f "$crash_indicator" "$exit_type_file"
        elif [[ "$exit_type" == "normal_exit" ]]; then
            # Exit normale (comando exit diretto) - non è un crash
            echo -e "${GREEN}✅ Sessione precedente chiusa normalmente${NC}"
            rm -f "$crash_indicator" "$exit_type_file"
        else
            # Crash reale - recovery necessario
            echo -e "${YELLOW}🚨 Recovery necessario: rilevato crash sessione precedente${NC}"
            
            # Tenta recovery automatico
            if [[ -f "$WORKSPACE_DIR/scripts/claude-enhanced-save.sh" ]]; then
                echo -e "${CYAN}🔧 Tentativo auto-recovery...${NC}"
                "$WORKSPACE_DIR/scripts/claude-enhanced-save.sh" "Emergency recovery - restoring from crash" >/dev/null 2>&1
                
                if [[ $? -eq 0 ]]; then
                    echo -e "${GREEN}✅ Recovery completato${NC}"
                    rm -f "$crash_indicator" "$exit_type_file"
                else
                    echo -e "${RED}❌ Recovery fallito${NC}"
                fi
            fi
        fi
    fi
}

# Setup emergency recovery marker
setup_emergency_recovery() {
    local recovery_dir="$WORKSPACE_DIR/.claude/auto-memory"
    mkdir -p "$recovery_dir"
    
    # Crea marker che verrà rimosso solo su exit pulito
    echo "Session started: $(date)" > "$recovery_dir/emergency_recovery_needed"
    
    # Crea marker per distinguere exit normale da crash
    echo "normal_exit" > "$recovery_dir/exit_type"
}

# Cleanup vecchi file temporanei
cleanup_temp_files() {
    # Cleanup vecchi lock files orfani
    find "$WORKSPACE_DIR/.claude/auto-memory" -name "*.lock" -mtime +1 -delete 2>/dev/null || true
    find "$WORKSPACE_DIR/.claude/auto-memory" -name "rate_limit_*" -mtime +1 -delete 2>/dev/null || true
}

# Mostra status servizi
show_services_status() {
    echo -e "${CYAN}🔧 SERVIZI CLAUDE WORKSPACE${NC}"
    
    # Autonomous system status
    local autonomous_status="❌ Non attivo"
    if [[ -f "$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" ]]; then
        local status_output=$("$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" status 2>/dev/null)
        if echo "$status_output" | grep -q "RUNNING"; then
            autonomous_status="✅ Attivo"
        fi
    fi
    echo -e "   🤖 Autonomous system: $autonomous_status"
    
    # Git status
    cd "$WORKSPACE_DIR"
    if git status >/dev/null 2>&1; then
        echo -e "   📂 Git repository: ✅ Attivo"
    else
        echo -e "   📂 Git repository: ❌ Errore"
    fi
    
    # Memory files
    local memory_status="❌ Non trovati"
    if [[ -f "$WORKSPACE_DIR/.claude/memory/current-session-context.json" ]]; then
        memory_status="✅ Disponibili"
    fi
    echo -e "   💾 Memory files: $memory_status"
}

# Main startup routine
main_startup() {
    echo -e "${BLUE}🚀 Claude Workspace Startup${NC}"
    echo ""
    
    # 1. Recovery check
    recovery_check
    
    # 2. Cleanup
    cleanup_temp_files
    
    # 3. Setup emergency recovery
    setup_emergency_recovery
    
    # 4. Migration check
    migrate_from_old_auto_memory
    
    # 5. Start autonomous system
    start_autonomous_system
    
    echo ""
}

# Comandi
case "${1:-startup}" in
    "startup"|"")
        main_startup
        ;;
    "status")
        show_services_status
        ;;
    "restart-autonomous")
        echo "Restarting autonomous system..."
        "$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" restart
        ;;
    "stop-all")
        echo "Stopping all services..."
        "$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" stop
        ;;
    "help")
        echo "Claude Startup - Auto-avvio servizi"
        echo ""
        echo "Uso: claude-startup [comando]"
        echo ""
        echo "Comandi:"
        echo "  startup              Avvio completo (default)"
        echo "  status               Mostra stato servizi"
        echo "  restart-autonomous   Riavvia sistema autonomo"
        echo "  stop-all             Ferma tutti i servizi"
        echo ""
        ;;
    *)
        echo "Comando sconosciuto: $1"
        exit 1
        ;;
esac