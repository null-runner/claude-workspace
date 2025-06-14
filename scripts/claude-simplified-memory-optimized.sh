#!/bin/bash
# Claude Simplified Memory - Optimized Version
# Riduce overhead Python usando memory-operations.py persistente

WORKSPACE_DIR="$HOME/claude-workspace"
MEMORY_DIR="$WORKSPACE_DIR/.claude/memory"
CONTEXT_FILE="$MEMORY_DIR/enhanced-context.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$MEMORY_DIR"

# Funzione per salvare context semplificato
save_context() {
    local save_reason="${1:-manual}"
    local conversation_summary="${2:-}"
    local open_issues="${3:-}"
    local next_actions="${4:-}"
    
    # Prima prova il coordinator unificato
    if [[ -x "$WORKSPACE_DIR/scripts/claude-memory-coordinator.sh" ]]; then
        echo -e "${YELLOW}💾 Using unified memory coordinator...${NC}"
        "$WORKSPACE_DIR/scripts/claude-memory-coordinator.sh" save simplified "$save_reason" "$conversation_summary" "$open_issues" "$next_actions"
        return $?
    fi
    
    # Fallback ottimizzato usando memory-operations.py
    echo -e "${YELLOW}💾 Saving optimized context...${NC}"
    
    export WORKSPACE_DIR
    python3 "$WORKSPACE_DIR/scripts/memory-operations.py" save_context "$save_reason" "$conversation_summary" "$open_issues" "$next_actions"
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✅ Context saved successfully${NC}"
    else
        echo -e "${RED}❌ Failed to save context${NC}"
    fi
    
    return $result
}

# Funzione per caricare context semplificato
load_context() {
    echo -e "${CYAN}🧠 Loading unified context...${NC}"
    
    # Prima prova il coordinator unificato
    if [[ -x "$WORKSPACE_DIR/scripts/claude-memory-coordinator.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-memory-coordinator.sh" load
        return $?
    fi
    
    # Fallback ottimizzato usando memory-operations.py
    echo -e "${CYAN}Loading optimized context...${NC}"
    
    export WORKSPACE_DIR
    local context_json=$(python3 "$WORKSPACE_DIR/scripts/memory-operations.py" load_context)
    local result=$?
    
    if [[ $result -ne 0 ]]; then
        echo -e "${RED}❌ Failed to load context${NC}"
        return $result
    fi
    
    # Parse e display del context
    local last_session=$(echo "$context_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    if 'error' in data:
        print(f'Error: {data[\"error\"]}')
    else:
        print(f'📅 Last session: {data.get(\"timestamp\", \"unknown\")}')
        if 'device' in data:
            print(f'💻 Device: {data[\"device\"]}')
        if 'current_project' in data and data['current_project']:
            project = data['current_project']
            print(f'📁 Project: {project.get(\"name\", \"unknown\")} ({project.get(\"type\", \"unknown\")})')
        if 'git_status' in data:
            git = data['git_status']
            print(f'🌿 Branch: {git.get(\"branch\", \"unknown\")}')
            if git.get('has_changes', False):
                print(f'📝 Uncommitted changes: {git.get(\"dirty_files_count\", 0)} files')
        if 'conversation_summary' in data and data['conversation_summary']:
            print(f'💬 Summary: {data[\"conversation_summary\"]}')
        if 'open_issues' in data and data['open_issues']:
            print('🚨 Open issues:')
            for issue in data['open_issues'][:5]:  # Max 5 issues
                print(f'   • {issue}')
        if 'next_actions' in data and data['next_actions']:
            print('🎯 Next actions:')
            for action in data['next_actions'][:5]:  # Max 5 actions
                print(f'   • {action}')
except json.JSONDecodeError:
    print('Error: Invalid JSON data')
except Exception as e:
    print(f'Error: {e}')
")
    
    echo "$last_session"
    return 0
}

# Funzione per ottenere statistiche performance
get_stats() {
    export WORKSPACE_DIR
    python3 "$WORKSPACE_DIR/scripts/memory-operations.py" stats
}

# Main command handler
case "${1:-}" in
    "save")
        save_context "${2:-manual}" "${3:-}" "${4:-}" "${5:-}"
        ;;
    "load")
        load_context
        ;;
    "stats")
        get_stats
        ;;
    *)
        echo "Usage: $0 {save|load|stats} [args...]"
        echo ""
        echo "Commands:"
        echo "  save [reason] [summary] [issues] [actions] - Save context"
        echo "  load                                       - Load and display context"
        echo "  stats                                      - Show performance statistics"
        exit 1
        ;;
esac