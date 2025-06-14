#!/bin/bash
# Claude Workspace - Enhanced Session Save Script
# Salva stato completo: context conversazione, task incomplete, next steps

MEMORY_DIR="$HOME/claude-workspace/.claude/memory"
ENHANCED_MEMORY_FILE="$MEMORY_DIR/enhanced-sessions.json"
SESSION_CONTEXT_FILE="$MEMORY_DIR/current-session-context.json"

# Parametri
SESSION_NOTE="$1"
CONVERSATION_SUMMARY="$2"
INCOMPLETE_TASKS="$3"
NEXT_STEPS="$4"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verifica permessi
if [[ ! -f ~/.claude-access/ACTIVE ]]; then
    echo "⚠️  Claude non attivo. Modalità read-only..."
fi

# Crea directory se non esiste
mkdir -p "$MEMORY_DIR"

# Funzione per rilevare projetto attivo
detect_active_project() {
    local current_dir=$(pwd)
    
    if [[ "$current_dir" =~ claude-workspace/projects/ ]]; then
        local project_path=${current_dir#*claude-workspace/projects/}
        local project_type=$(echo "$project_path" | cut -d'/' -f1)
        local project_name=$(echo "$project_path" | cut -d'/' -f2)
        
        if [[ -n "$project_name" ]]; then
            echo "{\"name\":\"$project_name\",\"type\":\"$project_type\",\"path\":\"$project_path\"}"
            return
        fi
    fi
    
    # Cerca ultimo progetto modificato
    local last_project=$(find ~/claude-workspace/projects -name "*.py" -o -name "*.js" -o -name "*.md" -o -name "*.json" -type f -exec stat -c "%Y %n" {} + 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
    
    if [[ -n "$last_project" ]]; then
        local rel_path=${last_project#*claude-workspace/projects/}
        local project_type=$(echo "$rel_path" | cut -d'/' -f1)
        local project_name=$(echo "$rel_path" | cut -d'/' -f2)
        
        if [[ -n "$project_name" ]]; then
            echo "{\"name\":\"$project_name\",\"type\":\"$project_type\",\"path\":\"projects/$project_type/$project_name\"}"
            return
        fi
    fi
    
    echo "null"
}

# Funzione per analizzare file modificati
analyze_modified_files() {
    cd ~/claude-workspace
    
    # Usa approccio più robusto con tempfile
    python3 << 'EOF'
import subprocess
import json
import sys

try:
    # Esegui git status e cattura output
    result = subprocess.run(['git', 'status', '--porcelain'], 
                          capture_output=True, text=True, check=True)
    
    files = []
    for line in result.stdout.strip().split('\n'):
        if not line:
            continue
            
        # Parse formato git status --porcelain
        # Formato: XY filename
        # X = index status, Y = working tree status
        if len(line) < 3:
            continue
            
        status = line[:2]
        filepath = line[3:]  # Skip status + space
        
        # Determina tipo di modifica basato su status
        if 'M' in status:
            change_type = 'modified'
        elif 'A' in status:
            change_type = 'added'
        elif 'D' in status:
            change_type = 'deleted'
        elif '?' in status:
            change_type = 'untracked'
        elif 'R' in status:
            change_type = 'renamed'
        elif 'C' in status:
            change_type = 'copied'
        else:
            change_type = 'unknown'
        
        files.append({
            'path': filepath,
            'change_type': change_type,
            'status': status.strip()
        })
    
    print(json.dumps(files, indent=2))

except subprocess.CalledProcessError:
    print("[]")
except Exception as e:
    print("[]")
EOF
}

# Funzione per salvare sessione enhanced
save_enhanced_session() {
    # Check if we should use coordinator (unless already in coordinator mode)
    if [[ -z "$MEMORY_COORD_MODE" ]]; then
        echo -e "${YELLOW}🚀 Requesting coordinated enhanced save...${NC}"
        local coord_params=""
        if [[ -n "$SESSION_NOTE" ]]; then coord_params+="$SESSION_NOTE "; fi
        if [[ -n "$CONVERSATION_SUMMARY" ]]; then coord_params+="$CONVERSATION_SUMMARY "; fi
        if [[ -n "$INCOMPLETE_TASKS" ]]; then coord_params+="$INCOMPLETE_TASKS "; fi
        if [[ -n "$NEXT_STEPS" ]]; then coord_params+="$NEXT_STEPS"; fi
        
        "$HOME/claude-workspace/scripts/claude-memory-coordinator.sh" request-save enhanced "claude-enhanced-save" normal $coord_params
        return $?
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local hostname=$(hostname)
    local active_project=$(detect_active_project)
    local working_dir=$(pwd | sed "s|$HOME|~|")
    local modified_files=$(analyze_modified_files)
    
    # Crea backup se esiste
    if [[ -f "$ENHANCED_MEMORY_FILE" ]]; then
        cp "$ENHANCED_MEMORY_FILE" "$ENHANCED_MEMORY_FILE.backup"
    fi
    
    # Crea o carica memoria enhanced
    local memory_content
    if [[ -f "$ENHANCED_MEMORY_FILE" ]]; then
        memory_content=$(cat "$ENHANCED_MEMORY_FILE")
    else
        memory_content='{
            "version": "2.0",
            "workspace_id": "claude-workspace-enhanced",
            "sessions": [],
            "settings": {
                "max_sessions": 100,
                "context_retention_days": 30,
                "auto_context_capture": true
            }
        }'
    fi
    
    # Salva con python per JSON manipulation
    python3 << EOF
import json
import sys
from datetime import datetime

try:
    # Carica memoria esistente
    memory = json.loads('''$memory_content''')
    
    # Crea nuova sessione
    new_session = {
        "id": "$timestamp-$hostname",
        "timestamp": "$timestamp",
        "device": "$hostname",
        "working_directory": "$working_dir",
        "active_project": json.loads('$active_project') if '$active_project' != "null" else None,
        "session_note": "$SESSION_NOTE" if "$SESSION_NOTE" else None,
        "conversation_summary": "$CONVERSATION_SUMMARY" if "$CONVERSATION_SUMMARY" else None,
        "incomplete_tasks": "$INCOMPLETE_TASKS".split("|||") if "$INCOMPLETE_TASKS" else [],
        "next_steps": "$NEXT_STEPS".split("|||") if "$NEXT_STEPS" else [],
        "modified_files": json.loads('''$modified_files'''),
        "git_status": {
            "branch": "$(git branch --show-current 2>/dev/null || echo 'unknown')",
            "has_changes": len(json.loads('''$modified_files''')) > 0,
            "last_commit": "$(git log -1 --format='%h: %s' 2>/dev/null || echo 'No commits')"
        },
        "context": {
            "todo_list_active": $(if [[ -f ~/claude-workspace/.claude/todo.json ]]; then echo "True"; else echo "False"; fi),
            "memory_system_active": True,
            "projects_count": len([d for d in __import__('os').listdir('$HOME/claude-workspace/projects/active') if not d.startswith('.')]) if __import__('os').path.exists('$HOME/claude-workspace/projects/active') else 0
        }
    }
    
    # Aggiungi alla lista sessioni
    memory["sessions"].insert(0, new_session)
    
    # Mantieni solo le ultime N sessioni
    max_sessions = memory.get("settings", {}).get("max_sessions", 100)
    memory["sessions"] = memory["sessions"][:max_sessions]
    
    # Salva file aggiornato
    with open("$ENHANCED_MEMORY_FILE", "w") as f:
        json.dump(memory, f, indent=2)
    
    # Salva anche context corrente per quick access
    with open("$SESSION_CONTEXT_FILE", "w") as f:
        json.dump(new_session, f, indent=2)
    
    print("✅ Enhanced session salvata con successo")
    
except Exception as e:
    print(f"❌ Errore nel salvare enhanced session: {e}")
    sys.exit(1)
EOF
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}🚀 Enhanced Session Salvata:${NC}"
        echo -e "${BLUE}   Device: ${NC}$hostname"
        echo -e "${BLUE}   Time: ${NC}$(date)"
        
        if [[ -n "$SESSION_NOTE" ]]; then
            echo -e "${BLUE}   Note: ${NC}$SESSION_NOTE"
        fi
        
        if [[ -n "$CONVERSATION_SUMMARY" ]]; then
            echo -e "${BLUE}   Summary: ${NC}$CONVERSATION_SUMMARY"
        fi
        
        if [[ -n "$INCOMPLETE_TASKS" ]]; then
            echo -e "${BLUE}   Tasks: ${NC}$(echo "$INCOMPLETE_TASKS" | tr '|||' ',')"
        fi
        
        if [[ -n "$NEXT_STEPS" ]]; then
            echo -e "${BLUE}   Next: ${NC}$(echo "$NEXT_STEPS" | tr '|||' ',')"
        fi
        
        local modified_count=$(echo "$modified_files" | python3 -c "import json,sys; print(len(json.load(sys.stdin)))")
        if [[ "$modified_count" -gt 0 ]]; then
            echo -e "${BLUE}   Files: ${NC}$modified_count modificati"
        fi
        
        # Log per auto-sync
        echo "[$(date)] Enhanced session salvata: $SESSION_NOTE" >> ~/claude-workspace/logs/sync.log
        
        return 0
    else
        echo -e "${RED}❌ Errore nel salvare enhanced session${NC}"
        return 1
    fi
}

# Funzione per caricare ultima sessione
load_last_session() {
    echo -e "${YELLOW}📖 Loading unified session context...${NC}"
    
    # Use coordinator for loading
    "$HOME/claude-workspace/scripts/claude-memory-coordinator.sh" load
    return $?
    
    # Legacy code (kept for reference)
    if false && [[ -f "$SESSION_CONTEXT_FILE" ]]; then
        echo -e "${YELLOW}📖 Ultima sessione salvata:${NC}"
        python3 << EOF
import json
import sys
from datetime import datetime

try:
    with open("$SESSION_CONTEXT_FILE", "r") as f:
        session = json.load(f)
    
    print(f"   📅 {session['timestamp']}")
    print(f"   💻 {session['device']}")
    
    if session.get('session_note'):
        print(f"   📝 {session['session_note']}")
    
    if session.get('conversation_summary'):
        print(f"   💬 {session['conversation_summary']}")
    
    if session.get('active_project'):
        proj = session['active_project']
        print(f"   📁 {proj['name']} ({proj['type']})")
    
    if session.get('incomplete_tasks'):
        print(f"   ⏳ Tasks: {', '.join(session['incomplete_tasks'])}")
    
    if session.get('next_steps'):
        print(f"   ➡️  Next: {', '.join(session['next_steps'])}")
    
    if session.get('modified_files'):
        count = len(session['modified_files'])
        if count > 0:
            print(f"   📄 {count} file modificati")

except Exception as e:
    print(f"❌ Errore nel caricare sessione: {e}")
EOF
    else
        echo -e "${YELLOW}📖 Nessuna sessione enhanced trovata${NC}"
    fi
}

# Mostra help
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Uso: claude-enhanced-save [nota] [summary] [tasks] [next_steps]"
    echo ""
    echo "Salva stato completo della sessione Claude con context"
    echo ""
    echo "Parametri:"
    echo "  nota           - Nota della sessione"
    echo "  summary        - Riassunto conversazione"
    echo "  tasks          - Task incomplete (separate da |||)"
    echo "  next_steps     - Prossimi passi (separati da |||)"
    echo ""
    echo "Esempi:"
    echo "  claude-enhanced-save \"Fix auth bug\""
    echo "  claude-enhanced-save \"API work\" \"Working on JWT\" \"Fix middleware|||Add tests\" \"Debug auth.js|||Run tests\""
    echo ""
    echo "Opzioni:"
    echo "  --load, -l     - Carica ultima sessione"
    echo "  --help, -h     - Mostra questo help"
    exit 0
fi

# Carica ultima sessione
if [[ "$1" == "--load" || "$1" == "-l" ]]; then
    load_last_session
    exit 0
fi

# Mostra status del sistema unificato
if [[ "$1" == "--status" || "$1" == "-s" ]]; then
    "$HOME/claude-workspace/scripts/claude-memory-coordinator.sh" status
    exit 0
fi

# Esegui salvataggio enhanced
echo -e "${YELLOW}🚀 Salvataggio enhanced session...${NC}"
save_enhanced_session