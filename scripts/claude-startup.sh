#!/bin/bash
# Claude Startup - Auto-avvio servizi essenziali
# Questo script viene chiamato automaticamente all'inizio di ogni sessione Claude

set -euo pipefail  # Strict error handling

# Environment validation - auto-detect workspace
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"

# Source error handling library
if [[ -f "$WORKSPACE_DIR/scripts/error-handling-library.sh" ]]; then
    source "$WORKSPACE_DIR/scripts/error-handling-library.sh"
else
    echo "ERROR: error-handling-library.sh not found in $WORKSPACE_DIR/scripts/" >&2
    exit 3
fi

# Validate environment and dependencies
validate_environment "HOME" "WORKSPACE_DIR" || exit $?
check_dependencies "bash" "git" "python3" || exit $?
validate_directory "$WORKSPACE_DIR" "workspace directory" || exit $?

# Setup cleanup trap
cleanup_startup() {
    error_log "INFO" "Startup cleanup called"
}
setup_cleanup_trap cleanup_startup

# Colori (migrated to error-handling-library.sh)
GREEN="$SUCCESS_GREEN"
BLUE="$INFO_BLUE"  
YELLOW="$WARNING_YELLOW"
RED="$ERROR_RED"
CYAN='\033[0;36m'
# NC already defined in error-handling-library.sh

# Source integrity checks with proper error handling
if [[ -f "$WORKSPACE_DIR/scripts/state-integrity-manager.sh" ]]; then
    if ! source "$WORKSPACE_DIR/scripts/state-integrity-manager.sh" 2>/dev/null; then
        error_log "WARN" "Failed to source state-integrity-manager.sh"
    fi
else
    error_log "WARN" "state-integrity-manager.sh not available"
fi

# Avvia sistema autonomo se non è già in esecuzione
start_autonomous_system() {
    local autonomous_script="$WORKSPACE_DIR/scripts/claude-autonomous-system.sh"
    
    # Validate autonomous script exists and is executable
    if ! validate_file "$autonomous_script" "autonomous system script" true; then
        error_log "ERROR" "Autonomous system script not found or not accessible"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -x "$autonomous_script" ]]; then
        error_log "ERROR" "Autonomous system script is not executable"
        return $EXIT_PERMISSION_ERROR
    fi
    
    # Check current status with timeout
    local status_output
    if ! status_output=$(execute_with_timeout 10 "Check autonomous system status" "$autonomous_script" status 2>/dev/null); then
        error_log "WARN" "Failed to check autonomous system status"
        status_output=""
    fi
    
    if echo "$status_output" | grep -q "RUNNING"; then
        echo -e "${GREEN}🤖 Autonomous system: già attivo${NC}"
        return $EXIT_SUCCESS
    else
        echo -e "${YELLOW}🤖 Avvio autonomous system...${NC}"
        
        # Start autonomous system with timeout
        if execute_with_timeout 30 "Start autonomous system" "$autonomous_script" start; then
            error_log "SUCCESS" "Autonomous system start command completed"
            
            # Verify startup with timeout
            sleep 2
            local verify_output
            if verify_output=$(execute_with_timeout 10 "Verify autonomous system status" "$autonomous_script" status 2>/dev/null); then
                if echo "$verify_output" | grep -q "RUNNING"; then
                    echo -e "${GREEN}✅ Autonomous system avviato${NC}"
                    return $EXIT_SUCCESS
                else
                    error_log "ERROR" "Autonomous system failed to start properly"
                    echo -e "${RED}❌ Errore avvio autonomous system${NC}"
                    return $EXIT_GENERAL_ERROR
                fi
            else
                error_log "ERROR" "Failed to verify autonomous system startup"
                echo -e "${RED}❌ Errore verifica autonomous system${NC}"
                return $EXIT_GENERAL_ERROR
            fi
        else
            error_log "ERROR" "Failed to start autonomous system"
            echo -e "${RED}❌ Errore comando avvio autonomous system${NC}"
            return $EXIT_GENERAL_ERROR
        fi
    fi
}

# Migrazione da vecchio sistema auto-memory
migrate_from_old_auto_memory() {
    error_log "INFO" "Starting auto-memory migration"
    
    # Ferma vecchio auto-memory se presente
    local old_memory_script="$WORKSPACE_DIR/scripts/claude-auto-memory.sh"
    if [[ -f "$old_memory_script" ]]; then
        error_log "INFO" "Stopping old auto-memory system"
        if execute_with_timeout 15 "Stop old auto-memory" "$old_memory_script" stop; then
            error_log "SUCCESS" "Old auto-memory stopped successfully"
        else
            error_log "WARN" "Failed to stop old auto-memory (may not be running)"
        fi
    fi
    
    # Migra enhanced sessions to simplified format
    local simplified_script="$WORKSPACE_DIR/scripts/claude-simplified-memory.sh"
    if validate_file "$simplified_script" "simplified memory script" false; then
        error_log "INFO" "Running memory migration"
        if execute_with_timeout 30 "Memory migration" "$simplified_script" migrate; then
            error_log "SUCCESS" "Memory migration completed"
        else
            error_log "WARN" "Memory migration had issues (may be normal)"
        fi
    fi
    
    return $EXIT_SUCCESS
}

