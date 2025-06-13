#!/bin/bash
# Claude Exit Hook - Intercetta comando exit per graceful exit automatico
# Questo hook viene attivato automaticamente quando usi "exit"
# Version 3.0 - Enhanced safety and Claude Code detection

WORKSPACE_DIR="$HOME/claude-workspace"
HOOK_LOG_FILE="$WORKSPACE_DIR/.claude/logs/exit-hook.log"
HOOK_TIMEOUT=30  # Timeout in seconds
HOOK_MAX_RETRIES=3

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Initialize logging
init_hook_logging() {
    mkdir -p "$(dirname "$HOOK_LOG_FILE")"
    if [[ ! -f "$HOOK_LOG_FILE" ]]; then
        touch "$HOOK_LOG_FILE"
    fi
    # Rotate log if too large (>1MB)
    if [[ -f "$HOOK_LOG_FILE" ]] && [[ $(stat -f%z "$HOOK_LOG_FILE" 2>/dev/null || stat -c%s "$HOOK_LOG_FILE" 2>/dev/null || echo 0) -gt 1048576 ]]; then
        mv "$HOOK_LOG_FILE" "${HOOK_LOG_FILE}.old"
        touch "$HOOK_LOG_FILE"
    fi
}

# Enhanced logging function
log_hook_event() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$HOOK_LOG_FILE" 2>/dev/null || true
    
    # Also echo to stderr for debugging (only if verbose)
    if [[ "${CLAUDE_EXIT_HOOK_DEBUG:-}" == "1" ]]; then
        echo "[EXIT-HOOK] [$level] $message" >&2
    fi
}

