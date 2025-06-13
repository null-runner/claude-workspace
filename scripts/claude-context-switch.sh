#!/bin/bash
# Claude Context Switch - Salva/carica contesto quando cambi progetto
# Integrato con activity tracker e session manager

WORKSPACE_DIR="$HOME/claude-workspace"
CONTEXTS_DIR="$WORKSPACE_DIR/.claude/contexts"
ACTIVE_CONTEXT="$CONTEXTS_DIR/active-context.json"

# Scripts correlati
ACTIVITY_TRACKER="$WORKSPACE_DIR/scripts/claude-activity-tracker.sh"
SESSION_SAVE="$WORKSPACE_DIR/scripts/claude-enhanced-save.sh"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Crea directory
mkdir -p "$CONTEXTS_DIR"

# Funzione per salvare contesto corrente
save_context() {
    local project_name="$1"
    local reason="${2:-manual save}"
    
    if [[ -z "$project_name" ]]; then
        # Prova a rilevare progetto corrente
        if [[ -f "$WORKSPACE_DIR/.claude/activity/current-session.json" ]]; then
            project_name=$(python3 -c "import json; print(json.load(open('$WORKSPACE_DIR/.claude/activity/current-session.json'))['project_name'])" 2>/dev/null)
        fi
        
        if [[ -z "$project_name" ]]; then
            echo -e "${RED}❌ Nome progetto richiesto o nessuna sessione attiva${NC}"
            return 1
        fi
    fi
    
    echo -e "${YELLOW}💾 Salvando contesto per: $project_name${NC}"
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local context_file="$CONTEXTS_DIR/context-${project_name}-$(date +%s).json"
    
    # Raccogli informazioni contesto
    local current_dir=$(pwd)
    local git_branch=$(git branch --show-current 2>/dev/null || echo "none")
    local modified_files=$(git status --porcelain 2>/dev/null | wc -l)
    
    # Ottieni file aperti di recente nel progetto
    local recent_files=""
    if [[ -d "$WORKSPACE_DIR/projects/active/$project_name" ]]; then
        recent_files=$(find "$WORKSPACE_DIR/projects/active/$project_name" -type f -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.jsx" -o -name "*.tsx" -o -name "*.java" -o -name "*.go" 2>/dev/null | head -10)
    fi
    
    # Ottieni ultima sessione enhanced se esiste
    local last_session_summary=""
    local incomplete_tasks=""
    if [[ -f "$WORKSPACE_DIR/.claude/memory/current-session-context.json" ]]; then
        last_session_summary=$(python3 -c "import json; s=json.load(open('$WORKSPACE_DIR/.claude/memory/current-session-context.json')); print(s.get('conversation_summary', ''))" 2>/dev/null)
        incomplete_tasks=$(python3 -c "import json; s=json.load(open('$WORKSPACE_DIR/.claude/memory/current-session-context.json')); print('|||'.join(s.get('incomplete_tasks', [])))" 2>/dev/null)
    fi
    
    python3 << EOF
import json
import os
from datetime import datetime

context = {
    "project_name": "$project_name",
    "timestamp": "$timestamp",
    "reason": "$reason",
    "environment": {
        "working_directory": "$current_dir",
        "git_branch": "$git_branch",
        "modified_files_count": $modified_files,
        "device": "$(hostname)"
    },
    "session_info": {
        "last_summary": "$last_session_summary",
        "incomplete_tasks": "$incomplete_tasks".split("|||") if "$incomplete_tasks" else []
    },
    "recent_files": [f for f in """$recent_files""".strip().split('\n') if f],
    "mental_context": {
        "focus_area": None,
        "blockers": [],
        "next_steps": [],
        "notes": None
    }
}

# Salva contesto specifico del progetto
with open("$context_file", "w") as f:
    json.dump(context, f, indent=2)

# Aggiorna link al contesto attivo
if os.path.exists("$ACTIVE_CONTEXT"):
    os.remove("$ACTIVE_CONTEXT")
os.symlink(os.path.basename("$context_file"), "$ACTIVE_CONTEXT")

# Aggiorna indice contesti
index_file = "$CONTEXTS_DIR/index.json"
if os.path.exists(index_file):
    with open(index_file, "r") as f:
        index = json.load(f)
else:
    index = {"projects": {}}

if "$project_name" not in index["projects"]:
    index["projects"]["$project_name"] = {
        "contexts": [],
        "last_switch": None,
        "total_switches": 0
    }

index["projects"]["$project_name"]["contexts"].append({
    "file": os.path.basename("$context_file"),
    "timestamp": "$timestamp",
    "reason": "$reason"
})
index["projects"]["$project_name"]["last_switch"] = "$timestamp"
index["projects"]["$project_name"]["total_switches"] += 1

# Mantieni solo ultimi 10 contesti per progetto
index["projects"]["$project_name"]["contexts"] = index["projects"]["$project_name"]["contexts"][-10:]

with open(index_file, "w") as f:
    json.dump(index, f, indent=2)

print(f"✅ Contesto salvato: {os.path.basename('$context_file')}")
EOF
    
    # Trigger enhanced session save
    if [[ -f "$SESSION_SAVE" ]]; then
        "$SESSION_SAVE" "Context switch from $project_name" "Saving context before switching" "$incomplete_tasks" >/dev/null 2>&1
    fi
}

# Funzione per caricare contesto
load_context() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}❌ Nome progetto richiesto${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📂 Caricando contesto per: $project_name${NC}"
    
    python3 << EOF
import json
import os
from datetime import datetime

index_file = "$CONTEXTS_DIR/index.json"
if not os.path.exists(index_file):
    print("❌ Nessun contesto salvato trovato")
    exit(1)

with open(index_file, "r") as f:
    index = json.load(f)

if "$project_name" not in index["projects"]:
    print(f"❌ Nessun contesto trovato per progetto: $project_name")
    exit(1)

project_data = index["projects"]["$project_name"]
if not project_data["contexts"]:
    print(f"❌ Nessun contesto salvato per: $project_name")
    exit(1)

# Carica ultimo contesto
latest_context = project_data["contexts"][-1]
context_file = os.path.join("$CONTEXTS_DIR", latest_context["file"])

if not os.path.exists(context_file):
    print(f"❌ File contesto non trovato: {latest_context['file']}")
    exit(1)

with open(context_file, "r") as f:
    context = json.load(f)

print(f"\n📋 CONTESTO: {context['project_name']}")
print(f"📅 Salvato: {context['timestamp']}")
print(f"💻 Device: {context['environment']['device']}")
print(f"🌿 Branch: {context['environment']['git_branch']}")
print(f"📝 File modificati: {context['environment']['modified_files_count']}")

if context['session_info']['last_summary']:
    print(f"\n💬 Ultimo lavoro: {context['session_info']['last_summary']}")

if context['session_info']['incomplete_tasks']:
    print(f"\n⏳ Task incomplete:")
    for task in context['session_info']['incomplete_tasks']:
        if task:
            print(f"   • {task}")

if context['recent_files']:
    print(f"\n📄 File recenti:")
    for file in context['recent_files'][:5]:
        print(f"   • {os.path.basename(file)}")

print(f"\n✅ Contesto caricato. Pronto per riprendere il lavoro su {context['project_name']}")
EOF
    
    # Cambia directory se esiste
    local project_dir="$WORKSPACE_DIR/projects/active/$project_name"
    if [[ -d "$project_dir" ]]; then
        echo -e "${GREEN}📁 Cambiando directory a: $project_dir${NC}"
        cd "$project_dir"
    fi
}

