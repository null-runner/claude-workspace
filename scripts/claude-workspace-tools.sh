#!/bin/bash
# Claude Workspace Tools - Sistema unificato per le feature rimanenti
# Semantic search, Recent context, Deadline reminder, Auto-testing, etc.

WORKSPACE_DIR="$HOME/claude-workspace"
TOOLS_DIR="$WORKSPACE_DIR/.claude/tools"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Crea directory
mkdir -p "$TOOLS_DIR"

# Semantic Search - ricerca intelligente nel workspace
semantic_search() {
    local query="$1"
    local context="${2:-all}"  # all, code, docs, decisions, learnings
    
    if [[ -z "$query" ]]; then
        echo -e "${RED}❌ Query richiesta${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔍 Semantic Search: '$query'${NC}"
    echo ""
    
    python3 << EOF
import os
import json
import re
from pathlib import Path

query = "$query".lower()
results = []

# Cerca nei progetti
if "$context" in ["all", "code"]:
    projects_dir = Path("$WORKSPACE_DIR/projects")
    if projects_dir.exists():
        for file_path in projects_dir.rglob("*"):
            if file_path.is_file() and file_path.suffix in ['.py', '.js', '.ts', '.md', '.json', '.yml', '.yaml']:
                try:
                    content = file_path.read_text(encoding='utf-8')
                    if query in content.lower():
                        # Trova righe con match
                        lines = content.split('\n')
                        matches = [(i+1, line) for i, line in enumerate(lines) if query in line.lower()]
                        if matches:
                            results.append({
                                "type": "code",
                                "file": str(file_path.relative_to(Path("$WORKSPACE_DIR"))),
                                "matches": len(matches),
                                "sample": matches[0][1][:100].strip()
                            })
                except:
                    pass

# Cerca nelle decisioni
if "$context" in ["all", "decisions"]:
    decisions_file = Path("$WORKSPACE_DIR/.claude/decisions/decisions.json")
    if decisions_file.exists():
        try:
            with open(decisions_file) as f:
                decisions_db = json.load(f)
            for decision in decisions_db.get("decisions", []):
                if (query in decision["title"].lower() or 
                    query in decision["decision"].lower() or
                    query in decision["reasoning"].lower()):
                    results.append({
                        "type": "decision",
                        "file": f"Decision: {decision['title']}",
                        "matches": 1,
                        "sample": decision["decision"][:100]
                    })
        except:
            pass

# Cerca nelle lezioni
if "$context" in ["all", "learnings"]:
    learnings_file = Path("$WORKSPACE_DIR/.claude/learnings/learnings.json")
    if learnings_file.exists():
        try:
            with open(learnings_file) as f:
                learnings_db = json.load(f)
            for learning in learnings_db.get("learnings", []):
                if (query in learning["title"].lower() or 
                    query in learning["lesson"].lower() or
                    query in learning["context"].lower()):
                    results.append({
                        "type": "learning",
                        "file": f"Learning: {learning['title']}",
                        "matches": 1,
                        "sample": learning["lesson"][:100]
                    })
        except:
            pass

# Cerca nella documentazione
if "$context" in ["all", "docs"]:
    for doc_file in Path("$WORKSPACE_DIR").rglob("*.md"):
        if "/.claude/" not in str(doc_file):
            try:
                content = doc_file.read_text(encoding='utf-8')
                if query in content.lower():
                    results.append({
                        "type": "docs",
                        "file": str(doc_file.relative_to(Path("$WORKSPACE_DIR"))),
                        "matches": content.lower().count(query),
                        "sample": content[:100]
                    })
            except:
                pass

# Mostra risultati
if not results:
    print("❌ Nessun risultato trovato")
else:
    print(f"📋 Trovati {len(results)} risultati:\n")
    
    type_icons = {"code": "💻", "decision": "🎯", "learning": "📚", "docs": "📄"}
    
    for result in sorted(results, key=lambda x: x["matches"], reverse=True)[:20]:
        icon = type_icons.get(result["type"], "📄")
        print(f"{icon} {result['file']}")
        print(f"   📊 {result['matches']} match | 📝 {result['sample']}...")
        print()
EOF
}

