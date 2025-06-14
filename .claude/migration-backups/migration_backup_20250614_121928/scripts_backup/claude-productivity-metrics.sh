#!/bin/bash
# Claude Productivity Metrics - Traccia e analizza produttività
# Genera report settimanali/mensili su task completate e metriche

WORKSPACE_DIR="$HOME/claude-workspace"
METRICS_DB="$WORKSPACE_DIR/.claude/metrics/productivity.json"
TASKS_LOG="$WORKSPACE_DIR/.claude/metrics/tasks.log"
WEEKLY_REPORTS="$WORKSPACE_DIR/.claude/metrics/weekly-reports"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Crea directory
mkdir -p "$WORKSPACE_DIR/.claude/metrics"
mkdir -p "$WEEKLY_REPORTS"

# Funzione per loggare task completata
log_task() {
    local task_name="$1"
    local project="$2"
    local task_type="${3:-feature}"  # feature, bugfix, refactor, docs, test
    local complexity="${4:-medium}"    # simple, medium, complex
    local time_spent="${5:-0}"        # minuti
    
    if [[ -z "$task_name" ]]; then
        echo -e "${RED}❌ Nome task richiesto${NC}"
        echo "Uso: claude-productivity-metrics log <task> <progetto> [tipo] [complessità] [tempo]"
        return 1
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local week_number=$(date +%V)
    local year=$(date +%Y)
    local task_id="task-$(date +%s)-$(echo $RANDOM)"
    
    # Punteggio basato su complessità
    local points=0
    case "$complexity" in
        "simple") points=1 ;;
        "medium") points=3 ;;
        "complex") points=5 ;;
    esac
    
    python3 << EOF
import json
import os
from datetime import datetime

# Carica o crea database
db_path = "$METRICS_DB"
if os.path.exists(db_path):
    with open(db_path, "r") as f:
        db = json.load(f)
else:
    db = {
        "version": "1.0",
        "tasks": [],
        "projects": {},
        "weekly_stats": {},
        "task_types": {
            "feature": {"count": 0, "points": 0},
            "bugfix": {"count": 0, "points": 0},
            "refactor": {"count": 0, "points": 0},
            "docs": {"count": 0, "points": 0},
            "test": {"count": 0, "points": 0}
        },
        "total_stats": {
            "tasks_completed": 0,
            "total_points": 0,
            "total_time_minutes": 0
        }
    }

# Crea task
task = {
    "id": "$task_id",
    "name": "$task_name",
    "project": "$project",
    "type": "$task_type",
    "complexity": "$complexity",
    "points": $points,
    "time_spent_minutes": $time_spent,
    "timestamp": "$timestamp",
    "week": "$week_number",
    "year": "$year",
    "device": "$(hostname)"
}

# Aggiungi task
db["tasks"].append(task)

# Aggiorna statistiche progetto
if "$project" not in db["projects"]:
    db["projects"]["$project"] = {
        "tasks_count": 0,
        "total_points": 0,
        "total_time_minutes": 0,
        "task_types": {}
    }

db["projects"]["$project"]["tasks_count"] += 1
db["projects"]["$project"]["total_points"] += $points
db["projects"]["$project"]["total_time_minutes"] += $time_spent

# Aggiorna task types per progetto
if "$task_type" not in db["projects"]["$project"]["task_types"]:
    db["projects"]["$project"]["task_types"]["$task_type"] = 0
db["projects"]["$project"]["task_types"]["$task_type"] += 1

# Aggiorna statistiche settimanali
week_key = f"{$year}-W{$week_number}"
if week_key not in db["weekly_stats"]:
    db["weekly_stats"][week_key] = {
        "tasks": 0,
        "points": 0,
        "time_minutes": 0,
        "projects_touched": set(),
        "daily_tasks": {}
    }

db["weekly_stats"][week_key]["tasks"] += 1
db["weekly_stats"][week_key]["points"] += $points
db["weekly_stats"][week_key]["time_minutes"] += $time_spent
db["weekly_stats"][week_key]["projects_touched"] = list(
    set(db["weekly_stats"][week_key].get("projects_touched", [])) | {"$project"}
)