# Recovery check - verifica se ci sono stati crash
recovery_check() {
    local recovery_dir="$WORKSPACE_DIR/.claude/auto-memory"
    local crash_indicator="$recovery_dir/emergency_recovery_needed"
    local exit_type_file="$recovery_dir/exit_type"
    
    error_log "INFO" "Starting recovery check"
    
    # Validate recovery directory exists
    if ! validate_directory "$recovery_dir" "recovery directory" false; then
        error_log "WARN" "Recovery directory not accessible, skipping recovery check"
        return $EXIT_SUCCESS
    fi
    
    if [[ -f "$crash_indicator" ]]; then
        error_log "INFO" "Crash indicator found, analyzing exit type"
        
        # Read exit type safely
        local exit_type=""
        if validate_file "$exit_type_file" "exit type file" false; then
            exit_type=$(cat "$exit_type_file" 2>/dev/null || echo "")
        fi
        
        case "$exit_type" in
            "graceful_exit")
                echo -e "${GREEN}✅ Sessione precedente chiusa correttamente${NC}"
                rm -f "$crash_indicator" "$exit_type_file"
                error_log "SUCCESS" "Graceful exit detected, cleanup completed"
                ;;
            "normal_exit")
                echo -e "${GREEN}✅ Sessione precedente chiusa normalmente${NC}"
                rm -f "$crash_indicator" "$exit_type_file"
                error_log "SUCCESS" "Normal exit detected, cleanup completed"
                ;;
            *)
                echo -e "${YELLOW}🚨 Recovery necessario: rilevato crash sessione precedente${NC}"
                error_log "WARN" "Crash detected, attempting recovery"
                
                # Attempt auto-recovery with timeout
                local recovery_script="$WORKSPACE_DIR/scripts/claude-enhanced-save.sh"
                if validate_file "$recovery_script" "recovery script" false; then
                    echo -e "${CYAN}🔧 Tentativo auto-recovery...${NC}"
                    
                    if execute_with_timeout 60 "Emergency recovery" "$recovery_script" "Emergency recovery - restoring from crash"; then
                        echo -e "${GREEN}✅ Recovery completato${NC}"
                        rm -f "$crash_indicator" "$exit_type_file"
                        error_log "SUCCESS" "Emergency recovery completed successfully"
                    else
                        echo -e "${RED}❌ Recovery fallito${NC}"
                        error_log "ERROR" "Emergency recovery failed"
                        return $EXIT_GENERAL_ERROR
                    fi
                else
                    error_log "ERROR" "Recovery script not found, cannot perform auto-recovery"
                    echo -e "${RED}❌ Script di recovery non trovato${NC}"
                    return $EXIT_VALIDATION_ERROR
                fi
                ;;
        esac
    else
        error_log "INFO" "No crash indicator found, session start is clean"
    fi
    
    return $EXIT_SUCCESS
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
    local crash_indicator="$recovery_dir/emergency_recovery_needed"
    
    error_log "INFO" "Setting up emergency recovery markers"
    
    # Create recovery directory with proper error handling
    if ! mkdir -p "$recovery_dir"; then
        error_log "ERROR" "Failed to create recovery directory: $recovery_dir"
        return $EXIT_PERMISSION_ERROR
    fi
    
    # Validate directory is writable
    if ! validate_directory "$recovery_dir" "recovery directory"; then
        return $?
    fi
    
    # Create crash indicator with session info
    local session_info="Session started: $(date) (PID: $$, User: $(whoami), Host: $(hostname))"
    if ! atomic_write_with_validation "$crash_indicator" "$session_info"; then
        error_log "ERROR" "Failed to create crash indicator"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Create exit type marker atomically
    if ! atomic_write_with_validation "$exit_type_file" "normal_exit"; then
        error_log "ERROR" "Failed to create exit type marker"
        return $EXIT_GENERAL_ERROR
    fi
    
    error_log "SUCCESS" "Emergency recovery markers created successfully"
    return $EXIT_SUCCESS
}

# Cleanup vecchi file temporanei
cleanup_temp_files() {
    # Cleanup vecchi lock files orfani
    find "$WORKSPACE_DIR/.claude/auto-memory" -name "*.lock" -mtime +1 -delete 2>/dev/null || true
    find "$WORKSPACE_DIR/.claude/auto-memory" -name "rate_limit_*" -mtime +1 -delete 2>/dev/null || true
}

