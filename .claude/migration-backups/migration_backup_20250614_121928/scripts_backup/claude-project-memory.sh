#!/bin/bash
# Claude Workspace - Project Memory Management
# Gestisce memoria specifica per ogni progetto

MEMORY_BASE="$HOME/claude-workspace/.claude/memory"
PROJECT_MEMORY_DIR="$MEMORY_BASE/projects"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Funzione per rilevare progetto corrente
detect_current_project() {
    local current_dir=$(pwd)
    
    # Se siamo dentro un progetto
    if [[ "$current_dir" =~ claude-workspace/projects/ ]]; then
        local project_path=${current_dir#*claude-workspace/projects/}
        local project_type=$(echo "$project_path" | cut -d'/' -f1)
        local project_name=$(echo "$project_path" | cut -d'/' -f2)
        
        # Se siamo nella directory root del progetto o sottodirectory
        if [[ -n "$project_name" && -d "$HOME/claude-workspace/projects/$project_type/$project_name" ]]; then
            echo "$project_type/$project_name"
            return 0
        fi
    fi
    
    # Se non siamo in un progetto, cerca il più recente modificato
    return 1
}

# Funzione per creare memoria progetto se non esiste
init_project_memory() {
    local project_id="$1"
    local project_memory_file="$PROJECT_MEMORY_DIR/${project_id//\//_}.json"
    
    if [[ ! -f "$project_memory_file" ]]; then
        # Estrai info dal project_id
        local project_type=$(echo "$project_id" | cut -d'/' -f1)
        local project_name=$(echo "$project_id" | cut -d'/' -f2)
        
        # Crea memoria iniziale
        python3 << EOF
import json
import os
from datetime import datetime

project_name = "$project_name"
project_type = "$project_type" 
project_id = "$project_id"

project_memory = {
    "project_info": {
        "name": project_name,
        "type": project_type,
        "id": project_id,
        "created_at": datetime.utcnow().isoformat() + "Z",
        "path": f"~/claude-workspace/projects/{project_id}"
    },
    "current_context": {
        "last_activity": None,
        "current_task": None,
        "active_files": [],
        "notes": [],
        "todo": [],
        "completed": []
    },
    "session_history": [],
    "technical_notes": {
        "technologies": [],
        "dependencies": [],
        "architecture_notes": [],
        "setup_instructions": []
    },
    "goals": {
        "main_objective": None,
        "milestones": [],
        "current_milestone": None
    },
    "settings": {
        "auto_save": True,
        "retention": "infinite"
    }
}

# Crea directory se non esiste
os.makedirs("$PROJECT_MEMORY_DIR", exist_ok=True)

# Salva memoria iniziale
with open("$project_memory_file", "w") as f:
    json.dump(project_memory, f, indent=2)

print(f"✅ Memoria progetto inizializzata: {project_name}")
EOF
    fi
    
    echo "$project_memory_file"
}

# Funzione per salvare stato progetto
save_project_state() {
    local project_id="$1"
    local note="$2"
    local task="$3"
    
    if [[ -z "$project_id" ]]; then
        echo -e "${RED}❌ Progetto non rilevato${NC}"
        return 1
    fi
    
    local project_memory_file=$(init_project_memory "$project_id")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local hostname=$(hostname)
    local current_dir=$(pwd | sed "s|$HOME|~|")
    
    # Rileva file attivi (ultimamente modificati)
    local active_files=()
    if [[ -d "$HOME/claude-workspace/projects/$project_id" ]]; then
        local project_dir="$HOME/claude-workspace/projects/$project_id"
        
        # Trova file modificati negli ultimi 30 minuti
        while IFS= read -r -d '' file; do
            local rel_file=${file#$project_dir/}
            # Escludi file di sistema
            if [[ ! "$rel_file" =~ ^(\.|venv|node_modules|__pycache__|\.git) ]]; then
                active_files+=("\"$rel_file\"")
            fi
        done < <(find "$project_dir" -type f -mmin -30 -print0 2>/dev/null | head -20)
    fi
    
    # Aggiorna memoria progetto
    python3 << EOF
import json
import sys
from datetime import datetime

try:
    # Carica memoria esistente
    with open("$project_memory_file", "r") as f:
        memory = json.load(f)
    
    # Salva sessione corrente nello storico
    if memory.get("current_context", {}).get("last_activity"):
        session = {
            "timestamp": memory["current_context"]["last_activity"],
            "device": memory["current_context"].get("device", "unknown"),
            "task": memory["current_context"].get("current_task"),
            "note": memory["current_context"].get("notes", [])[-1] if memory["current_context"].get("notes") else None,
            "working_directory": memory["current_context"].get("working_directory"),
            "ended_at": "$timestamp"
        }
        memory["session_history"].insert(0, session)
        # Mantieni ultimi 50 record
        memory["session_history"] = memory["session_history"][:50]
    
    # Aggiorna context corrente
    memory["current_context"].update({
        "last_activity": "$timestamp",
        "device": "$hostname",
        "current_task": "$task" if "$task" else memory["current_context"].get("current_task"),
        "working_directory": "$current_dir",
        "active_files": [$(IFS=,; echo "${active_files[*]}")],
        "last_save_note": "$note" if "$note" else None
    })
    
    # Aggiungi nota se presente
    if "$note":
        if "notes" not in memory["current_context"]:
            memory["current_context"]["notes"] = []
        memory["current_context"]["notes"].insert(0, {
            "timestamp": "$timestamp",
            "device": "$hostname",
            "content": "$note"
        })
        # Mantieni ultime 20 note
        memory["current_context"]["notes"] = memory["current_context"]["notes"][:20]
    
    # Salva
    with open("$project_memory_file", "w") as f:
        json.dump(memory, f, indent=2)
    
    print("✅ Stato progetto salvato")
    
except Exception as e:
    print(f"❌ Errore nel salvare stato progetto: {e}")
    sys.exit(1)
EOF
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}📝 Progetto: ${NC}$(echo "$project_id" | cut -d'/' -f2)"
        echo -e "${BLUE}   Device: ${NC}$hostname"
        echo -e "${BLUE}   Time: ${NC}$(date)"
        
        if [[ -n "$note" ]]; then
            echo -e "${BLUE}   Note: ${NC}$note"
        fi
        
        if [[ -n "$task" ]]; then
            echo -e "${BLUE}   Task: ${NC}$task"
        fi
        
        if [[ ${#active_files[@]} -gt 0 ]]; then
            echo -e "${BLUE}   File attivi: ${NC}${#active_files[@]} file"
        fi
    fi
}

# Funzione per riprendere progetto
resume_project() {
    local project_id="$1"
    
    if [[ -z "$project_id" ]]; then
        project_id=$(detect_current_project)
        if [[ -z "$project_id" ]]; then
            echo -e "${RED}❌ Nessun progetto rilevato${NC}"
            echo "💡 Usa: claude-project-memory resume <tipo>/<nome>"
            return 1
        fi
    fi
    
    local project_memory_file="$PROJECT_MEMORY_DIR/${project_id//\//_}.json"
    
    if [[ ! -f "$project_memory_file" ]]; then
        echo -e "${YELLOW}⚠️  Nessuna memoria trovata per: $(echo "$project_id" | cut -d'/' -f2)${NC}"
        echo "💡 Inizializza con: claude-project-memory save"
        return 1
    fi
    
    echo -e "${BLUE}🧠 MEMORIA PROGETTO: $(echo "$project_id" | cut -d'/' -f2)${NC}"
    echo "======================================"
    
    python3 << 'EOF'
import json
import sys
from datetime import datetime, timezone

try:
    project_id = "$project_id"
    memory_file = "$project_memory_file"
    
    with open(memory_file, "r") as f:
        memory = json.load(f)
    
    # Info progetto
    project_info = memory.get("project_info", {})
    print(f"\n📁 PROGETTO: {project_info.get('name', 'N/A')}")
    print(f"   Tipo: {project_info.get('type', 'N/A')}")
    print(f"   Path: {project_info.get('path', 'N/A')}")
    
    # Context corrente
    context = memory.get("current_context", {})
    if context:
        print(f"\n📍 ULTIMA SESSIONE:")
        
        if context.get("last_activity"):
            # Calcola tempo trascorso
            last_time = datetime.fromisoformat(context['last_activity'].replace('Z', '+00:00'))
            now = datetime.now(timezone.utc)
            diff = now - last_time
            
            if diff.days > 0:
                time_ago = f"{diff.days} giorni fa"
            elif diff.seconds > 3600:
                hours = diff.seconds // 3600
                time_ago = f"{hours} ore fa"
            elif diff.seconds > 60:
                minutes = diff.seconds // 60
                time_ago = f"{minutes} minuti fa"
            else:
                time_ago = "Pochi secondi fa"
            
            print(f"   Quando: {time_ago} ({context.get('device', 'N/A')})")
        
        if context.get("current_task"):
            print(f"   Task corrente: {context['current_task']}")
        
        if context.get("last_save_note"):
            print(f"   Ultima nota: {context['last_save_note']}")
        
        # Note recenti
        notes = context.get("notes", [])
        if notes:
            print(f"\n📝 NOTE RECENTI:")
            for i, note in enumerate(notes[:3]):
                content = note.get('content', 'N/A')
                device = note.get('device', 'N/A')
                print(f"   {i+1}. {content} ({device})")
        
        # File attivi
        active_files = context.get("active_files", [])
        if active_files:
            print(f"\n📄 FILE ATTIVI:")
            for i, file in enumerate(active_files[:5]):
                print(f"   {i+1}. {file}")
            if len(active_files) > 5:
                print(f"   ... e altri {len(active_files)-5} file")
        
        # TODO
        todo = context.get("todo", [])
        if todo:
            print(f"\n📋 TODO:")
            for i, task in enumerate(todo[:3]):
                status = "⏳" if task.get('status') == 'pending' else "✅"
                print(f"   {status} {task.get('description', 'N/A')}")
    
    # Obiettivi
    goals = memory.get("goals", {})
    if goals.get("main_objective"):
        print(f"\n🎯 OBIETTIVO PRINCIPALE:")
        print(f"   {goals['main_objective']}")
    
    # Milestone corrente
    if goals.get("current_milestone"):
        print(f"\n🚀 MILESTONE CORRENTE:")
        print(f"   {goals['current_milestone']}")
    
    # Suggerimento navigazione
    print(f"\n💡 Per riprendere il lavoro:")
    print(f"   cd ~/claude-workspace/projects/{project_id}")
    if active_files:
        print(f"   # Poi apri: {active_files[0] if active_files else 'file recenti'}")

except Exception as e:
    print(f"❌ Errore nel leggere memoria progetto: {e}")
    sys.exit(1)
EOF
}

# Funzione per gestire TODO progetto
manage_todo() {
    local project_id="$1"
    local action="$2"
    shift 2
    local description="$*"
    
    if [[ -z "$project_id" ]]; then
        project_id=$(detect_current_project)
    fi
    
    if [[ -z "$project_id" ]]; then
        echo -e "${RED}❌ Progetto non rilevato${NC}"
        return 1
    fi
    
    local project_memory_file=$(init_project_memory "$project_id")
    
    case "$action" in
        "add")
            if [[ -z "$description" ]]; then
                echo "Uso: todo add <descrizione>"
                return 1
            fi
            
            python3 << EOF
import json
from datetime import datetime

with open("$project_memory_file", "r") as f:
    memory = json.load(f)

if "todo" not in memory["current_context"]:
    memory["current_context"]["todo"] = []

new_todo = {
    "id": len(memory["current_context"]["todo"]) + 1,
    "description": "$description",
    "status": "pending",
    "created_at": datetime.utcnow().isoformat() + "Z",
    "device": "$(hostname)"
}

memory["current_context"]["todo"].append(new_todo)

with open("$project_memory_file", "w") as f:
    json.dump(memory, f, indent=2)

print("✅ TODO aggiunto: $description")
EOF
            ;;
        "list")
            python3 << 'EOF'
import json

try:
    with open("$project_memory_file", "r") as f:
        memory = json.load(f)
    
    todos = memory.get("current_context", {}).get("todo", [])
    completed = memory.get("current_context", {}).get("completed", [])
    
    if todos:
        print("📋 TODO ATTIVI:")
        for todo in todos:
            status = "⏳" if todo.get('status') == 'pending' else "✅"
            print(f"   {todo.get('id', '?')}. {status} {todo.get('description', 'N/A')}")
    
    if completed:
        print(f"\n✅ COMPLETATI ({len(completed)}):")
        for todo in completed[-3:]:  # Ultimi 3
            print(f"   ✅ {todo.get('description', 'N/A')}")

except Exception as e:
    print(f"❌ Errore: {e}")
EOF
            ;;
        "done")
            if [[ -z "$description" ]]; then
                echo "Uso: todo done <id>"
                return 1
            fi
            
            python3 << EOF
import json
from datetime import datetime

with open("$project_memory_file", "r") as f:
    memory = json.load(f)

todos = memory.get("current_context", {}).get("todo", [])
todo_id = int("$description")

# Trova e rimuovi TODO
todo_to_complete = None
for i, todo in enumerate(todos):
    if todo.get("id") == todo_id:
        todo_to_complete = todos.pop(i)
        break

if todo_to_complete:
    # Sposta in completed
    if "completed" not in memory["current_context"]:
        memory["current_context"]["completed"] = []
    
    todo_to_complete["completed_at"] = datetime.utcnow().isoformat() + "Z"
    todo_to_complete["status"] = "completed"
    memory["current_context"]["completed"].insert(0, todo_to_complete)
    
    # Mantieni solo ultimi 20 completed
    memory["current_context"]["completed"] = memory["current_context"]["completed"][:20]
    
    with open("$project_memory_file", "w") as f:
        json.dump(memory, f, indent=2)
    
    print(f"✅ TODO completato: {todo_to_complete.get('description', 'N/A')}")
else:
    print(f"❌ TODO {todo_id} non trovato")
EOF
            ;;
        *)
            echo "Azioni disponibili: add, list, done"
            ;;
    esac
}

