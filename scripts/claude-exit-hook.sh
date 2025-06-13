#!/bin/bash
# Claude Exit Hook - Intercetta comando exit per graceful exit automatico
# Questo hook viene attivato automaticamente quando usi "exit"

WORKSPACE_DIR="$HOME/claude-workspace"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funzione exit personalizzata che sostituisce il comando exit
claude_exit() {
    echo -e "${CYAN}🪝 Intercettato comando exit - avvio graceful exit...${NC}"
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

# Funzione per installare l'hook
install_exit_hook() {
    # Crea alias che sostituisce il comando exit
    alias exit='claude_exit'
    
    # Esporta la funzione per renderla disponibile in subshell
    export -f claude_exit
    
    echo -e "${GREEN}✅ Exit hook installato - 'exit' ora esegue graceful exit automatico${NC}"
}

# Funzione per disinstallare l'hook
uninstall_exit_hook() {
    unalias exit 2>/dev/null
    unset -f claude_exit 2>/dev/null
    echo -e "${YELLOW}🔓 Exit hook disinstallato - 'exit' ora funziona normalmente${NC}"
}

# Funzione per verificare se l'hook è attivo
check_hook_status() {
    if alias exit 2>/dev/null | grep -q "claude_exit"; then
        echo -e "${GREEN}✅ Exit hook: ATTIVO${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Exit hook: NON ATTIVO${NC}"
        return 1
    fi
}

# Main logic
case "${1:-install}" in
    "install")
        install_exit_hook
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
        else
            echo -e "${RED}❌ Hook non attivo. Usa 'install' per attivarlo${NC}"
        fi
        ;;
    "help")
        echo "Claude Exit Hook - Intercettatore automatico per graceful exit"
        echo ""
        echo "Uso: claude-exit-hook.sh [comando]"
        echo ""
        echo "Comandi:"
        echo "  install     Installa hook per intercettare 'exit' (default)"
        echo "  uninstall   Rimuove hook, ripristina 'exit' normale"
        echo "  status      Mostra stato hook"
        echo "  test        Testa se hook è attivo"
        echo "  help        Mostra questo aiuto"
        echo ""
        echo "Una volta installato, ogni volta che digiti 'exit' verrà"
        echo "automaticamente eseguito il graceful exit con smart-sync!"
        ;;
    *)
        echo -e "${RED}❌ Comando sconosciuto: $1${NC}"
        echo "Usa 'help' per vedere i comandi disponibili"
        exit 1
        ;;
esac