# Recent Context - trova ultimo file/progetto lavorato
recent_context() {
    echo -e "${CYAN}📄 Recent Context${NC}"
    echo ""
    
    python3 << EOF
import json
import os
from datetime import datetime
from pathlib import Path

recent_files = []
context_info = []

# Cerca ultima sessione
session_file = Path("$WORKSPACE_DIR/.claude/memory/current-session-context.json")
if session_file.exists():
    try:
        with open(session_file) as f:
            session = json.load(f)
        print(f"📂 Ultima sessione: {session.get('timestamp', 'Unknown')}")
        if session.get('conversation_summary'):
            print(f"💬 Stavamo facendo: {session['conversation_summary']}")
        if session.get('incomplete_tasks'):
            print(f"⏳ Task incomplete: {len(session['incomplete_tasks'])}")
        print()
    except:
        pass

# Cerca activity tracker
activity_file = Path("$WORKSPACE_DIR/.claude/activity/activity.json")
if activity_file.exists():
    try:
        with open(activity_file) as f:
            activity = json.load(f)
        
        if activity.get("projects"):
            print("🏃 PROGETTI RECENTI:")
            sorted_projects = sorted(activity["projects"].items(), 
                                   key=lambda x: x[1].get("last_activity", ""), 
                                   reverse=True)[:5]
            for project, data in sorted_projects:
                print(f"   • {project}: {data.get('last_activity', 'N/A')}")
            print()
    except:
        pass

# File modificati di recente
try:
    import subprocess
    result = subprocess.run(['find', '$WORKSPACE_DIR/projects', '-type', 'f', 
                           '-name', '*.py', '-o', '-name', '*.js', '-o', '-name', '*.md',
                           '-exec', 'stat', '-c', '%Y %n', '{}', '+'], 
                          capture_output=True, text=True)
    
    if result.returncode == 0:
        files_by_time = []
        for line in result.stdout.strip().split('\n'):
            if line:
                parts = line.split(' ', 1)
                if len(parts) == 2:
                    timestamp, filepath = parts
                    files_by_time.append((int(timestamp), filepath))
        
        print("📄 FILE MODIFICATI DI RECENTE:")
        for timestamp, filepath in sorted(files_by_time, reverse=True)[:10]:
            relative_path = filepath.replace('$WORKSPACE_DIR/', '')
            date_str = datetime.fromtimestamp(timestamp).strftime('%Y-%m-%d %H:%M')
            print(f"   • {relative_path} ({date_str})")
except:
    pass
EOF
}

# Deadline Reminder - progetti fermi da troppo tempo
deadline_reminder() {
    local days="${1:-7}"
    
    echo -e "${YELLOW}⏰ Deadline Reminder - Progetti fermi da $days+ giorni${NC}"
    echo ""
    
    python3 << EOF
import json
import os
from datetime import datetime, timedelta
from pathlib import Path

cutoff_date = datetime.now() - timedelta(days=$days)
stale_projects = []

# Controlla activity tracker
activity_file = Path("$WORKSPACE_DIR/.claude/activity/activity.json")
if activity_file.exists():
    try:
        with open(activity_file) as f:
            activity = json.load(f)
        
        for project, data in activity["projects"].items():
            last_activity = data.get("last_activity")
            if last_activity:
                last_date = datetime.fromisoformat(last_activity.replace("Z", "+00:00"))
                if last_date < cutoff_date:
                    days_ago = (datetime.now().replace(tzinfo=last_date.tzinfo) - last_date).days
                    stale_projects.append({
                        "name": project,
                        "last_activity": last_activity,
                        "days_ago": days_ago,
                        "total_time": data.get("total_hours", 0)
                    })
    except:
        pass

# Controlla directory progetti per file modificati
projects_dir = Path("$WORKSPACE_DIR/projects/active")
if projects_dir.exists():
    for project_dir in projects_dir.iterdir():
        if project_dir.is_dir():
            try:
                latest_file_time = 0
                for file_path in project_dir.rglob("*"):
                    if file_path.is_file():
                        file_time = file_path.stat().st_mtime
                        latest_file_time = max(latest_file_time, file_time)
                
                if latest_file_time > 0:
                    last_modified = datetime.fromtimestamp(latest_file_time)
                    if last_modified < cutoff_date:
                        days_ago = (datetime.now() - last_modified).days
                        project_name = project_dir.name
                        
                        # Aggiungi se non già presente
                        if not any(p["name"] == project_name for p in stale_projects):
                            stale_projects.append({
                                "name": project_name,
                                "last_activity": last_modified.isoformat(),
                                "days_ago": days_ago,
                                "total_time": 0
                            })
            except:
                pass

# Mostra risultati
if not stale_projects:
    print("✅ Tutti i progetti sono attivi!")
else:
    print(f"⚠️  Trovati {len(stale_projects)} progetti fermi:\n")
    
    for project in sorted(stale_projects, key=lambda x: x["days_ago"], reverse=True):
        urgency = "🔴" if project["days_ago"] > 30 else "🟡" if project["days_ago"] > 14 else "🟠"
        print(f"{urgency} {project['name']}")
        print(f"   📅 Ultimo aggiornamento: {project['days_ago']} giorni fa")
        if project["total_time"] > 0:
            print(f"   ⏱️  Tempo investito: {project['total_time']:.1f} ore")
        print()
    
    print("💡 Suggerimento: Usa 'claude-context-switch switch <progetto>' per riprendere")
EOF
}