# Funzione per switch automatico
auto_switch() {
    local new_project="$1"
    local reason="${2:-project change}"
    
    # Salva contesto corrente se c'è una sessione attiva
    if [[ -f "$WORKSPACE_DIR/.claude/activity/current-session.json" ]]; then
        local current_project=$(python3 -c "import json; print(json.load(open('$WORKSPACE_DIR/.claude/activity/current-session.json'))['project_name'])" 2>/dev/null)
        if [[ -n "$current_project" && "$current_project" != "$new_project" ]]; then
            echo -e "${YELLOW}🔄 Context switch: $current_project → $new_project${NC}"
            save_context "$current_project" "switching to $new_project"
            
            # Ferma tracking precedente
            if [[ -f "$ACTIVITY_TRACKER" ]]; then
                "$ACTIVITY_TRACKER" stop "Context switch to $new_project" >/dev/null 2>&1
            fi
        fi
    fi
    
    # Carica nuovo contesto se esiste
    load_context "$new_project"
    
    # Inizia nuovo tracking
    if [[ -f "$ACTIVITY_TRACKER" ]]; then
        "$ACTIVITY_TRACKER" start "$new_project" "active" "Resumed from context switch"
    fi
}

# Funzione per listare contesti
list_contexts() {
    if [[ ! -f "$CONTEXTS_DIR/index.json" ]]; then
        echo -e "${YELLOW}📂 Nessun contesto salvato${NC}"
        return 0
    fi
    
    echo -e "${CYAN}📚 CONTESTI SALVATI${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime

with open("$CONTEXTS_DIR/index.json", "r") as f:
    index = json.load(f)

if not index["projects"]:
    print("Nessun progetto con contesti salvati")
    exit(0)

for project_name, data in sorted(index["projects"].items()):
    print(f"📁 {project_name}")
    print(f"   Switches: {data['total_switches']}")
    print(f"   Ultimo: {data['last_switch']}")
    print(f"   Contesti salvati: {len(data['contexts'])}")
    print()
EOF
}