# Main script
case "$1" in
    "save")
        project_id=$(detect_current_project)
        save_project_state "$project_id" "$2" "$3"
        ;;
    "resume")
        resume_project "$2"
        ;;
    "todo")
        project_id=$(detect_current_project)
        manage_todo "$project_id" "$2" "${@:3}"
        ;;
    "list")
        echo -e "${BLUE}📁 PROGETTI CON MEMORIA:${NC}"
        if [[ -d "$PROJECT_MEMORY_DIR" ]]; then
            for file in "$PROJECT_MEMORY_DIR"/*.json; do
                if [[ -f "$file" ]]; then
                    basename=$(basename "$file" .json)
                    project_id=${basename//_/\/}
                    echo "   - $project_id"
                fi
            done
        else
            echo "   Nessun progetto con memoria"
        fi
        ;;
    "--help"|"-h")
        echo "Uso: claude-project-memory [comando] [opzioni]"
        echo ""
        echo "Comandi:"
        echo "  save [nota] [task]     Salva stato progetto corrente"
        echo "  resume [progetto]      Riprendi progetto"
        echo "  todo add <desc>        Aggiungi TODO"
        echo "  todo list              Lista TODO"
        echo "  todo done <id>         Completa TODO"
        echo "  list                   Lista progetti con memoria"
        ;;
    *)
        # Auto-detect e resume
        project_id=$(detect_current_project)
        if [[ -n "$project_id" ]]; then
            resume_project "$project_id"
        else
            echo "Uso: claude-project-memory --help"
        fi
        ;;
esac