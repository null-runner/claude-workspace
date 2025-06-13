#!/bin/bash
# Claude Exit Hook - Intercetta comando exit per graceful exit automatico
# Questo hook viene attivato automaticamente quando usi "exit"
# Version 2.0 - Trap-based system for better reliability

WORKSPACE_DIR="$HOME/claude-workspace"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Function to handle graceful exit via trap
claude_exit_handler() {
    local exit_code=$?
    echo -e "${CYAN}🪝 Trap-based exit hook triggered - avvio graceful exit...${NC}"
    echo ""
    
    # Prevent recursive trap calls
    trap - EXIT SIGINT SIGTERM
    
    # Cambia alla directory workspace se non ci siamo già
    local original_dir="$(pwd)"
    if [[ "$original_dir" != "$WORKSPACE_DIR" ]]; then
        cd "$WORKSPACE_DIR" 2>/dev/null || {
            echo -e "${RED}❌ Errore: impossibile accedere a $WORKSPACE_DIR${NC}"
            echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
            exit $exit_code
        }
    fi
    
    # Controlla se lo script smart-exit esiste
    if [[ ! -f "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" ]]; then
        echo -e "${RED}❌ Smart-exit script non trovato${NC}"
        echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
        cd "$original_dir" 2>/dev/null
        exit $exit_code
    fi
    
    # Esegui smart exit con modalità automatica (senza prompt eccessivi)
    echo -e "${BLUE}🚀 Executing smart exit...${NC}"
    "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" --auto
    
    # If we get here, smart-exit didn't exit (error case)
    echo -e "${YELLOW}⚠️  Smart exit non ha terminato - fallback a exit normale${NC}"
    cd "$original_dir" 2>/dev/null
    exit $exit_code
}

# Funzione exit personalizzata che sostituisce il comando exit (alias fallback)
claude_exit() {
    echo -e "${CYAN}🪝 Alias-based exit hook triggered - avvio graceful exit...${NC}"
    echo ""
    
    # Cambia alla directory workspace se non ci siamo già
    if [[ "$(pwd)" != "$WORKSPACE_DIR" ]]; then
        cd "$WORKSPACE_DIR" 2>/dev/null || {
            echo -e "${RED}❌ Errore: impossibile accedere a $WORKSPACE_DIR${NC}"
            echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
            builtin exit "$@"
        }
    fi
    
    # Controlla se lo script smart-exit esiste
    if [[ ! -f "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" ]]; then
        echo -e "${RED}❌ Smart-exit script non trovato${NC}"
        echo -e "${YELLOW}💡 Proseguo con exit normale...${NC}"
        builtin exit "$@"
    fi
    
    # Esegui smart exit con modalità automatica (senza prompt eccessivi)
    echo -e "${BLUE}🚀 Executing smart exit...${NC}"
    "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" --auto
    
    # Se arriviamo qui, smart-exit non ha fatto exit (errore)
    echo -e "${YELLOW}⚠️  Smart exit non ha terminato - fallback a exit normale${NC}"
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

# Runtime hook installation (called from profile)
install_runtime_hook() {
    # Only install in interactive shells
    if [[ -n "$PS1" ]]; then
        # Install trap-based hook (primary method)
        trap 'claude_exit_handler' EXIT SIGINT SIGTERM
        
        # Install alias as fallback
        alias exit='claude_exit'
        export -f claude_exit
        
        # Silent success for profile loading
        return 0
    fi
    
    return 0
}

# Funzione per installare l'hook (backward compatibility)
install_exit_hook() {
    # Install trap-based hook for current session
    trap 'claude_exit_handler' EXIT SIGINT SIGTERM
    
    # Install alias as fallback
    alias exit='claude_exit'
    export -f claude_exit
    
    echo -e "${GREEN}✅ Exit hook installato (trap + alias) - 'exit' ora esegue graceful exit automatico${NC}"
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

# Funzione per verificare se l'hook è attivo
check_hook_status() {
    local trap_active=false
    local alias_active=false
    
    # Check trap status
    if trap -p EXIT | grep -q "claude_exit_handler"; then
        trap_active=true
    fi
    
    # Check alias status
    if alias exit 2>/dev/null | grep -q "claude_exit"; then
        alias_active=true
    fi
    
    if [[ "$trap_active" == true ]] && [[ "$alias_active" == true ]]; then
        echo -e "${GREEN}✅ Exit hook: FULLY ACTIVE (trap + alias)${NC}"
        return 0
    elif [[ "$trap_active" == true ]]; then
        echo -e "${YELLOW}⚠️  Exit hook: PARTIAL (trap only)${NC}"
        return 0
    elif [[ "$alias_active" == true ]]; then
        echo -e "${YELLOW}⚠️  Exit hook: PARTIAL (alias only)${NC}"
        return 0
    else
        echo -e "${RED}❌ Exit hook: NOT ACTIVE${NC}"
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
        else
            echo -e "${RED}❌ Hook non attivo. Usa 'install' per attivarlo${NC}"
        fi
        ;;
    "help")
        echo "Claude Exit Hook v2.0 - Trap + Alias based exit interceptor"
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
        echo "• Alias-based: Sostituisce comando 'exit' (fallback)"
        echo ""
        echo "INSTALLAZIONE PERMANENTE:"
        echo "• install_profile: Aggiunge hook ai file di profilo (~/.bashrc, etc)"
        echo "• L'hook verrà caricato automaticamente ad ogni nuova sessione"
        echo ""
        echo "Una volta installato, exit/Ctrl+C eseguiranno graceful exit automatico!"
        ;;
    *)
        echo -e "${RED}❌ Comando sconosciuto: $1${NC}"
        echo "Usa 'help' per vedere i comandi disponibili"
        exit 1
        ;;
esac