# Crea cexit wrapper per graceful exit manuale (exit hook automatico disabilitato)
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
    
    local startup_errors=0
    
    # 1. Recovery check
    error_log "INFO" "Step 1: Recovery check"
    if ! recovery_check; then
        error_log "ERROR" "Recovery check failed"
        ((startup_errors++))
    fi
    
    # 2. Integrity check  
    error_log "INFO" "Step 2: Integrity check"
    if ! integrity_check; then
        error_log "ERROR" "Integrity check failed"
        ((startup_errors++))
    fi
    
    # 3. Cleanup
    error_log "INFO" "Step 3: Cleanup temporary files"
    if ! cleanup_temp_files; then
        error_log "WARN" "Cleanup had issues (non-critical)"
    fi
    
    # 4. Setup emergency recovery
    error_log "INFO" "Step 4: Setup emergency recovery"
    if ! setup_emergency_recovery; then
        error_log "ERROR" "Emergency recovery setup failed"
        ((startup_errors++))
    fi
    
    # 5. Migration check
    error_log "INFO" "Step 5: Auto-memory migration"
    if ! migrate_from_old_auto_memory; then
        error_log "WARN" "Migration had issues (may be normal)"
    fi
    
    # 6. Start autonomous system
    error_log "INFO" "Step 6: Start autonomous system"
    if ! start_autonomous_system; then
        error_log "ERROR" "Autonomous system startup failed"
        ((startup_errors++))
    fi
    
    # 7. Exit hook installation DISABLED (use cexit manually instead)
    error_log "INFO" "Step 7: Exit hook disabled (use cexit for graceful exit)"
    
    echo ""
    
    # Step 8: Load TODO.md into memory for Claude session
    echo -e "${BLUE}📥 Step 8: Loading TODO persistence for Claude${NC}"
    if [[ -f "$WORKSPACE_DIR/scripts/sync-todo-workspace.sh" ]]; then
        error_log "INFO" "Loading TODO.md for Claude session persistence"
        "$WORKSPACE_DIR/scripts/sync-todo-workspace.sh" load
    else
        error_log "WARN" "TODO sync script not found - Claude TODO persistence disabled"
    fi
    echo ""
    
    # Report startup status
    if [[ $startup_errors -eq 0 ]]; then
        error_log "SUCCESS" "Claude Workspace startup completed successfully"
        return $EXIT_SUCCESS
    elif [[ $startup_errors -le 2 ]]; then
        error_log "WARN" "Claude Workspace startup completed with $startup_errors non-critical errors"
        return $EXIT_SUCCESS
    else
        error_log "ERROR" "Claude Workspace startup failed with $startup_errors critical errors"
        return $EXIT_GENERAL_ERROR
    fi
}

# Command handling with proper error codes and validation
case "${1:-startup}" in
    "startup"|"")
        if main_startup; then
            error_log "SUCCESS" "Claude startup completed successfully"
            exit $EXIT_SUCCESS
        else
            error_log "ERROR" "Claude startup failed"
            exit $EXIT_GENERAL_ERROR
        fi
        ;;
    "status")
        if show_services_status; then
            exit $EXIT_SUCCESS
        else
            error_log "ERROR" "Failed to show services status"
            exit $EXIT_GENERAL_ERROR
        fi
        ;;
    "restart-autonomous")
        autonomous_script="$WORKSPACE_DIR/scripts/claude-autonomous-system.sh"
        if ! validate_file "$autonomous_script" "autonomous system script" true; then
            error_log "ERROR" "Autonomous system script not found"
            exit $EXIT_VALIDATION_ERROR
        fi
        
        echo "Restarting autonomous system..."
        if execute_with_timeout 60 "Restart autonomous system" "$autonomous_script" restart; then
            error_log "SUCCESS" "Autonomous system restarted"
            exit $EXIT_SUCCESS
        else
            error_log "ERROR" "Failed to restart autonomous system"
            exit $EXIT_GENERAL_ERROR
        fi
        ;;
    "stop-all")
        autonomous_script="$WORKSPACE_DIR/scripts/claude-autonomous-system.sh"
        if ! validate_file "$autonomous_script" "autonomous system script" true; then
            error_log "ERROR" "Autonomous system script not found"
            exit $EXIT_VALIDATION_ERROR
        fi
        
        echo "Stopping all services..."
        if execute_with_timeout 60 "Stop all services" "$autonomous_script" stop; then
            error_log "SUCCESS" "All services stopped"
            exit $EXIT_SUCCESS
        else
            error_log "ERROR" "Failed to stop all services"
            exit $EXIT_GENERAL_ERROR
        fi
        ;;
    "test")
        echo "Testing error handling library..."
        if command -v test_error_handling >/dev/null 2>&1; then
            test_error_handling
            exit $EXIT_SUCCESS
        else
            error_log "ERROR" "Error handling library test function not available"
            exit $EXIT_VALIDATION_ERROR
        fi
        ;;
    "help"|"--help"|"-h")
        print_usage "claude-startup.sh" "Auto-avvio servizi essenziali" "[command]" \
            "startup              Avvio completo (default)" \
            "status               Mostra stato servizi" \
            "restart-autonomous   Riavvia sistema autonomo" \
            "stop-all             Ferma tutti i servizi" \
            "test                 Test error handling library" \
            "help                 Mostra questo messaggio"
        exit $EXIT_SUCCESS
        ;;
    *)
        error_log "ERROR" "Unknown command: $1"
        echo "Use 'claude-startup.sh help' for usage information" >&2
        exit $EXIT_INVALID_USAGE
        ;;
esac