# Auto-testing - esegue test quando rileva modifiche
auto_test() {
    local project_dir="$1"
    
    if [[ -z "$project_dir" ]]; then
        project_dir="$WORKSPACE_DIR/projects/active"
    fi
    
    echo -e "${GREEN}🧪 Auto Testing in $project_dir${NC}"
    
    python3 << EOF
import os
import subprocess
import json
from pathlib import Path
from datetime import datetime

project_path = Path("$project_dir")

def find_test_command(project_dir):
    """Rileva automaticamente il comando di test appropriato"""
    
    # Python
    if (project_dir / "pytest.ini").exists() or any(project_dir.rglob("test_*.py")):
        return ["python", "-m", "pytest"]
    
    # Node.js
    package_json = project_dir / "package.json"
    if package_json.exists():
        try:
            with open(package_json) as f:
                data = json.load(f)
            if "scripts" in data and "test" in data["scripts"]:
                return ["npm", "test"]
        except:
            pass
    
    # Java (Maven)
    if (project_dir / "pom.xml").exists():
        return ["mvn", "test"]
    
    # Java (Gradle)
    if (project_dir / "build.gradle").exists() or (project_dir / "build.gradle.kts").exists():
        return ["./gradlew", "test"]
    
    # Go
    if any(project_dir.rglob("*_test.go")):
        return ["go", "test", "./..."]
    
    return None

if project_path.is_file():
    project_path = project_path.parent

# Cerca progetti con test
test_results = []

if project_path.name != "active":
    # Test singolo progetto
    test_cmd = find_test_command(project_path)
    if test_cmd:
        print(f"🔍 Rilevato test in {project_path.name}: {' '.join(test_cmd)}")
        try:
            result = subprocess.run(test_cmd, cwd=project_path, 
                                  capture_output=True, text=True, timeout=300)
            test_results.append({
                "project": project_path.name,
                "command": " ".join(test_cmd),
                "success": result.returncode == 0,
                "output": result.stdout + result.stderr
            })
        except subprocess.TimeoutExpired:
            test_results.append({
                "project": project_path.name,
                "command": " ".join(test_cmd),
                "success": False,
                "output": "TIMEOUT: Test execution exceeded 5 minutes"
            })
        except Exception as e:
            test_results.append({
                "project": project_path.name,
                "command": " ".join(test_cmd),
                "success": False,
                "output": f"ERROR: {str(e)}"
            })
else:
    # Test tutti i progetti in active/
    for project_dir in project_path.iterdir():
        if project_dir.is_dir():
            test_cmd = find_test_command(project_dir)
            if test_cmd:
                print(f"🔍 Testing {project_dir.name}...")
                try:
                    result = subprocess.run(test_cmd, cwd=project_dir, 
                                          capture_output=True, text=True, timeout=120)
                    test_results.append({
                        "project": project_dir.name,
                        "command": " ".join(test_cmd),
                        "success": result.returncode == 0,
                        "output": result.stdout + result.stderr
                    })
                except subprocess.TimeoutExpired:
                    test_results.append({
                        "project": project_dir.name,
                        "command": " ".join(test_cmd),
                        "success": False,
                        "output": "TIMEOUT: Test execution exceeded 2 minutes"
                    })
                except Exception as e:
                    test_results.append({
                        "project": project_dir.name,
                        "command": " ".join(test_cmd),
                        "success": False,
                        "output": f"ERROR: {str(e)}"
                    })

# Mostra risultati
if not test_results:
    print("❌ Nessun test rilevato nei progetti")
else:
    print(f"\n📊 RISULTATI TEST ({len(test_results)} progetti)")
    print("=" * 50)
    
    passed = sum(1 for r in test_results if r["success"])
    failed = len(test_results) - passed
    
    print(f"✅ Passati: {passed}")
    print(f"❌ Falliti: {failed}")
    print()
    
    for result in test_results:
        status = "✅ PASS" if result["success"] else "❌ FAIL"
        print(f"{status} {result['project']}")
        print(f"   🔧 Comando: {result['command']}")
        
        # Mostra output conciso
        lines = result["output"].split('\n')
        if result["success"]:
            # Per test passati, mostra solo summary
            summary_lines = [l for l in lines if any(word in l.lower() for word in ['passed', 'ok', 'success', 'test'])]
            if summary_lines:
                print(f"   📝 {summary_lines[-1][:100]}")
        else:
            # Per test falliti, mostra errori
            error_lines = [l for l in lines if any(word in l.lower() for word in ['error', 'fail', 'exception'])]
            for line in error_lines[:3]:  # Max 3 error lines
                print(f"   ❌ {line[:100]}")
        print()

# Calcola statistiche
passed = sum(1 for r in test_results if r["success"])
failed = len(test_results) - passed

# Salva risultati
results_file = Path("$TOOLS_DIR/test-results.json")
with open(results_file, "w") as f:
    json.dump({
        "timestamp": datetime.now().isoformat(),
        "total_projects": len(test_results),
        "passed": passed,
        "failed": failed,
        "results": test_results
    }, f, indent=2)

print(f"💾 Risultati salvati in {results_file}")
EOF
}