# Funzione per pulire vecchi contesti
cleanup_contexts() {
    local days="${1:-30}"
    
    echo -e "${YELLOW}🧹 Pulizia contesti più vecchi di $days giorni...${NC}"
    
    python3 << EOF
import json
import os
from datetime import datetime, timedelta

cutoff_date = datetime.now() - timedelta(days=$days)
removed_count = 0

# Pulisci file vecchi
for file in os.listdir("$CONTEXTS_DIR"):
    if file.startswith("context-") and file.endswith(".json"):
        file_path = os.path.join("$CONTEXTS_DIR", file)
        
        # Estrai timestamp dal nome file
        try:
            timestamp = int(file.split("-")[-1].replace(".json", ""))
            file_date = datetime.fromtimestamp(timestamp)
            
            if file_date < cutoff_date:
                os.remove(file_path)
                removed_count += 1
        except:
            pass

# Aggiorna indice
if os.path.exists("$CONTEXTS_DIR/index.json"):
    with open("$CONTEXTS_DIR/index.json", "r") as f:
        index = json.load(f)
    
    # Rimuovi riferimenti a file eliminati
    for project in index["projects"].values():
        project["contexts"] = [
            c for c in project["contexts"] 
            if os.path.exists(os.path.join("$CONTEXTS_DIR", c["file"]))
        ]
    
    with open("$CONTEXTS_DIR/index.json", "w") as f:
        json.dump(index, f, indent=2)

print(f"✅ Rimossi {removed_count} contesti vecchi")
EOF
}

# Help
show_help() {
    echo "Claude Context Switch - Gestione contesti per progetto"
    echo ""
    echo "Uso: claude-context-switch [comando] [parametri]"
    echo ""
    echo "Comandi:"
    echo "  save [progetto]       - Salva contesto corrente"
    echo "  load <progetto>       - Carica contesto progetto"
    echo "  switch <progetto>     - Switch automatico (salva corrente, carica nuovo)"
    echo "  list                  - Lista contesti salvati"
    echo "  cleanup [giorni]      - Rimuovi contesti vecchi (default: 30 giorni)"
    echo ""
    echo "Esempi:"
    echo "  claude-context-switch save"
    echo "  claude-context-switch switch api-gateway"
    echo "  claude-context-switch list"
}

# Main
case "$1" in
    "save")
        save_context "$2" "$3"
        ;;
    "load")
        load_context "$2"
        ;;
    "switch")
        auto_switch "$2" "$3"
        ;;
    "list")
        list_contexts
        ;;
    "cleanup")
        cleanup_contexts "$2"
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Comando sconosciuto: $1${NC}"
        show_help
        exit 1
        ;;
esac