# Task giornaliere
day_key = datetime.now().strftime("%Y-%m-%d")
if day_key not in db["weekly_stats"][week_key]["daily_tasks"]:
    db["weekly_stats"][week_key]["daily_tasks"][day_key] = 0
db["weekly_stats"][week_key]["daily_tasks"][day_key] += 1

# Aggiorna task types globali
db["task_types"]["$task_type"]["count"] += 1
db["task_types"]["$task_type"]["points"] += $points

# Aggiorna totali
db["total_stats"]["tasks_completed"] += 1
db["total_stats"]["total_points"] += $points
db["total_stats"]["total_time_minutes"] += $time_spent

# Salva database
with open(db_path, "w") as f:
    json.dump(db, f, indent=2)

print(f"✅ Task loggata: {task['name']}")
print(f"📊 Punti: {$points} | Tempo: {$time_spent} min")
EOF
    
    # Log testuale
    echo "[$(date)] TASK_COMPLETED: $task_name | Project: $project | Type: $task_type | Complexity: $complexity | Time: $time_spent min" >> "$TASKS_LOG"
}

# Funzione per generare report settimanale
generate_weekly_report() {
    local week="${1:-current}"
    
    if [[ ! -f "$METRICS_DB" ]]; then
        echo -e "${RED}❌ Nessun dato di produttività trovato${NC}"
        return 1
    fi
    
    if [[ "$week" == "current" ]]; then
        week="$(date +%Y)-W$(date +%V)"
    fi
    
    echo -e "${CYAN}📊 PRODUCTIVITY REPORT - Week $week${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime, timedelta

with open("$METRICS_DB", "r") as f:
    db = json.load(f)

week_key = "$week"

if week_key not in db["weekly_stats"]:
    print("❌ Nessun dato per questa settimana")
    exit(1)

week_data = db["weekly_stats"][week_key]

# Header
print("=" * 60)
print(f"📅 SETTIMANA: {week_key}")
print("=" * 60)

# Metriche principali
print(f"\n📈 METRICHE PRINCIPALI:")
print(f"   ✅ Task completate: {week_data['tasks']}")
print(f"   🎯 Punti produttività: {week_data['points']}")
print(f"   ⏱️  Tempo totale: {week_data['time_minutes']} min ({week_data['time_minutes']/60:.1f} ore)")
print(f"   📁 Progetti toccati: {len(week_data['projects_touched'])}")

# Media giornaliera
if week_data.get('daily_tasks'):
    avg_daily = sum(week_data['daily_tasks'].values()) / len(week_data['daily_tasks'])
    print(f"   📊 Media task/giorno: {avg_daily:.1f}")

# Progetti della settimana
if week_data['projects_touched']:
    print(f"\n🗂️  PROGETTI SETTIMANA:")
    for project in week_data['projects_touched']:
        if project in db["projects"]:
            proj_data = db["projects"][project]
            # Conta task di questa settimana per progetto
            week_tasks = [t for t in db["tasks"] if t["project"] == project and f"{t['year']}-W{t['week']}" == week_key]
            print(f"   • {project}: {len(week_tasks)} task")

# Task per tipo questa settimana
week_tasks = [t for t in db["tasks"] if f"{t['year']}-W{t['week']}" == week_key]
task_types_week = {}
for task in week_tasks:
    task_type = task["type"]
    if task_type not in task_types_week:
        task_types_week[task_type] = {"count": 0, "points": 0}
    task_types_week[task_type]["count"] += 1
    task_types_week[task_type]["points"] += task["points"]

if task_types_week:
    print(f"\n📋 TASK PER TIPO:")
    for task_type, data in sorted(task_types_week.items(), key=lambda x: x[1]["points"], reverse=True):
        print(f"   • {task_type}: {data['count']} task ({data['points']} punti)")

# Distribuzione giornaliera
if week_data.get('daily_tasks'):
    print(f"\n📅 DISTRIBUZIONE GIORNALIERA:")
    for day in sorted(week_data['daily_tasks'].keys()):
        tasks_count = week_data['daily_tasks'][day]
        bar = "█" * min(tasks_count, 20)
        print(f"   {day}: {bar} {tasks_count}")

# Confronto con settimana precedente
prev_week_num = int(week_key.split("-W")[1]) - 1
if prev_week_num > 0:
    prev_week_key = f"{week_key.split('-W')[0]}-W{prev_week_num:02d}"
    if prev_week_key in db["weekly_stats"]:
        prev_data = db["weekly_stats"][prev_week_key]
        print(f"\n📊 CONFRONTO SETTIMANA PRECEDENTE:")
        
        task_diff = week_data['tasks'] - prev_data['tasks']
        points_diff = week_data['points'] - prev_data['points']
        
        task_symbol = "📈" if task_diff >= 0 else "📉"
        points_symbol = "📈" if points_diff >= 0 else "📉"
        
        print(f"   {task_symbol} Task: {task_diff:+d} ({prev_data['tasks']} → {week_data['tasks']})")
        print(f"   {points_symbol} Punti: {points_diff:+d} ({prev_data['points']} → {week_data['points']})")

print("\n" + "=" * 60)

# Salva report in file
report_file = f"$WEEKLY_REPORTS/week-{week_key.replace(':', '-')}.txt"
with open(report_file, "w") as f:
    f.write(f"PRODUCTIVITY REPORT - {week_key}\n")
    f.write("=" * 60 + "\n")
    f.write(f"Tasks: {week_data['tasks']} | Points: {week_data['points']} | Time: {week_data['time_minutes']} min\n")
    f.write(f"Projects: {', '.join(week_data['projects_touched'])}\n")

print(f"\n💾 Report salvato in: {report_file}")
EOF
}

