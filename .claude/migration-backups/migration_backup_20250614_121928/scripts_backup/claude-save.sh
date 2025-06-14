#!/bin/bash
# Claude Workspace - Save Session Script
# Salva lo stato corrente della sessione

MEMORY_DIR="$HOME/claude-workspace/.claude/memory"
MEMORY_FILE="$MEMORY_DIR/workspace-memory.json"
SESSION_NOTE="$1"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Verifica permessi Claude
if [[ ! -f ~/.claude-access/ACTIVE ]]; then
    echo "⚠️  Claude non attivo. Uso modalità read-only..."
fi

# Funzione per aggiornare timestamp
update_timestamp() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "$timestamp"
}

# Funzione per rilevare progetto attivo
detect_active_project() {
    local current_dir=$(pwd)
    
    # Se siamo in un progetto
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
    local last_project=$(find ~/claude-workspace/projects -name "*.py" -o -name "*.js" -o -name "*.md" -type f -exec stat -f "%m %N" {} + 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)
    
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

# Funzione per salvare sessione
save_session() {
    local timestamp=$(update_timestamp)
    local hostname=$(hostname)
    local active_project=$(detect_active_project)
    local working_dir=$(pwd | sed "s|$HOME|~|")
    
    # Crea backup del file esistente
    if [[ -f "$MEMORY_FILE" ]]; then
        cp "$MEMORY_FILE" "$MEMORY_FILE.backup"
    fi
    
    # Legge memoria esistente o crea nuova
    local memory_content
    if [[ -f "$MEMORY_FILE" ]]; then
        memory_content=$(cat "$MEMORY_FILE")
    else
        memory_content='{
            "version": "1.0",
            "workspace_id": "claude-workspace-nullrunner",
            "devices": {},
            "current_session": {},
            "recent_projects": [],
            "session_history": [],
            "context": {},
            "settings": {
                "auto_save_interval": 300,
                "max_history_days": 30,
                "context_retention": "detailed"
            }
        }'
    fi
    
    # Aggiorna con python per manipolazione JSON sicura
    python3 << EOF
import json
import sys
from datetime import datetime

try:
    # Carica memoria esistente
    memory = json.loads('''$memory_content''')
    
    # Aggiorna device corrente
    memory["devices"]["$hostname"] = {
        "type": "desktop" if "$hostname" == "NEURAL-X" else "laptop",
        "last_seen": "$timestamp",
        "active": True
    }
    
    # Segna altri device come non attivi
    for device in memory["devices"]:
        if device != "$hostname":
            memory["devices"][device]["active"] = False
    
    # Salva sessione precedente nello storico
    if "current_session" in memory and memory["current_session"]:
        prev_session = memory["current_session"].copy()
        prev_session["ended_at"] = "$timestamp"
        memory["session_history"].insert(0, prev_session)
        
        # Mantieni solo ultimi 50 record
        memory["session_history"] = memory["session_history"][:50]
    
    # Aggiorna sessione corrente
    memory["current_session"] = {
        "started_at": "$timestamp",
        "device": "$hostname",
        "last_activity": "$timestamp",
        "active_project": json.loads('$active_project') if '$active_project' != "null" else None,
        "working_directory": "$working_dir",
        "last_command": "claude-save",
        "session_note": "$SESSION_NOTE" if "$SESSION_NOTE" else None
    }
    
    # Aggiorna progetti recenti se c'è un progetto attivo
    if '$active_project' != "null":
        project = json.loads('$active_project')
        # Rimuovi se già presente
        memory["recent_projects"] = [p for p in memory["recent_projects"] if p.get("name") != project["name"]]
        # Aggiungi in cima
        project["last_accessed"] = "$timestamp"
        project["device"] = "$hostname"
        memory["recent_projects"].insert(0, project)
        # Mantieni solo ultimi 10
        memory["recent_projects"] = memory["recent_projects"][:10]
    
    # Salva file aggiornato
    with open("$MEMORY_FILE", "w") as f:
        json.dump(memory, f, indent=2)
    
    print("✅ Sessione salvata con successo")
    
except Exception as e:
    print(f"❌ Errore nel salvare la sessione: {e}")
    sys.exit(1)
EOF
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}📝 Sessione salvata:${NC}"
        echo -e "${BLUE}   Device: ${NC}$hostname"
        echo -e "${BLUE}   Time: ${NC}$(date)"
        
        if [[ -n "$SESSION_NOTE" ]]; then
            echo -e "${BLUE}   Note: ${NC}$SESSION_NOTE"
        fi
        
        if [[ "$active_project" != "null" ]]; then
            local project_name=$(echo "$active_project" | python3 -c "import json,sys; print(json.load(sys.stdin)['name'])" 2>/dev/null)
            if [[ -n "$project_name" ]]; then
                echo -e "${BLUE}   Progetto: ${NC}$project_name"
            fi
        fi
        
        # Log per auto-sync
        echo "[$(date)] Sessione salvata: $SESSION_NOTE" >> ~/claude-workspace/logs/sync.log
    else
        echo "❌ Errore nel salvare la sessione"
        return 1
    fi
}

# Mostra help se richiesto
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    echo "Uso: claude-save [nota]"
    echo ""
    echo "Salva lo stato corrente della sessione Claude"
    echo ""
    echo "Esempi:"
    echo "  claude-save                              # Salva sessione corrente"
    echo "  claude-save \"Lavorando su homepage\"     # Salva con nota"
    echo "  claude-save \"TODO: aggiungere tests\"   # Salva promemoria"
    exit 0
fi

# Esegui salvataggio
echo -e "${YELLOW}💾 Salvataggio sessione...${NC}"
save_session