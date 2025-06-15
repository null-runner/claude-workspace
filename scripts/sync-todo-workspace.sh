#!/bin/bash
# Sync TODO Workspace - Sincronizza TodoWrite ↔ TODO.md
# Garantisce persistenza TODO tra sessioni Claude Code

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Detect current project and use appropriate TODO file
detect_todo_file() {
    local project_json="$WORKSPACE_DIR/.claude/auto-projects/current.json"
    
    # Default to workspace meta-project
    local todo_path="$WORKSPACE_DIR/meta-projects/claude-workspace/TODO.md"
    
    if [[ -f "$project_json" ]]; then
        # Extract project info
        local project_name=$(python3 -c "import json; print(json.load(open('$project_json'))['name'])" 2>/dev/null || echo "")
        local project_type=$(python3 -c "import json; print(json.load(open('$project_json'))['type'])" 2>/dev/null || echo "")
        local project_path=$(python3 -c "import json; print(json.load(open('$project_json'))['path'])" 2>/dev/null || echo "")
        
        if [[ "$project_type" == "meta" ]]; then
            # Meta project - use meta-projects directory
            todo_path="$WORKSPACE_DIR/meta-projects/$project_name/TODO.md"
        elif [[ -n "$project_path" && "$project_path" != "." ]]; then
            # Regular project - use project directory
            todo_path="$project_path/TODO.md"
        fi
        
        echo -e "${BLUE}📁 Project: $project_name (type: $project_type)${NC}" >&2
        echo -e "${BLUE}📋 TODO file: $todo_path${NC}" >&2
    else
        echo -e "${YELLOW}⚠️  No project detected, using workspace TODO${NC}" >&2
    fi
    
    # Create TODO file if doesn't exist
    if [[ ! -f "$todo_path" ]]; then
        mkdir -p "$(dirname "$todo_path")"
        echo "# TODO List - $project_name" > "$todo_path"
        echo "" >> "$todo_path"
        echo -e "${GREEN}✅ Created new TODO file: $todo_path${NC}" >&2
    fi
    
    echo "$todo_path"
}

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Dynamic TODO file detection
TODO_FILE=$(detect_todo_file)

# Funzione per parsare TODO.md e creare TodoWrite format
parse_todo_md() {
    if [[ ! -f "$TODO_FILE" ]]; then
        echo "[]"
        return
    fi
    
    # Usa parser Python per estrazione completa
    python3 "$WORKSPACE_DIR/scripts/todo-parser.py" parse "$TODO_FILE"
}

# Funzione per aggiornare TODO.md da TodoWrite
update_todo_md() {
    local todo_data="$1"
    
    echo -e "${YELLOW}🔄 Aggiornando TODO.md workspace...${NC}"
    
    # Backup TODO.md corrente
    if [[ -f "$TODO_FILE" ]]; then
        cp "$TODO_FILE" "$TODO_FILE.backup.$(date +%s)"
        echo -e "${YELLOW}📋 Backup creato: TODO.md.backup.$(date +%s)${NC}"
    fi
    
    # Usa parser Python per update completo
    python3 "$WORKSPACE_DIR/scripts/todo-parser.py" update "$TODO_FILE" "$todo_data"
    
    echo -e "${GREEN}✅ TODO.md aggiornato con session todos${NC}"
}

# Funzione per caricare TODO.md in TodoWrite (genera comandi per Claude)
load_todo_to_todowrite() {
    echo -e "${YELLOW}📥 Caricando TODO.md in TodoWrite...${NC}"
    
    local todo_json=$(parse_todo_md)
    local todo_count=$(echo "$todo_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    
    if [[ "$todo_count" -gt 0 ]]; then
        echo -e "${GREEN}✅ Trovati $todo_count todos in TODO.md${NC}"
        echo -e "${YELLOW}💡 Per caricare in TodoWrite, Claude deve eseguire:${NC}"
        echo -e "${YELLOW}   TodoWrite con todos: $todo_json${NC}"
        
        # Opzionalmente salva in file temporaneo per Claude
        echo "$todo_json" > "$WORKSPACE_DIR/.claude/temp-todos-from-md.json"
        echo -e "${GREEN}📁 Saved in .claude/temp-todos-from-md.json per Claude${NC}"
    else
        echo -e "${YELLOW}⚠️  Nessun TODO trovato in TODO.md${NC}"
    fi
}

# Main function
case "${1:-help}" in
    "load")
        load_todo_to_todowrite
        ;;
    "save")
        # Richiede TODO data come secondo parametro
        update_todo_md "${2:-[]}"
        ;;
    "sync")
        load_todo_to_todowrite
        ;;
    *)
        echo "Usage: $0 {load|save|sync}"
        echo "  load  - Carica TODO.md in TodoWrite"
        echo "  save  - Salva TodoWrite in TODO.md"
        echo "  sync  - Sincronizza bidirezionale"
        exit 1
        ;;
esac