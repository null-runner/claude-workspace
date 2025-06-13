#!/bin/bash
# Claude Activity Tracker - Traccia tempo speso per progetto
# Monitora attività e genera report tempo per progetto

WORKSPACE_DIR="$HOME/claude-workspace"
ACTIVITY_LOG="$WORKSPACE_DIR/.claude/activity/activity.log"
ACTIVITY_DB="$WORKSPACE_DIR/.claude/activity/activity.json"
CURRENT_SESSION="$WORKSPACE_DIR/.claude/activity/current-session.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Crea directory se non esiste
mkdir -p "$WORKSPACE_DIR/.claude/activity"

# Funzione per iniziare tracking
start_tracking() {
    local project_name="$1"
    local project_type="${2:-active}"
    local task_description="$3"
    
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}❌ Nome progetto richiesto${NC}"
        echo "Uso: claude-activity-tracker start <nome-progetto> [tipo] [descrizione]"
        return 1
    fi
    
    # Verifica se c'è già una sessione attiva
    if [[ -f "$CURRENT_SESSION" ]]; then
        local active_project=$(python3 -c "import json; print(json.load(open('$CURRENT_SESSION'))['project_name'])" 2>/dev/null)
        if [[ -n "$active_project" ]]; then
            echo -e "${YELLOW}⚠️  Sessione già attiva per: $active_project${NC}"
            echo "Vuoi fermarla e iniziare una nuova? (y/n)"
            read -r response
            if [[ "$response" == "y" || "$response" == "Y" ]]; then
                stop_tracking "Switching to $project_name"
            else
                return 1
            fi
        fi
    fi
    
    # Crea sessione
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local session_id="$(date +%s)-$project_name"
    
    python3 << EOF
import json
from datetime import datetime

session = {
    "session_id": "$session_id",
    "project_name": "$project_name",
    "project_type": "$project_type",
    "task_description": "$task_description" if "$task_description" else None,
    "start_time": "$timestamp",
    "start_timestamp": $(date +%s),
    "device": "$(hostname)",
    "active": True
}

with open("$CURRENT_SESSION", "w") as f:
    json.dump(session, f, indent=2)

print("✅ Tracking iniziato per: $project_name")
EOF
    
    # Log evento
    echo "[$(date)] START tracking: $project_name ($project_type) - $task_description" >> "$ACTIVITY_LOG"
    
    echo -e "${GREEN}🏃 Tracking attivo per:${NC} $project_name"
    if [[ -n "$task_description" ]]; then
        echo -e "${BLUE}📋 Task:${NC} $task_description"
    fi
}

# Funzione per fermare tracking
stop_tracking() {
    local notes="$1"
    
    if [[ ! -f "$CURRENT_SESSION" ]]; then
        echo -e "${RED}❌ Nessuna sessione attiva${NC}"
        return 1
    fi
    
    local end_timestamp=$(date +%s)
    local end_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    python3 << EOF
import json
from datetime import datetime, timedelta

# Carica sessione corrente
with open("$CURRENT_SESSION", "r") as f:
    session = json.load(f)

# Calcola durata
start_ts = session["start_timestamp"]
end_ts = $end_timestamp
duration_seconds = end_ts - start_ts
duration_minutes = duration_seconds // 60
duration_hours = duration_minutes / 60

# Aggiorna sessione
session["end_time"] = "$end_time"
session["end_timestamp"] = end_ts
session["duration_seconds"] = duration_seconds
session["duration_minutes"] = duration_minutes
session["duration_hours"] = round(duration_hours, 2)
session["notes"] = "$notes" if "$notes" else None
session["active"] = False

# Carica o crea database
try:
    with open("$ACTIVITY_DB", "r") as f:
        db = json.load(f)
except:
    db = {
        "version": "1.0",
        "sessions": [],
        "projects": {},
        "total_time": {
            "seconds": 0,
            "minutes": 0,
            "hours": 0
        }
    }

# Aggiungi sessione
db["sessions"].append(session)

# Aggiorna statistiche progetto
project_name = session["project_name"]
if project_name not in db["projects"]:
    db["projects"][project_name] = {
        "total_seconds": 0,
        "total_minutes": 0,
        "total_hours": 0,
        "session_count": 0,
        "last_activity": None,
        "created": session["start_time"]
    }

db["projects"][project_name]["total_seconds"] += duration_seconds
db["projects"][project_name]["total_minutes"] += duration_minutes
db["projects"][project_name]["total_hours"] = round(
    db["projects"][project_name]["total_seconds"] / 3600, 2
)
db["projects"][project_name]["session_count"] += 1
db["projects"][project_name]["last_activity"] = "$end_time"

# Aggiorna totali globali
db["total_time"]["seconds"] += duration_seconds
db["total_time"]["minutes"] = db["total_time"]["seconds"] // 60
db["total_time"]["hours"] = round(db["total_time"]["seconds"] / 3600, 2)

# Salva database
with open("$ACTIVITY_DB", "w") as f:
    json.dump(db, f, indent=2)

# Rimuovi sessione corrente
import os
os.remove("$CURRENT_SESSION")

# Report
print(f"⏹️  Tracking fermato per: {project_name}")
print(f"⏱️  Durata: {duration_minutes} minuti ({round(duration_hours, 1)} ore)")
print(f"💾 Sessione salvata")
EOF
    
    # Log evento
    echo "[$(date)] STOP tracking - Duration logged" >> "$ACTIVITY_LOG"
}

