#!/bin/bash
# Claude Session Manager - Interface per Enhanced Session Save
# Da usare durante le conversazioni per salvare context e stato

WORKSPACE_DIR="$HOME/claude-workspace"
ENHANCED_SAVE="$WORKSPACE_DIR/scripts/claude-enhanced-save.sh"
SESSION_CONTEXT_FILE="$WORKSPACE_DIR/.claude/memory/current-session-context.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funzione per salvare sessione interattiva
save_interactive() {
    echo -e "${CYAN}🚀 Claude Session Save - Modalità Interattiva${NC}"
    echo ""
    
    # Raccoglie info
    read -p "📝 Nota sessione (breve descrizione): " session_note
    echo ""
    
    read -p "💬 Riassunto conversazione (cosa stavamo facendo): " conversation_summary
    echo ""
    
    echo "⏳ Task incomplete (una per riga, ENTER vuoto per finire):"
    incomplete_tasks=()
    while true; do
        read -p "   • " task
        if [[ -z "$task" ]]; then
            break
        fi
        incomplete_tasks+=("$task")
    done
    
    echo ""
    echo "➡️ Prossimi passi (uno per riga, ENTER vuoto per finire):"
    next_steps=()
    while true; do
        read -p "   • " step
        if [[ -z "$step" ]]; then
            break
        fi
        next_steps+=("$step")
    done
    
    # Converte array in string separata da |||
    incomplete_tasks_str=$(IFS='|||'; echo "${incomplete_tasks[*]}")
    next_steps_str=$(IFS='|||'; echo "${next_steps[*]}")
    
    echo ""
    echo -e "${YELLOW}💾 Salvando sessione...${NC}"
    
    # Esegue enhanced save
    "$ENHANCED_SAVE" "$session_note" "$conversation_summary" "$incomplete_tasks_str" "$next_steps_str"
}

# Funzione per salvare sessione rapida
save_quick() {
    local note="$1"
    local summary="$2"
    
    if [[ -z "$note" ]]; then
        note="Quick save $(date '+%H:%M')"
    fi
    
    if [[ -z "$summary" ]]; then
        summary="Session checkpoint"
    fi
    
    echo -e "${YELLOW}⚡ Quick save sessione...${NC}"
    "$ENHANCED_SAVE" "$note" "$summary"
}

# Funzione per visualizzare recap ultima sessione
show_recap() {
    echo -e "${CYAN}📖 Recap Ultima Sessione${NC}"
    echo ""
    
    if [[ ! -f "$SESSION_CONTEXT_FILE" ]]; then
        echo -e "${RED}❌ Nessuna sessione enhanced trovata${NC}"
        return 1
    fi
    
    "$ENHANCED_SAVE" --load
}

# Funzione per salvare end-of-session completo
save_end_session() {
    echo -e "${CYAN}🏁 End of Session Save${NC}"
    echo ""
    
    # Auto-detect info
    local modified_files=$(cd "$WORKSPACE_DIR" && git status --porcelain | wc -l)
    local current_branch=$(cd "$WORKSPACE_DIR" && git branch --show-current 2>/dev/null || echo "unknown")
    
    echo -e "${BLUE}📊 Stato rilevato:${NC}"
    echo "   • Branch: $current_branch"
    echo "   • File modificati: $modified_files"
    echo ""
    
    read -p "📝 Come è andata la sessione? " session_note
    echo ""
    
    read -p "💬 Cosa è stato fatto di principale: " conversation_summary
    echo ""
    
    if [[ "$modified_files" -gt 0 ]]; then
        echo -e "${YELLOW}⚠️  Hai $modified_files file modificati non committati${NC}"
        read -p "🔄 Vuoi committarli ora? (y/n): " commit_now
        
        if [[ "$commit_now" == "y" || "$commit_now" == "Y" ]]; then
            read -p "📄 Messaggio commit: " commit_msg
            cd "$WORKSPACE_DIR"
            git add -A
            git commit -m "$commit_msg

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>"
            git push
            echo -e "${GREEN}✅ Commit e push completati${NC}"
        fi
    fi
    
    echo ""
    echo "🔜 Cosa rimane da fare alla prossima sessione:"
    todo_items=()
    while true; do
        read -p "   • " item
        if [[ -z "$item" ]]; then
            break
        fi
        todo_items+=("$item")
    done
    
    # Salva sessione completa
    todo_items_str=$(IFS='|||'; echo "${todo_items[*]}")
    
    echo ""
    echo -e "${YELLOW}💾 Salvando end-of-session...${NC}"
    "$ENHANCED_SAVE" "END SESSION: $session_note" "$conversation_summary" "$todo_items_str" "Resume next session"
    
    echo ""
    echo -e "${GREEN}🎉 Sessione salvata! Alla prossima! 👋${NC}"
}

# Help
show_help() {
    echo "Claude Session Manager - Gestione Enhanced Sessions"
    echo ""
    echo "Uso: claude-session-manager [comando] [parametri]"
    echo ""
    echo "Comandi:"
    echo "  save, s              - Salvataggio interattivo completo"
    echo "  quick [nota]         - Salvataggio rapido con nota"
    echo "  recap, r             - Mostra recap ultima sessione"
    echo "  end                  - End-of-session completo con commit"
    echo "  help, h              - Mostra questo help"
    echo ""
    echo "Esempi:"
    echo "  claude-session-manager save"
    echo "  claude-session-manager quick \"Working on auth\""
    echo "  claude-session-manager recap"
    echo "  claude-session-manager end"
    echo ""
    echo "Alias rapidi:"
    echo "  css save    (claude session save)"
    echo "  css quick   (quick save)"
    echo "  css recap   (show recap)"
    echo "  css end     (end session)"
}

# Main
case "$1" in
    "save"|"s")
        save_interactive
        ;;
    "quick"|"q")
        save_quick "$2" "$3"
        ;;
    "recap"|"r"|"load"|"l")
        show_recap
        ;;
    "end"|"finish"|"done")
        save_end_session
        ;;
    "help"|"h"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Comando sconosciuto: $1${NC}"
        echo "Usa 'claude-session-manager help' per vedere i comandi disponibili"
        exit 1
        ;;
esac