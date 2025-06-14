# Claude Exit Hook Configuration
claude_exit() {
    local WORKSPACE_DIR="$HOME/claude-workspace"
    local CYAN='\033[0;36m'
    local BLUE='\033[0;34m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m'
    
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
    
    # Esegui smart exit con modalità automatica
    echo -e "${BLUE}🚀 Executing smart exit...${NC}"
    "$WORKSPACE_DIR/scripts/claude-smart-exit.sh" --auto
    
    # Se arriviamo qui, smart-exit non ha fatto exit (errore)
    echo -e "${YELLOW}⚠️  Smart exit non ha terminato - fallback a exit normale${NC}"
    builtin exit "$@"
}

# Installa alias
alias exit='claude_exit'