# Error Aggregation - raccoglie errori frequenti
aggregate_errors() {
    echo -e "${RED}🚨 Error Aggregation${NC}"
    echo ""
    
    python3 << EOF
import json
import re
import os
from pathlib import Path
from collections import Counter, defaultdict
from datetime import datetime

errors = []
error_patterns = defaultdict(int)

# Cerca errori nei log
log_files = [
    Path("$WORKSPACE_DIR/logs/sync.log"),
    Path("$WORKSPACE_DIR/.claude/activity/activity.log")
]

for log_file in log_files:
    if log_file.exists():
        try:
            content = log_file.read_text()
            # Estrai righe con errori
            error_lines = [line for line in content.split('\n') 
                          if any(word in line.lower() for word in ['error', 'fail', 'exception', 'crash'])]
            errors.extend(error_lines)
        except:
            pass

# Cerca nei test results
test_results_file = Path("$TOOLS_DIR/test-results.json")
if test_results_file.exists():
    try:
        with open(test_results_file) as f:
            test_data = json.load(f)
        
        for result in test_data.get("results", []):
            if not result["success"]:
                errors.append(f"TEST FAIL: {result['project']} - {result['output'][:200]}")
    except:
        pass

# Analizza pattern di errori
common_errors = Counter()
for error in errors:
    # Estrai pattern comuni
    if "authentication" in error.lower() or "auth" in error.lower():
        error_patterns["Authentication Issues"] += 1
    elif "permission" in error.lower() or "access" in error.lower():
        error_patterns["Permission Issues"] += 1
    elif "network" in error.lower() or "connection" in error.lower():
        error_patterns["Network Issues"] += 1
    elif "memory" in error.lower() or "out of" in error.lower():
        error_patterns["Memory Issues"] += 1
    elif "syntax" in error.lower() or "parse" in error.lower():
        error_patterns["Syntax Errors"] += 1
    elif "file" in error.lower() and "not found" in error.lower():
        error_patterns["File Not Found"] += 1
    else:
        error_patterns["Other"] += 1
    
    # Conta errori specifici (prime 50 caratteri)
    error_signature = error[:50].strip()
    if error_signature:
        common_errors[error_signature] += 1

print("🚨 ERROR AGGREGATION REPORT")
print("=" * 40)
print(f"📊 Errori totali trovati: {len(errors)}")
print(f"🔍 Pattern unici: {len(error_patterns)}")
print()

if error_patterns:
    print("📂 PATTERN DI ERRORE:")
    for pattern, count in sorted(error_patterns.items(), key=lambda x: x[1], reverse=True):
        percentage = (count / len(errors) * 100) if errors else 0
        print(f"   • {pattern}: {count} ({percentage:.1f}%)")
    print()

if common_errors:
    print("🔥 ERRORI PIÙ FREQUENTI:")
    for error, count in common_errors.most_common(10):
        if count > 1:
            print(f"   • [{count}x] {error}...")
    print()

# Suggerimenti
suggestions = []
if error_patterns.get("Authentication Issues", 0) > 3:
    suggestions.append("🔐 Considera setup di auth robusta (molti errori auth)")
if error_patterns.get("Memory Issues", 0) > 2:
    suggestions.append("💾 Monitora uso memoria (leak potenziali)")
if error_patterns.get("Network Issues", 0) > 3:
    suggestions.append("🌐 Implementa retry logic per network")

if suggestions:
    print("💡 SUGGERIMENTI:")
    for suggestion in suggestions:
        print(f"   {suggestion}")
    print()

# Salva aggregation
aggregation_file = Path("$TOOLS_DIR/error-aggregation.json")
with open(aggregation_file, "w") as f:
    json.dump({
        "timestamp": datetime.now().isoformat(),
        "total_errors": len(errors),
        "patterns": dict(error_patterns),
        "common_errors": dict(common_errors.most_common(20)),
        "suggestions": suggestions
    }, f, indent=2)

print(f"💾 Aggregazione salvata in {aggregation_file}")
EOF
}

