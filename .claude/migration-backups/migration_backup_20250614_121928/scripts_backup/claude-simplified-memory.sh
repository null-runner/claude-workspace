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
    python3 "$WORKSPACE_DIR/scripts/memory_operations.py" save_context "$save_reason" "$conversation_summary" "$open_issues" "$next_actions"
    local result=$?
    
    if [[ $result -eq 0 ]]; then
        echo -e "${GREEN}✅ Context saved successfully${NC}"
    else
        echo -e "${RED}❌ Failed to save context${NC}"
    fi
    
    return $result
}

# Funzione per integrare intelligence context
integrate_intelligence_context() {
    local intelligence_context_file="$WORKSPACE_DIR/.claude/intelligence/claude-memory-context.json"
    
    if [[ -f "$intelligence_context_file" ]]; then
        echo -e "${CYAN}🧠 Integrating enhanced intelligence context...${NC}"
        
        # Merge intelligence context with current memory
        export INTELLIGENCE_CONTEXT_FILE="$intelligence_context_file"
        export MEMORY_DIR
        
        python3 << 'EOF'
import json
import os
from datetime import datetime

def merge_intelligence_context():
    try:
        # Load intelligence context
        intel_file = os.environ.get('INTELLIGENCE_CONTEXT_FILE')
        memory_dir = os.environ.get('MEMORY_DIR')
        
        with open(intel_file, 'r') as f:
            intel_context = json.load(f)
        
        # Load current memory context if exists
        memory_file = os.path.join(memory_dir, 'enhanced-context.json')
        if os.path.exists(memory_file):
            with open(memory_file, 'r') as f:
                memory_context = json.load(f)
        else:
            memory_context = {
                "session_context": {},
                "conversation_memory": {}
            }
        
        # Merge intelligence profile into memory
        if 'user_intelligence_profile' in intel_context:
            memory_context['user_intelligence_profile'] = intel_context['user_intelligence_profile']
        
        if 'current_session' in intel_context:
            memory_context['current_session_intelligence'] = intel_context['current_session']
        
        # Add timestamp
        memory_context['last_intelligence_update'] = datetime.now().isoformat() + 'Z'
        
        # Save merged context
        with open(memory_file, 'w') as f:
            json.dump(memory_context, f, indent=2)
        
        print("✅ Intelligence context integrated into memory system")
        return True
        
    except Exception as e:
        print(f"❌ Failed to integrate intelligence context: {e}")
        return False

if merge_intelligence_context():
    exit(0)
else:
    exit(1)
EOF
        return $?
    else
        echo -e "${YELLOW}⚠️  No intelligence context found to integrate${NC}"
        return 0
    fi
}

# Funzione per caricare context semplificato
load_context() {
    echo -e "${CYAN}🧠 Loading unified context...${NC}"
    
    # First integrate latest intelligence context
    integrate_intelligence_context
    
    # Prima prova il coordinator unificato
    if [[ -x "$WORKSPACE_DIR/scripts/claude-memory-coordinator.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-memory-coordinator.sh" load
        return $?
    fi
    
    # Fallback ottimizzato usando memory-operations.py
    echo -e "${CYAN}Loading optimized context...${NC}"
    
    export WORKSPACE_DIR
    local context_json=$(python3 "$WORKSPACE_DIR/scripts/memory_operations.py" load_context)
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
    python3 "$WORKSPACE_DIR/scripts/memory_operations.py" stats
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