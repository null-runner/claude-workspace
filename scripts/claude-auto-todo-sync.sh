#!/bin/bash
# Claude Auto TODO Sync - Automatically sync TodoWrite to TODO.md
# Called from CLAUDE.md rules when Claude updates todos

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC_SCRIPT="$WORKSPACE_DIR/scripts/sync-todo-workspace.sh"

# Dynamic temp file based on current project
get_temp_todo_file() {
    local project_json="$WORKSPACE_DIR/.claude/auto-projects/current.json"
    local project_name="workspace"
    
    if [[ -f "$project_json" ]]; then
        project_name=$(python3 -c "import json; print(json.load(open('$project_json'))['name'])" 2>/dev/null || echo "workspace")
    fi
    
    echo "$WORKSPACE_DIR/.claude/temp-todos-${project_name}.json"
}

TEMP_TODO_FILE=$(get_temp_todo_file)

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if we have temporary todos (created by load)
load_todos_from_temp() {
    if [[ -f "$TEMP_TODO_FILE" ]]; then
        echo -e "${BLUE}📥 Loading persisted TODOs from previous session...${NC}"
        
        local todo_json=$(cat "$TEMP_TODO_FILE")
        local todo_count=$(echo "$todo_json" | python3 -c "import sys, json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
        
        echo -e "${GREEN}✅ Found $todo_count persisted TODOs to load${NC}"
        echo -e "${YELLOW}💡 Claude should use TodoWrite tool with:${NC}"
        echo "$todo_json"
        
        return 0
    else
        echo -e "${YELLOW}⚠️  No persisted TODOs found${NC}"
        return 1
    fi
}

# Save current session todos to TODO.md
save_session_todos() {
    local todo_data="$1"
    
    if [[ -z "$todo_data" || "$todo_data" == "[]" ]]; then
        echo -e "${YELLOW}⚠️  No session TODOs to save${NC}"
        return 0
    fi
    
    echo -e "${BLUE}💾 Saving session TODOs to TODO.md...${NC}"
    
    # Use sync script to update TODO.md
    "$SYNC_SCRIPT" save "$todo_data"
    
    # Clean temp file
    rm -f "$TEMP_TODO_FILE"
    
    echo -e "${GREEN}✅ Session TODOs saved and persisted${NC}"
}

# Auto-detect current session todos (simplified version)
auto_save_current_session() {
    echo -e "${YELLOW}🔍 Auto-detecting current session TODOs...${NC}"
    echo -e "${YELLOW}💡 This requires Claude to call with current TodoWrite data${NC}"
    echo -e "${YELLOW}Usage: $0 save '[{\"id\":\"1\",\"content\":\"task\",\"status\":\"pending\",\"priority\":\"high\"}]'${NC}"
}

case "${1:-help}" in
    "load")
        load_todos_from_temp
        ;;
    "save")
        if [[ -n "${2:-}" ]]; then
            save_session_todos "$2"
        else
            auto_save_current_session
        fi
        ;;
    "auto-save")
        auto_save_current_session
        ;;
    *)
        echo "Claude Auto TODO Sync - Automatic TODO persistence"
        echo ""
        echo "Usage: $0 {load|save|auto-save}"
        echo "  load      - Load persisted TODOs from TODO.md"
        echo "  save DATA - Save session TODOs to TODO.md"
        echo "  auto-save - Prompt for manual save"
        echo ""
        echo "Examples:"
        echo "  $0 load                    # At session start"
        echo "  $0 save '[{\"id\":\"1\",...}]'  # At session end"
        exit 1
        ;;
esac