# Detect if we're running inside Claude Code
is_running_in_claude_code() {
    # Method 1: Check parent process chain for Claude
    local current_pid=$$
    local max_depth=10
    local depth=0
    
    while [[ $depth -lt $max_depth ]] && [[ $current_pid -gt 1 ]]; do
        local parent_cmd=$(ps -o comm= -p "$current_pid" 2>/dev/null || echo "")
        local parent_args=$(ps -o args= -p "$current_pid" 2>/dev/null || echo "")
        
        # Check if this process or its args contain claude
        if [[ "$parent_cmd" =~ ^claude$ ]] || [[ "$parent_args" =~ claude.*code ]] || [[ "$parent_args" =~ ^claude ]]; then
            log_hook_event "INFO" "Detected Claude Code in process chain: PID=$current_pid, CMD=$parent_cmd"
            return 0
        fi
        
        # Get parent PID
        current_pid=$(ps -o ppid= -p "$current_pid" 2>/dev/null | tr -d ' ' || echo "0")
        ((depth++))
    done
    
    # Method 2: Check environment variables set by Claude
    if [[ -n "${CLAUDE_MODEL:-}" ]] || [[ -n "${CLAUDE_SESSION:-}" ]] || [[ "${TERM_PROGRAM:-}" == "Claude" ]]; then
        log_hook_event "INFO" "Detected Claude Code via environment variables"
        return 0
    fi
    
    # Method 3: Check if claude process exists and owns this session
    local claude_pids=()
    mapfile -t claude_pids < <(pgrep -x "claude" 2>/dev/null)
    
    if [[ ${#claude_pids[@]} -gt 0 ]]; then
        # Check if any claude process has the same session
        local current_sid=$(ps -o sid= -p $$ 2>/dev/null | tr -d ' ')
        for pid in "${claude_pids[@]}"; do
            local claude_sid=$(ps -o sid= -p "$pid" 2>/dev/null | tr -d ' ')
            if [[ "$current_sid" == "$claude_sid" ]] && [[ -n "$current_sid" ]] && [[ "$current_sid" != "0" ]]; then
                log_hook_event "INFO" "Detected Claude Code via session ID match: SID=$current_sid"
                return 0
            fi
        done
    fi
    
    log_hook_event "INFO" "Not running in Claude Code context"
    return 1
}

# Safe exit handler with timeout and Claude Code detection
claude_exit_handler() {
    local exit_code=$?
    
    # Initialize logging
    init_hook_logging
    log_hook_event "INFO" "Trap-based exit hook triggered (exit_code=$exit_code)"
    
    # Prevent recursive trap calls immediately
    trap - EXIT SIGINT SIGTERM
    
    echo -e "${CYAN}🪝 Safe exit hook triggered - analyzing context...${NC}"
    
    # Critical: Check if we're in Claude Code context
    if is_running_in_claude_code; then
        log_hook_event "WARN" "Running in Claude Code context - using safe mode"
        echo -e "${YELLOW}⚠️  Detected Claude Code context - using SAFE MODE${NC}"
        safe_claude_code_exit "$exit_code"
        return
    fi
    
    log_hook_event "INFO" "Not in Claude Code context - proceeding with full exit hook"
    echo -e "${GREEN}✅ Safe to proceed with full exit hook${NC}"
    
    # Execute full exit hook with timeout
    execute_exit_hook_with_timeout "$exit_code"
}

# Safe exit specifically for Claude Code context
safe_claude_code_exit() {
    local exit_code="$1"
    
    echo -e "${BLUE}🔒 Claude Code safe exit mode${NC}"
    log_hook_event "INFO" "Executing Claude Code safe exit"
    
    # Only do minimal operations that won't interfere with Claude Code
    local original_dir="$(pwd)"
    
    # Try to change to workspace, but don't force it
    if [[ "$original_dir" != "$WORKSPACE_DIR" ]] && cd "$WORKSPACE_DIR" 2>/dev/null; then
        log_hook_event "INFO" "Changed to workspace directory"
    else
        log_hook_event "WARN" "Using current directory: $original_dir"
    fi
    
    # Mark graceful exit without terminating Claude Code
    if [[ -f "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" ]]; then
        echo -e "${CYAN}🤖 Running minimal graceful operations...${NC}"
        
        # Run smart-exit in non-terminating mode
        timeout "$HOOK_TIMEOUT" "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" --safe-mode 2>/dev/null || {
            log_hook_event "WARN" "Smart-exit timeout or error in safe mode"
            echo -e "${YELLOW}⚠️  Smart-exit had issues, continuing...${NC}"
        }
    fi
    
    # Mark exit as graceful (this is safe)
    mark_graceful_exit_safe
    
    log_hook_event "INFO" "Claude Code safe exit completed"
    echo -e "${GREEN}✅ Safe exit completed - session preserved${NC}"
    
    # Restore directory
    cd "$original_dir" 2>/dev/null || true
    
    # Exit with original code (safe)
    exit "$exit_code"
}

# Execute full exit hook with timeout protection
execute_exit_hook_with_timeout() {
    local exit_code="$1"
    local original_dir="$(pwd)"
    
    echo -e "${BLUE}🚀 Executing full exit hook with timeout protection${NC}"
    
    # Change to workspace directory
    if [[ "$original_dir" != "$WORKSPACE_DIR" ]]; then
        if ! cd "$WORKSPACE_DIR" 2>/dev/null; then
            log_hook_event "ERROR" "Cannot access workspace directory: $WORKSPACE_DIR"
            echo -e "${RED}❌ Errore: impossibile accedere a $WORKSPACE_DIR${NC}"
            echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
            exit "$exit_code"
        fi
    fi
    
    # Check if smart-exit script exists
    if [[ ! -f "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" ]]; then
        log_hook_event "ERROR" "Smart-exit script not found"
        echo -e "${RED}❌ Smart-exit script non trovato${NC}"
        echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
        cd "$original_dir" 2>/dev/null || true
        exit "$exit_code"
    fi
    
    # Execute smart exit with timeout
    echo -e "${BLUE}🚀 Executing smart exit with timeout...${NC}"
    
    if timeout "$HOOK_TIMEOUT" "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" --auto; then
        log_hook_event "INFO" "Smart-exit completed successfully"
        # Smart-exit should have handled the final exit
        # If we get here, something went wrong
        echo -e "${YELLOW}⚠️  Smart exit returned unexpectedly${NC}"
    else
        local timeout_exit_code=$?
        log_hook_event "WARN" "Smart-exit timeout or error (code=$timeout_exit_code)"
        echo -e "${YELLOW}⚠️  Smart exit timeout/error - using fallback${NC}"
        
        # Fallback: mark graceful and exit
        mark_graceful_exit_safe
        echo -e "${GREEN}✅ Fallback exit completed${NC}"
    fi
    
    # Restore directory and exit
    cd "$original_dir" 2>/dev/null || true
    exit "$exit_code"
}

# Safe version of mark_graceful_exit that won't fail
mark_graceful_exit_safe() {
    local recovery_dir="$WORKSPACE_DIR/.claude/auto-memory"
    local exit_type_file="$recovery_dir/exit_type"
    local temp_file="$recovery_dir/exit_type.tmp.$$"
    
    # Create directory safely
    if mkdir -p "$recovery_dir" 2>/dev/null; then
        # Atomic write with error handling
        if echo "graceful_exit" > "$temp_file" 2>/dev/null && mv "$temp_file" "$exit_type_file" 2>/dev/null; then
            log_hook_event "INFO" "Marked graceful exit successfully"
        else
            log_hook_event "WARN" "Failed to mark graceful exit atomically"
            # Fallback: direct write
            echo "graceful_exit" > "$exit_type_file" 2>/dev/null || true
        fi
    else
        log_hook_event "WARN" "Cannot create recovery directory: $recovery_dir"
    fi
}

# Enhanced alias-based exit function with safety checks
claude_exit() {
    # Initialize logging
    init_hook_logging
    log_hook_event "INFO" "Alias-based exit hook triggered with args: $*"
    
    echo -e "${CYAN}🪝 Safe alias exit hook triggered - analyzing context...${NC}"
    
    # Critical: Check if we're in Claude Code context
    if is_running_in_claude_code; then
        log_hook_event "WARN" "Alias exit in Claude Code context - using safe mode"
        echo -e "${YELLOW}⚠️  Detected Claude Code context - using SAFE MODE${NC}"
        safe_claude_code_alias_exit "$@"
        return
    fi
    
    log_hook_event "INFO" "Alias exit not in Claude Code context - proceeding normally"
    echo -e "${GREEN}✅ Safe to proceed with full alias exit${NC}"
    
    # Execute full alias exit with timeout
    execute_alias_exit_with_timeout "$@"
}

# Safe alias exit for Claude Code context
safe_claude_code_alias_exit() {
    echo -e "${BLUE}🔒 Claude Code safe alias exit mode${NC}"
    log_hook_event "INFO" "Executing Claude Code safe alias exit"
    
    # Just mark as graceful and use builtin exit - don't interfere with Claude Code
    mark_graceful_exit_safe
    
    echo -e "${GREEN}✅ Graceful exit marked - using standard exit${NC}"
    log_hook_event "INFO" "Using builtin exit in Claude Code context"
    
    # Use builtin exit to avoid recursion
    builtin exit "$@"
}

# Execute full alias exit with timeout
execute_alias_exit_with_timeout() {
    local original_dir="$(pwd)"
    
    # Change to workspace directory
    if [[ "$original_dir" != "$WORKSPACE_DIR" ]]; then
        if ! cd "$WORKSPACE_DIR" 2>/dev/null; then
            log_hook_event "ERROR" "Cannot access workspace directory via alias"
            echo -e "${RED}❌ Errore: impossibile accedere a $WORKSPACE_DIR${NC}"
            echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
            builtin exit "$@"
        fi
    fi
    
    # Check if smart-exit script exists
    if [[ ! -f "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" ]]; then
        log_hook_event "ERROR" "Smart-exit script not found via alias"
        echo -e "${RED}❌ Smart-exit script non trovato${NC}"
        echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
        cd "$original_dir" 2>/dev/null || true
        builtin exit "$@"
    fi
    
    # Execute smart exit with timeout
    echo -e "${BLUE}🚀 Executing smart exit via alias with timeout...${NC}"
    
    if timeout "$HOOK_TIMEOUT" "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" --auto; then
        log_hook_event "INFO" "Smart-exit via alias completed successfully"
        # If we get here, smart-exit didn't exit properly
        echo -e "${YELLOW}⚠️  Smart exit returned unexpectedly${NC}"
    else
        log_hook_event "WARN" "Smart-exit via alias timeout or error"
        echo -e "${YELLOW}⚠️  Smart exit timeout/error - using fallback${NC}"
        
        # Safe fallback
        mark_graceful_exit_safe
        echo -e "${GREEN}✅ Fallback alias exit completed${NC}"
    fi
    
    # Restore directory and exit
    cd "$original_dir" 2>/dev/null || true
    builtin exit "$@"
}

# Function to install profile-persistent hook
install_profile_hook() {
    local profile_files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
    local hook_line="source \"$WORKSPACE_DIR/scripts/claude-exit-hook.sh\" install_runtime >/dev/null 2>&1"
    local installed=false
    
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]] && [[ -w "$profile_file" ]]; then
            # Check if hook is already installed
            if ! grep -q "claude-exit-hook.sh" "$profile_file"; then
                echo "# Claude Workspace Exit Hook - Auto-installed" >> "$profile_file"
                echo "$hook_line" >> "$profile_file"
                echo -e "${GREEN}✅ Hook installed in $profile_file${NC}"
                installed=true
                break
            else
                echo -e "${YELLOW}⚠️  Hook already exists in $profile_file${NC}"
                installed=true
                break
            fi
        fi
    done
    
    if [[ "$installed" == false ]]; then
        echo -e "${RED}❌ Could not install hook in any profile file${NC}"
        return 1
    fi
    
    return 0
}

# Function to remove profile hook
remove_profile_hook() {
    local profile_files=("$HOME/.bashrc" "$HOME/.bash_profile" "$HOME/.profile")
    local removed=false
    
    for profile_file in "${profile_files[@]}"; do
        if [[ -f "$profile_file" ]] && [[ -w "$profile_file" ]]; then
            if grep -q "claude-exit-hook.sh" "$profile_file"; then
                # Remove hook lines
                sed -i '/# Claude Workspace Exit Hook/d' "$profile_file"
                sed -i '/claude-exit-hook.sh/d' "$profile_file"
                echo -e "${GREEN}✅ Hook removed from $profile_file${NC}"
                removed=true
            fi
        fi
    done
    
    if [[ "$removed" == false ]]; then
        echo -e "${YELLOW}⚠️  Hook not found in any profile file${NC}"
    fi
    
    return 0
}

# Enhanced runtime hook installation with safety checks
install_runtime_hook() {
    # Initialize logging
    init_hook_logging
    log_hook_event "INFO" "Installing runtime hook (PS1=$PS1, PPID=$PPID)"
    
    # Only install in interactive shells
    if [[ -z "$PS1" ]]; then
        log_hook_event "INFO" "Skipping hook installation - non-interactive shell"
        return 0
    fi
    
    # Check if we should install hooks based on context
    if is_running_in_claude_code; then
        log_hook_event "INFO" "Installing hooks in Claude Code context - using safe configuration"
        
        # In Claude Code, only install minimal trap (no aggressive alias)
        trap 'claude_exit_handler' EXIT SIGINT SIGTERM
        
        # Export functions but don't override exit alias aggressively
        export -f claude_exit 2>/dev/null || true
        export -f claude_exit_handler 2>/dev/null || true
        
        log_hook_event "INFO" "Safe runtime hook installed for Claude Code"
    else
        log_hook_event "INFO" "Installing full hooks in normal shell context"
        
        # Install full trap-based hook (primary method)
        trap 'claude_exit_handler' EXIT SIGINT SIGTERM
        
        # Install alias as fallback
        alias exit='claude_exit'
        export -f claude_exit
        export -f claude_exit_handler
        
        log_hook_event "INFO" "Full runtime hook installed"
    fi
    
    # Silent success for profile loading
    return 0
}

# Enhanced install function with context awareness
install_exit_hook() {
    # Initialize logging
    init_hook_logging
    log_hook_event "INFO" "Installing exit hook manually"
    
    # Check context and install appropriate hooks
    if is_running_in_claude_code; then
        echo -e "${YELLOW}⚠️  Claude Code context detected - installing SAFE hooks${NC}"
        log_hook_event "INFO" "Installing safe hooks for Claude Code context"
        
        # Install only trap-based hook (safer)
        trap 'claude_exit_handler' EXIT SIGINT SIGTERM
        export -f claude_exit_handler 2>/dev/null || true
        
        echo -e "${GREEN}✅ Safe exit hook installato - trap-based only${NC}"
        log_hook_event "INFO" "Safe exit hook installed successfully"
    else
        echo -e "${GREEN}📦 Normal shell context - installing FULL hooks${NC}"
        log_hook_event "INFO" "Installing full hooks for normal shell"
        
        # Install full trap-based hook
        trap 'claude_exit_handler' EXIT SIGINT SIGTERM
        
        # Install alias as fallback
        alias exit='claude_exit'
        export -f claude_exit
        export -f claude_exit_handler
        
        echo -e "${GREEN}✅ Exit hook installato (trap + alias) - 'exit' ora esegue graceful exit automatico${NC}"
        log_hook_event "INFO" "Full exit hook installed successfully"
    fi
}

# Funzione per disinstallare l'hook
uninstall_exit_hook() {
    # Remove traps
    trap - EXIT SIGINT SIGTERM 2>/dev/null
    
    # Remove alias and function
    unalias exit 2>/dev/null
    unset -f claude_exit 2>/dev/null
    unset -f claude_exit_handler 2>/dev/null
    
    echo -e "${YELLOW}🔓 Exit hook disinstallato - 'exit' ora funziona normalmente${NC}"
}

# Enhanced hook status check with context awareness
check_hook_status() {
    # Initialize logging
    init_hook_logging
    
    local trap_active=false
    local alias_active=false
    local context_info=""
    
    # Check context
    if is_running_in_claude_code; then
        context_info="(Claude Code context)"
        log_hook_event "INFO" "Checking hook status in Claude Code context"
    else
        context_info="(Normal shell context)"
        log_hook_event "INFO" "Checking hook status in normal shell context"
    fi
    
    # Check trap status
    if trap -p EXIT 2>/dev/null | grep -q "claude_exit_handler"; then
        trap_active=true
    fi
    
    # Check alias status
    if alias exit 2>/dev/null | grep -q "claude_exit"; then
        alias_active=true
    fi
    
    echo -e "${CYAN}🔍 Hook Status $context_info${NC}"
    
    if [[ "$trap_active" == true ]] && [[ "$alias_active" == true ]]; then
        echo -e "${GREEN}✅ Exit hook: FULLY ACTIVE (trap + alias)${NC}"
        log_hook_event "INFO" "Hook status: FULLY ACTIVE"
        return 0
    elif [[ "$trap_active" == true ]]; then
        echo -e "${YELLOW}⚠️  Exit hook: PARTIAL (trap only) - Expected in Claude Code${NC}"
        log_hook_event "INFO" "Hook status: PARTIAL (trap only)"
        return 0
    elif [[ "$alias_active" == true ]]; then
        echo -e "${YELLOW}⚠️  Exit hook: PARTIAL (alias only) - Unusual${NC}"
        log_hook_event "WARN" "Hook status: PARTIAL (alias only)"
        return 0
    else
        echo -e "${RED}❌ Exit hook: NOT ACTIVE${NC}"
        log_hook_event "WARN" "Hook status: NOT ACTIVE"
        return 1
    fi
}

# Main logic
case "${1:-install}" in
    "install")
        install_exit_hook
        ;;
    "install_runtime")
        install_runtime_hook
        ;;
    "install_profile")
        install_profile_hook
        ;;
    "remove_profile")
        remove_profile_hook
        ;;
    "uninstall")
        uninstall_exit_hook
        ;;
    "status")
        check_hook_status
        ;;
    "test")
        echo -e "${CYAN}🧪 Test exit hook...${NC}"
        if check_hook_status; then
            echo -e "${BLUE}💡 Prova a digitare 'exit' per testare l'hook${NC}"
            echo -e "${BLUE}💡 Oppure prova Ctrl+C per testare il trap${NC}"
            echo -e "${CYAN}📝 Log file: $HOOK_LOG_FILE${NC}"
            echo -e "${CYAN}🐛 Debug mode: export CLAUDE_EXIT_HOOK_DEBUG=1${NC}"
        else
            echo -e "${RED}❌ Hook non attivo. Usa 'install' per attivarlo${NC}"
        fi
        ;;
    "help")
        echo "Claude Exit Hook v3.0 - Enhanced safety with Claude Code detection"
        echo ""
        echo "Uso: claude-exit-hook.sh [comando]"
        echo ""
        echo "Comandi:"
        echo "  install          Installa hook per sessione corrente (trap + alias)"
        echo "  install_profile  Installa hook permanente nei file di profilo"
        echo "  install_runtime  Installa hook runtime (chiamato da profilo)"
        echo "  remove_profile   Rimuove hook dai file di profilo"
        echo "  uninstall        Rimuove hook da sessione corrente"
        echo "  status           Mostra stato hook dettagliato"
        echo "  test             Testa se hook è attivo"
        echo "  help             Mostra questo aiuto"
        echo ""
        echo "METODI DI INTERCETTAZIONE:"
        echo "• Trap-based: Intercetta EXIT, SIGINT, SIGTERM (più affidabile)"
        echo "• Alias-based: Sostituisce comando 'exit' (fallback per shell normali)"
        echo ""
        echo "MODALITÀ SICUREZZA:"
        echo "• Claude Code Detection: Rileva contesto Claude Code automaticamente"
        echo "• Safe Mode: Usa operazioni minime quando in Claude Code"
        echo "• Timeout Protection: Evita hang con timeout configurabile"
        echo "• Enhanced Logging: Log dettagliati per debugging"
        echo ""
        echo "INSTALLAZIONE PERMANENTE:"
        echo "• install_profile: Aggiunge hook ai file di profilo (~/.bashrc, etc)"
        echo "• L'hook verrà caricato automaticamente ad ogni nuova sessione"
        echo "• Context-aware: Si adatta automaticamente al contesto di esecuzione"
        echo ""
        echo "Una volta installato, exit/Ctrl+C eseguiranno graceful exit automatico!"
        echo "In Claude Code context, usa solo operazioni sicure che non causano crash."
        ;;
    *)
        echo -e "${RED}❌ Comando sconosciuto: $1${NC}"
        echo "Usa 'help' per vedere i comandi disponibili"
        exit 1
        ;;
esac