# Funzione per mostrare dashboard
show_dashboard() {
    if [[ ! -f "$METRICS_DB" ]]; then
        echo -e "${RED}❌ Nessun dato trovato${NC}"
        return 1
    fi
    
    echo -e "${PURPLE}🎯 PRODUCTIVITY DASHBOARD${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime, timedelta

with open("$METRICS_DB", "r") as f:
    db = json.load(f)

# Stats globali
print("📊 STATISTICHE GLOBALI")
print("=" * 40)
print(f"✅ Task totali: {db['total_stats']['tasks_completed']}")
print(f"🎯 Punti totali: {db['total_stats']['total_points']}")
print(f"⏱️  Tempo totale: {db['total_stats']['total_time_minutes']/60:.1f} ore")
print(f"📁 Progetti attivi: {len(db['projects'])}")

# Produttività media
if db['weekly_stats']:
    avg_weekly_tasks = sum(w['tasks'] for w in db['weekly_stats'].values()) / len(db['weekly_stats'])
    avg_weekly_points = sum(w['points'] for w in db['weekly_stats'].values()) / len(db['weekly_stats'])
    print(f"\n📈 MEDIE SETTIMANALI")
    print(f"   Task/settimana: {avg_weekly_tasks:.1f}")
    print(f"   Punti/settimana: {avg_weekly_points:.1f}")

# Top progetti
if db['projects']:
    print(f"\n🏆 TOP 3 PROGETTI")
    sorted_projects = sorted(db['projects'].items(), key=lambda x: x[1]['total_points'], reverse=True)[:3]
    for i, (name, data) in enumerate(sorted_projects, 1):
        print(f"   {i}. {name}: {data['tasks_count']} task ({data['total_points']} punti)")

# Task types
print(f"\n📋 DISTRIBUZIONE TASK")
for task_type, data in db['task_types'].items():
    if data['count'] > 0:
        percentage = (data['count'] / db['total_stats']['tasks_completed']) * 100
        print(f"   {task_type}: {data['count']} ({percentage:.1f}%)")

# Trend ultime 4 settimane
current_week = int(datetime.now().strftime("%V"))
current_year = int(datetime.now().strftime("%Y"))
print(f"\n📈 TREND ULTIME 4 SETTIMANE")

for i in range(3, -1, -1):
    week_num = current_week - i
    if week_num > 0:
        week_key = f"{current_year}-W{week_num:02d}"
        if week_key in db['weekly_stats']:
            week_data = db['weekly_stats'][week_key]
            bar = "█" * min(week_data['tasks'], 20)
            print(f"   W{week_num}: {bar} {week_data['tasks']} task")
EOF
}