# Funzione per mostrare status
show_status() {
    if [[ -f "$CURRENT_SESSION" ]]; then
        echo -e "${CYAN}📊 Activity Tracker Status${NC}"
        python3 << EOF
import json
from datetime import datetime

with open("$CURRENT_SESSION", "r") as f:
    session = json.load(f)

now = datetime.now().timestamp()
start = session["start_timestamp"]
duration_minutes = (now - start) // 60

print(f"🏃 Tracking attivo: {session['project_name']}")
print(f"⏱️  Tempo trascorso: {duration_minutes} minuti")
if session.get("task_description"):
    print(f"📋 Task: {session['task_description']}")
print(f"🕐 Iniziato: {session['start_time']}")
EOF
    else
        echo -e "${YELLOW}💤 Nessuna sessione attiva${NC}"
    fi
}

# Funzione per report
generate_report() {
    local filter_project="$1"
    
    if [[ ! -f "$ACTIVITY_DB" ]]; then
        echo -e "${RED}❌ Nessun dato di attività trovato${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📊 Activity Report${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime, timedelta

with open("$ACTIVITY_DB", "r") as f:
    db = json.load(f)

filter_project = "$filter_project" if "$filter_project" else None

# Report totale
if not filter_project:
    print(f"⏰ Tempo totale trackato: {db['total_time']['hours']} ore")
    print(f"📁 Progetti totali: {len(db['projects'])}")
    print(f"📊 Sessioni totali: {len(db['sessions'])}")
    print("")

# Report per progetto
print("📂 PROGETTI:")
print("=" * 60)

projects_to_show = [filter_project] if filter_project and filter_project in db["projects"] else db["projects"].keys()

for project_name in sorted(projects_to_show):
    project = db["projects"][project_name]
    print(f"\n🔸 {project_name}")
    print(f"   ⏱️  Tempo totale: {project['total_hours']} ore ({project['total_minutes']} min)")
    print(f"   📊 Sessioni: {project['session_count']}")
    print(f"   📅 Ultima attività: {project['last_activity']}")
    
    # Mostra ultime 3 sessioni per questo progetto
    recent_sessions = [s for s in db["sessions"] if s["project_name"] == project_name][-3:]
    if recent_sessions:
        print(f"   📜 Sessioni recenti:")
        for sess in reversed(recent_sessions):
            task = f" - {sess['task_description']}" if sess.get('task_description') else ""
            print(f"      • {sess['duration_minutes']} min{task}")

print("\n" + "=" * 60)

# Top 5 progetti per tempo
if not filter_project and len(db["projects"]) > 1:
    print("\n🏆 TOP 5 PROGETTI PER TEMPO:")
    sorted_projects = sorted(db["projects"].items(), key=lambda x: x[1]["total_hours"], reverse=True)[:5]
    for i, (name, data) in enumerate(sorted_projects, 1):
        print(f"   {i}. {name}: {data['total_hours']} ore")
EOF
}

# Funzione per esportare dati
export_data() {
    local format="${1:-json}"
    local output_file="${2:-activity-export}"
    
    if [[ ! -f "$ACTIVITY_DB" ]]; then
        echo -e "${RED}❌ Nessun dato da esportare${NC}"
        return 1
    fi
    
    case "$format" in
        "csv")
            python3 << EOF
import json
import csv
from datetime import datetime

with open("$ACTIVITY_DB", "r") as f:
    db = json.load(f)

# Esporta sessioni come CSV
with open("${output_file}.csv", "w", newline="") as csvfile:
    fieldnames = ["session_id", "project_name", "start_time", "end_time", 
                  "duration_minutes", "task_description", "notes"]
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    
    writer.writeheader()
    for session in db["sessions"]:
        writer.writerow({
            "session_id": session["session_id"],
            "project_name": session["project_name"],
            "start_time": session["start_time"],
            "end_time": session.get("end_time", ""),
            "duration_minutes": session.get("duration_minutes", 0),
            "task_description": session.get("task_description", ""),
            "notes": session.get("notes", "")
        })

print("✅ Esportato in ${output_file}.csv")
EOF
            ;;
        "json")
            cp "$ACTIVITY_DB" "${output_file}.json"
            echo -e "${GREEN}✅ Esportato in ${output_file}.json${NC}"
            ;;
        *)
            echo -e "${RED}❌ Formato non supportato: $format${NC}"
            echo "Formati supportati: json, csv"
            return 1
            ;;
    esac
}

# Help
show_help() {
    echo "Claude Activity Tracker - Traccia tempo per progetto"
    echo ""
    echo "Uso: claude-activity-tracker [comando] [parametri]"
    echo ""
    echo "Comandi:"
    echo "  start <progetto> [tipo] [task]  - Inizia tracking per progetto"
    echo "  stop [note]                      - Ferma tracking corrente"
    echo "  status                           - Mostra sessione attiva"
    echo "  report [progetto]                - Genera report attività"
    echo "  export [formato] [file]          - Esporta dati (json/csv)"
    echo "  help                             - Mostra questo help"
    echo ""
    echo "Esempi:"
    echo "  claude-activity-tracker start api-gateway active \"Implementing auth\""
    echo "  claude-activity-tracker stop \"Completed JWT integration\""
    echo "  claude-activity-tracker report"
    echo "  claude-activity-tracker export csv my-activity"
}

# Main
case "$1" in
    "start")
        start_tracking "$2" "$3" "$4"
        ;;
    "stop")
        stop_tracking "$2"
        ;;
    "status")
        show_status
        ;;
    "report")
        generate_report "$2"
        ;;
    "export")
        export_data "$2" "$3"
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