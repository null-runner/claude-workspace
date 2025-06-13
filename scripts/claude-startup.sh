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

# Source integrity checks
source "$WORKSPACE_DIR/scripts/state-integrity-manager.sh" 2>/dev/null || {
    echo -e "${YELLOW}Warning: state-integrity-manager.sh not available${NC}" >&2
}

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

# Integrity check - verifica consistenza file critici
integrity_check() {
    echo -e "${CYAN}🔧 Controllo integrità file critici...${NC}"
    
    # Inizializza sistema integrity se non esiste
    if command -v init_manifest >/dev/null 2>&1; then
        init_manifest >/dev/null 2>&1
    fi
    
    # Esegui controllo rapido
    if command -v run_consistency_check >/dev/null 2>&1; then
        local check_result
        if run_consistency_check true >/dev/null 2>&1; then
            echo -e "${GREEN}✅ File critici integri${NC}"
        else
            echo -e "${YELLOW}⚠️  Alcuni file corrotti - recovery automatico tentato${NC}"
            
            # Mostra log recenti per debugging
            local integrity_log="$WORKSPACE_DIR/.claude/integrity/integrity.log"
            if [[ -f "$integrity_log" ]]; then
                echo -e "${BLUE}Log recenti:${NC}"
                tail -3 "$integrity_log" | while read -r line; do
                    if [[ "$line" =~ ERROR ]]; then
                        echo -e "${RED}  $line${NC}"
                    elif [[ "$line" =~ WARN ]]; then
                        echo -e "${YELLOW}  $line${NC}"
                    else
                        echo -e "  $line"
                    fi
                done
            fi
        fi
    else
        echo -e "${YELLOW}⚠️  Sistema integrity non disponibile${NC}"
    fi
}

# Setup emergency recovery marker
setup_emergency_recovery() {
    local recovery_dir="$WORKSPACE_DIR/.claude/auto-memory"
    local exit_type_file="$recovery_dir/exit_type"
    local temp_file="$recovery_dir/exit_type.tmp.$$"
    
    mkdir -p "$recovery_dir"
    
    # Crea marker che verrà rimosso solo su exit pulito
    echo "Session started: $(date)" > "$recovery_dir/emergency_recovery_needed"
    
    # Crea marker per distinguere exit normale da crash (atomic)
    echo "normal_exit" > "$temp_file"
    mv "$temp_file" "$exit_type_file"
}

# Cleanup vecchi file temporanei
cleanup_temp_files() {
    # Cleanup vecchi lock files orfani
    find "$WORKSPACE_DIR/.claude/auto-memory" -name "*.lock" -mtime +1 -delete 2>/dev/null || true
    find "$WORKSPACE_DIR/.claude/auto-memory" -name "rate_limit_*" -mtime +1 -delete 2>/dev/null || true
}

# Installa exit hook per graceful exit automatico
install_exit_hook() {
    # Crea un wrapper script che l'utente può usare invece di exit
    local exit_wrapper="$WORKSPACE_DIR/scripts/cexit"
    
    cat > "$exit_wrapper" << 'EOF'
#!/bin/bash
# Claude Exit - Graceful exit con smart-sync automatico
# Usa questo comando invece di 'exit' per avere graceful exit automatico

WORKSPACE_DIR="$HOME/claude-workspace"

# Colori
CYAN='\033[0;36m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo -e "${CYAN}🪝 Claude Exit - avvio graceful exit...${NC}"
echo ""

# Cambia alla directory workspace se non ci siamo già
if [[ "$(pwd)" != "$WORKSPACE_DIR" ]]; then
    cd "$WORKSPACE_DIR" 2>/dev/null || {
        echo -e "${RED}❌ Errore: impossibile accedere a $WORKSPACE_DIR${NC}"
        echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
        exit "$@"
    }
fi

# Controlla se lo script smart-exit esiste
if [[ ! -f "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" ]]; then
    echo -e "${RED}❌ Smart-exit script non trovato${NC}"
    echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
    exit "$@"
fi

# Esegui smart exit con modalità automatica
echo -e "${BLUE}🚀 Executing smart exit...${NC}"
"$WORKSPACE_DIR/scripts/claude-smart-exit.sh" --auto

# Se arriviamo qui, smart-exit non ha fatto exit (errore)
echo -e "${YELLOW}⚠️  Smart exit non ha terminato - fallback a exit normale${NC}"
exit "$@"
EOF
    
    chmod +x "$exit_wrapper"
    
    # Crea anche un alias nel PATH se possibile
    local user_bin="$HOME/.local/bin"
    if [[ -d "$user_bin" ]] && [[ ":$PATH:" == *":$user_bin:"* ]]; then
        ln -sf "$exit_wrapper" "$user_bin/cexit" 2>/dev/null
    fi
    
    echo -e "${GREEN}🪝 Exit hook installato${NC}"
    echo -e "${BLUE}💡 Usa 'cexit' invece di 'exit' per graceful exit automatico${NC}"
    echo -e "${BLUE}💡 Oppure: ./scripts/cexit${NC}"
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
    
    # 2. Integrity check
    integrity_check
    
    # 3. Cleanup
    cleanup_temp_files
    
    # 4. Setup emergency recovery
    setup_emergency_recovery
    
    # 5. Migration check
    migrate_from_old_auto_memory
    
    # 6. Start autonomous system
    start_autonomous_system
    
    # 6. Install exit hook for automatic graceful exit
    install_exit_hook
    
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