# Funzione per esportare metriche
export_metrics() {
    local format="${1:-json}"
    local output="${2:-productivity-export}"
    
    if [[ ! -f "$METRICS_DB" ]]; then
        echo -e "${RED}❌ Nessun dato da esportare${NC}"
        return 1
    fi
    
    case "$format" in
        "csv")
            python3 << EOF
import json
import csv

with open("$METRICS_DB", "r") as f:
    db = json.load(f)

# Esporta task
with open("${output}-tasks.csv", "w", newline="") as f:
    fieldnames = ["id", "name", "project", "type", "complexity", "points", "time_spent_minutes", "timestamp", "week", "year"]
    writer = csv.DictWriter(f, fieldnames=fieldnames)
    writer.writeheader()
    for task in db["tasks"]:
        writer.writerow(task)

# Esporta statistiche settimanali
with open("${output}-weekly.csv", "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["Week", "Tasks", "Points", "Time (min)", "Projects"])
    for week, data in sorted(db["weekly_stats"].items()):
        writer.writerow([week, data["tasks"], data["points"], data["time_minutes"], len(data["projects_touched"])])

print("✅ Esportato in ${output}-tasks.csv e ${output}-weekly.csv")
EOF
            ;;
        "json")
            cp "$METRICS_DB" "${output}.json"
            echo -e "${GREEN}✅ Esportato in ${output}.json${NC}"
            ;;
        "markdown")
            python3 << EOF
import json
from datetime import datetime

with open("$METRICS_DB", "r") as f:
    db = json.load(f)

with open("${output}.md", "w") as f:
    f.write("# Productivity Metrics Report\n\n")
    f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n\n")
    
    f.write("## Summary\n\n")
    f.write(f"- **Total Tasks**: {db['total_stats']['tasks_completed']}\n")
    f.write(f"- **Total Points**: {db['total_stats']['total_points']}\n")
    f.write(f"- **Total Time**: {db['total_stats']['total_time_minutes']/60:.1f} hours\n\n")
    
    f.write("## Projects\n\n")
    for project, data in sorted(db['projects'].items(), key=lambda x: x[1]['total_points'], reverse=True):
        f.write(f"### {project}\n")
        f.write(f"- Tasks: {data['tasks_count']}\n")
        f.write(f"- Points: {data['total_points']}\n")
        f.write(f"- Time: {data['total_time_minutes']} min\n\n")

print("✅ Esportato in ${output}.md")
EOF
            ;;
        *)
            echo -e "${RED}❌ Formato non supportato: $format${NC}"
            echo "Formati: json, csv, markdown"
            return 1
            ;;
    esac
}

# Help
show_help() {
    echo "Claude Productivity Metrics - Traccia e analizza produttività"
    echo ""
    echo "Uso: claude-productivity-metrics [comando] [parametri]"
    echo ""
    echo "Comandi:"
    echo "  log <task> <progetto> [tipo] [complessità] [tempo]"
    echo "      Logga una task completata"
    echo "      Tipi: feature, bugfix, refactor, docs, test"
    echo "      Complessità: simple, medium, complex"
    echo ""
    echo "  report [settimana]    - Genera report settimanale (default: corrente)"
    echo "  dashboard             - Mostra dashboard produttività"
    echo "  export [formato] [file] - Esporta dati (json/csv/markdown)"
    echo ""
    echo "Esempi:"
    echo "  claude-productivity-metrics log \"Add user auth\" api-gateway feature complex 120"
    echo "  claude-productivity-metrics report 2025-W24"
    echo "  claude-productivity-metrics dashboard"
}

# Main
case "$1" in
    "log")
        log_task "$2" "$3" "$4" "$5" "$6"
        ;;
    "report")
        generate_weekly_report "$2"
        ;;
    "dashboard")
        show_dashboard
        ;;
    "export")
        export_metrics "$2" "$3"
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