# Weekly Digest - riassunto settimanale attività
weekly_digest() {
    echo -e "${PURPLE}📅 Weekly Digest${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime, timedelta
from pathlib import Path

print("📊 WEEKLY WORKSPACE DIGEST")
print("=" * 40)
print(f"📅 Week ending: {datetime.now().strftime('%Y-%m-%d')}")
print()

digest_data = {}

# Activity Tracker
activity_file = Path("$WORKSPACE_DIR/.claude/activity/activity.json")
if activity_file.exists():
    try:
        with open(activity_file) as f:
            activity = json.load(f)
        
        # Calcola attività settimanale
        week_start = datetime.now() - timedelta(days=7)
        weekly_sessions = [s for s in activity.get("sessions", []) 
                          if datetime.fromisoformat(s["start_time"].replace("Z", "+00:00")) > week_start]
        
        total_time = sum(s.get("duration_minutes", 0) for s in weekly_sessions)
        projects_worked = set(s["project_name"] for s in weekly_sessions)
        
        print("⏱️  ACTIVITY THIS WEEK:")
        print(f"   • Total time: {total_time} min ({total_time/60:.1f} hours)")
        print(f"   • Sessions: {len(weekly_sessions)}")
        print(f"   • Projects: {len(projects_worked)}")
        if projects_worked:
            print(f"   • Projects worked: {', '.join(projects_worked)}")
        print()
        
        digest_data["activity"] = {
            "total_minutes": total_time,
            "sessions": len(weekly_sessions),
            "projects": list(projects_worked)
        }
    except:
        pass

# Productivity Metrics
metrics_file = Path("$WORKSPACE_DIR/.claude/metrics/productivity.json")
if metrics_file.exists():
    try:
        with open(metrics_file) as f:
            metrics = json.load(f)
        
        # Trova settimana corrente
        current_week = f"{datetime.now().year}-W{datetime.now().isocalendar()[1]:02d}"
        week_data = metrics.get("weekly_stats", {}).get(current_week, {})
        
        if week_data:
            print("🎯 PRODUCTIVITY THIS WEEK:")
            print(f"   • Tasks completed: {week_data.get('tasks', 0)}")
            print(f"   • Productivity points: {week_data.get('points', 0)}")
            print(f"   • Time tracked: {week_data.get('time_minutes', 0)} min")
            print(f"   • Projects touched: {len(week_data.get('projects_touched', []))}")
            print()
            
            digest_data["productivity"] = week_data
    except:
        pass

# Decisions
decisions_file = Path("$WORKSPACE_DIR/.claude/decisions/decisions.json")
if decisions_file.exists():
    try:
        with open(decisions_file) as f:
            decisions = json.load(f)
        
        week_start = datetime.now() - timedelta(days=7)
        weekly_decisions = [d for d in decisions.get("decisions", [])
                           if datetime.fromisoformat(d["timestamp"].replace("Z", "+00:00")) > week_start]
        
        if weekly_decisions:
            print("🎯 DECISIONS THIS WEEK:")
            print(f"   • New decisions: {len(weekly_decisions)}")
            for decision in weekly_decisions[-3:]:  # Last 3
                print(f"   • {decision['title']} ({decision['impact']} impact)")
            print()
            
            digest_data["decisions"] = len(weekly_decisions)
    except:
        pass

# Learnings
learnings_file = Path("$WORKSPACE_DIR/.claude/learnings/learnings.json")
if learnings_file.exists():
    try:
        with open(learnings_file) as f:
            learnings = json.load(f)
        
        week_start = datetime.now() - timedelta(days=7)
        weekly_learnings = [l for l in learnings.get("learnings", [])
                           if datetime.fromisoformat(l["timestamp"].replace("Z", "+00:00")) > week_start]
        
        if weekly_learnings:
            print("📚 LEARNINGS THIS WEEK:")
            print(f"   • New learnings: {len(weekly_learnings)}")
            high_impact = [l for l in weekly_learnings if l["severity"] in ["high", "critical"]]
            if high_impact:
                print(f"   • High impact: {len(high_impact)}")
            print()
            
            digest_data["learnings"] = len(weekly_learnings)
    except:
        pass

# File changes
try:
    import subprocess
    result = subprocess.run(['git', 'log', '--since=1.week', '--oneline'], 
                          cwd='$WORKSPACE_DIR', capture_output=True, text=True)
    if result.returncode == 0:
        commits = [line for line in result.stdout.strip().split('\n') if line]
        print("📝 GIT ACTIVITY:")
        print(f"   • Commits this week: {len(commits)}")
        if commits:
            print(f"   • Latest: {commits[0][:60]}...")
        print()
        
        digest_data["git"] = {"commits": len(commits)}
except:
    pass

# Summary
total_score = 0
if digest_data.get("activity", {}).get("total_minutes", 0) > 60:
    total_score += 2
if digest_data.get("productivity", {}).get("tasks", 0) > 3:
    total_score += 2
if digest_data.get("decisions", 0) > 0:
    total_score += 1
if digest_data.get("learnings", 0) > 0:
    total_score += 1
if digest_data.get("git", {}).get("commits", 0) > 2:
    total_score += 1

print("🏆 WEEKLY SCORE")
score_emoji = "🟢" if total_score >= 6 else "🟡" if total_score >= 4 else "🔴"
print(f"   {score_emoji} {total_score}/7 points")

if total_score >= 6:
    print("   💪 Excellent productivity week!")
elif total_score >= 4:
    print("   👍 Good progress this week")
else:
    print("   📈 Room for improvement next week")

# Salva digest
digest_file = Path("$TOOLS_DIR/weekly-digest.json")
with open(digest_file, "w") as f:
    json.dump({
        "week_ending": datetime.now().isoformat(),
        "score": total_score,
        "data": digest_data
    }, f, indent=2)

print(f"\n💾 Digest salvato in {digest_file}")
EOF
}

# Help function
show_help() {
    echo "Claude Workspace Tools - Sistema unificato"
    echo ""
    echo "Uso: claude-workspace-tools [comando] [parametri]"
    echo ""
    echo "Comandi:"
    echo "  search <query> [context]    - Semantic search (context: all, code, docs, decisions, learnings)"
    echo "  recent                      - Recent context e file modificati"
    echo "  reminders [giorni]          - Deadline reminder per progetti fermi (default: 7)"
    echo "  test [progetto]             - Auto-testing con rilevamento automatico"
    echo "  errors                      - Error aggregation e pattern analysis"
    echo "  digest                      - Weekly digest attività"
    echo ""
    echo "Esempi:"
    echo "  claude-workspace-tools search \"authentication\" code"
    echo "  claude-workspace-tools recent"
    echo "  claude-workspace-tools reminders 14"
    echo "  claude-workspace-tools test"
}

# Main dispatch
case "$1" in
    "search")
        semantic_search "$2" "$3"
        ;;
    "recent")
        recent_context
        ;;
    "reminders"|"reminder")
        deadline_reminder "$2"
        ;;
    "test"|"tests")
        auto_test "$2"
        ;;
    "errors"|"error")
        aggregate_errors
        ;;
    "digest")
        weekly_digest
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