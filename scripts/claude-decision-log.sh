#!/bin/bash
# Claude Decision Log - Traccia decisioni architetturali importanti
# Documenta il reasoning dietro scelte tecniche

WORKSPACE_DIR="$HOME/claude-workspace"
DECISIONS_DIR="$WORKSPACE_DIR/.claude/decisions"
DECISIONS_DB="$DECISIONS_DIR/decisions.json"
DECISIONS_MARKDOWN="$DECISIONS_DIR/DECISIONS.md"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Crea directory
mkdir -p "$DECISIONS_DIR"

# Template per ADR (Architecture Decision Record)
create_adr_template() {
    local decision_id="$1"
    local title="$2"
    
    cat << EOF
# ADR-${decision_id}: ${title}

## Status
Proposed

## Context
[Describe the context and problem statement]

## Decision
[Describe the decision and rationale]

## Consequences
### Positive
- [Positive consequence 1]
- [Positive consequence 2]

### Negative
- [Negative consequence 1]
- [Negative consequence 2]

## Alternatives Considered
1. [Alternative 1]
   - Pros: 
   - Cons: 

2. [Alternative 2]
   - Pros:
   - Cons:

## References
- [Link or reference]
EOF
}

# Funzione per loggare decisione
log_decision() {
    local title="$1"
    local decision="$2"
    local reasoning="$3"
    local project="${4:-general}"
    local category="${5:-architecture}"  # architecture, tool, process, security
    local impact="${6:-medium}"          # low, medium, high
    
    if [[ -z "$title" || -z "$decision" ]]; then
        echo -e "${RED}❌ Titolo e decisione sono richiesti${NC}"
        echo "Uso: claude-decision-log add <titolo> <decisione> [reasoning] [progetto] [categoria] [impatto]"
        return 1
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local decision_id="$(date +%s)-$(echo $RANDOM)"
    local adr_number=$(date +%Y%m%d%H%M%S)
    
    echo -e "${YELLOW}📝 Registrando decisione...${NC}"
    
    # Esporta le variabili per Python
    export decision_id timestamp title decision reasoning project category impact adr_number
    export DECISIONS_DB DECISIONS_DIR
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

# Variabili da bash
decisions_db = os.environ.get('DECISIONS_DB')
decisions_dir = os.environ.get('DECISIONS_DIR')
decision_id = os.environ.get('decision_id')
adr_number = os.environ.get('adr_number')
timestamp = os.environ.get('timestamp')
title = os.environ.get('title')
decision = os.environ.get('decision')
reasoning = os.environ.get('reasoning')
project = os.environ.get('project')
category = os.environ.get('category')
impact = os.environ.get('impact')

# Carica o crea database
if os.path.exists(decisions_db):
    with open(decisions_db, "r") as f:
        db = json.load(f)
else:
    db = {
        "version": "1.0",
        "decisions": [],
        "projects": {},
        "categories": {
            "architecture": {"count": 0, "decisions": []},
            "tool": {"count": 0, "decisions": []},
            "process": {"count": 0, "decisions": []},
            "security": {"count": 0, "decisions": []}
        },
        "stats": {
            "total_decisions": 0,
            "by_impact": {"low": 0, "medium": 0, "high": 0}
        }
    }

# Crea decisione
decision_record = {
    "id": decision_id,
    "adr_number": f"ADR-{adr_number}",
    "timestamp": timestamp,
    "title": title,
    "decision": decision,
    "reasoning": reasoning if reasoning else "Not specified",
    "project": project,
    "category": category,
    "impact": impact,
    "status": "active",
    "author": os.uname().nodename,
    "tags": [],
    "references": [],
    "supersedes": None,
    "superseded_by": None
}

# Aggiungi al database
db["decisions"].append(decision_record)

# Aggiorna statistiche progetto
if project not in db["projects"]:
    db["projects"][project] = {
        "decisions_count": 0,
        "categories": {},
        "last_decision": None
    }

db["projects"][project]["decisions_count"] += 1
db["projects"][project]["last_decision"] = timestamp

if category not in db["projects"][project]["categories"]:
    db["projects"][project]["categories"][category] = 0
db["projects"][project]["categories"][category] += 1

# Aggiorna categorie
if category in db["categories"]:
    db["categories"][category]["count"] += 1
    db["categories"][category]["decisions"].append({
        "id": decision_id,
        "title": title,
        "project": project,
        "timestamp": timestamp
    })

# Aggiorna stats
db["stats"]["total_decisions"] += 1
db["stats"]["by_impact"][impact] += 1

# Salva database
with open(decisions_db, "w") as f:
    json.dump(db, f, indent=2)

print(f'✅ Decisione registrata: {decision_record["adr_number"]}')
print(f'📋 Titolo: {title}')
print(f'🎯 Impatto: {impact}')

# Crea file ADR individuale
clean_title = title.lower().replace(" ", "-").replace("/", "-")
adr_file = os.path.join(decisions_dir, f'{decision_record["adr_number"]}-{clean_title}.md')
with open(adr_file, 'w') as f:
    f.write(f'# {decision_record["adr_number"]}: {decision_record["title"]}\n\n')
    f.write(f'**Date**: {decision_record["timestamp"]}\n')
    f.write(f'**Status**: Active\n')
    f.write(f'**Project**: {decision_record["project"]}\n')
    f.write(f'**Category**: {decision_record["category"]}\n')
    f.write(f'**Impact**: {decision_record["impact"]}\n\n')
    f.write(f'## Decision\n{decision_record["decision"]}\n\n')
    f.write(f'## Reasoning\n{decision_record["reasoning"]}\n\n')
    f.write(f'## Consequences\n_To be determined_\n\n')
    f.write(f'## References\n_None yet_\n')

print(f'📄 ADR file creato: {os.path.basename(adr_file)}')
EOF
    
    # Aggiorna DECISIONS.md principale
    update_decisions_markdown
}

# Funzione per cercare decisioni
search_decisions() {
    local query="$1"
    local filter_type="${2:-all}"  # all, project, category, recent
    
    if [[ ! -f "$DECISIONS_DB" ]]; then
        echo -e "${RED}❌ Nessuna decisione trovata${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔍 Ricerca decisioni: '$query'${NC}"
    echo ""
    
    python3 << EOF
import json
import re
from datetime import datetime, timedelta

with open("$DECISIONS_DB", "r") as f:
    db = json.load(f)

query = "$query".lower()
filter_type = "$filter_type"

# Filtra decisioni
filtered = []

for decision in db["decisions"]:
    # Ricerca nel testo
    if filter_type == "all":
        if (query in decision["title"].lower() or 
            query in decision["decision"].lower() or
            query in decision["reasoning"].lower() or
            query in decision["project"].lower()):
            filtered.append(decision)
    
    elif filter_type == "project":
        if decision["project"].lower() == query:
            filtered.append(decision)
    
    elif filter_type == "category":
        if decision["category"].lower() == query:
            filtered.append(decision)
    
    elif filter_type == "recent":
        days_ago = int(query) if query.isdigit() else 7
        cutoff = datetime.now() - timedelta(days=days_ago)
        decision_date = datetime.fromisoformat(decision["timestamp"].replace("Z", "+00:00"))
        if decision_date > cutoff:
            filtered.append(decision)

# Mostra risultati
if not filtered:
    print("❌ Nessuna decisione trovata")
else:
    print(f"📋 Trovate {len(filtered)} decisioni:\n")
    
    for decision in sorted(filtered, key=lambda x: x["timestamp"], reverse=True):
        status_icon = "✅" if decision["status"] == "active" else "⚠️"
        impact_color = {"low": "🟢", "medium": "🟡", "high": "🔴"}.get(decision["impact"], "⚪")
        
        print(f"{status_icon} {decision['adr_number']}: {decision['title']}")
        print(f"   {impact_color} Impatto: {decision['impact']} | 📁 Progetto: {decision['project']}")
        print(f"   📅 Data: {decision['timestamp']}")
        print(f"   💭 Decisione: {decision['decision'][:100]}...")
        print()
EOF
}

# Funzione per mostrare dashboard decisioni
show_dashboard() {
    if [[ ! -f "$DECISIONS_DB" ]]; then
        echo -e "${RED}❌ Nessuna decisione registrata${NC}"
        return 1
    fi
    
    echo -e "${PURPLE}🎯 DECISION LOG DASHBOARD${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime, timedelta
from collections import Counter

with open("$DECISIONS_DB", "r") as f:
    db = json.load(f)

print("📊 STATISTICHE GLOBALI")
print("=" * 40)
print(f"📝 Decisioni totali: {db['stats']['total_decisions']}")
print(f"📁 Progetti coinvolti: {len(db['projects'])}")
print()

# Impatto
print("🎯 DISTRIBUZIONE IMPATTO")
for impact, count in db['stats']['by_impact'].items():
    icon = {"low": "🟢", "medium": "🟡", "high": "🔴"}.get(impact, "⚪")
    percentage = (count / db['stats']['total_decisions'] * 100) if db['stats']['total_decisions'] > 0 else 0
    print(f"   {icon} {impact.capitalize()}: {count} ({percentage:.1f}%)")
print()

# Categorie
print("📂 DECISIONI PER CATEGORIA")
for category, data in sorted(db['categories'].items(), key=lambda x: x[1]['count'], reverse=True):
    if data['count'] > 0:
        print(f"   • {category}: {data['count']} decisioni")
print()

# Top progetti
if db['projects']:
    print("🏆 TOP PROGETTI PER DECISIONI")
    sorted_projects = sorted(db['projects'].items(), key=lambda x: x[1]['decisions_count'], reverse=True)[:5]
    for project, data in sorted_projects:
        print(f"   • {project}: {data['decisions_count']} decisioni")
    print()

# Decisioni recenti
recent_decisions = sorted(db['decisions'], key=lambda x: x['timestamp'], reverse=True)[:5]
if recent_decisions:
    print("🕐 DECISIONI RECENTI")
    for decision in recent_decisions:
        print(f"   • {decision['title'][:50]}...")
        print(f"     {decision['timestamp']} | {decision['project']}")
EOF
}

# Funzione per aggiornare DECISIONS.md
update_decisions_markdown() {
    if [[ ! -f "$DECISIONS_DB" ]]; then
        return 0
    fi
    
    python3 << 'EOF'
import json
from datetime import datetime

with open("$DECISIONS_DB", "r") as f:
    db = json.load(f)

# Genera markdown
content = ["# Architecture Decision Records\n"]
content.append(f"Last updated: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
content.append(f"Total decisions: {db['stats']['total_decisions']}\n\n")

# Indice per categoria
content.append("## Index by Category\n")
for category, data in db['categories'].items():
    if data['count'] > 0:
        content.append(f"\n### {category.capitalize()} ({data['count']})\n")
        for decision_ref in sorted(data['decisions'], key=lambda x: x['timestamp'], reverse=True)[:10]:
            content.append(f"- [{decision_ref['title']}](#{decision_ref['id']}) - {decision_ref['project']}\n")

content.append("\n## All Decisions\n")

# Lista tutte le decisioni
for decision in sorted(db['decisions'], key=lambda x: x['timestamp'], reverse=True):
    content.append(f"\n### {decision['adr_number']}: {decision['title']} {{#{decision['id']}}}\n")
    content.append(f"- **Status**: {decision['status']}\n")
    content.append(f"- **Date**: {decision['timestamp']}\n")
    content.append(f"- **Project**: {decision['project']}\n")
    content.append(f"- **Category**: {decision['category']}\n")
    content.append(f"- **Impact**: {decision['impact']}\n\n")
    content.append(f"**Decision**: {decision['decision']}\n\n")
    content.append(f"**Reasoning**: {decision['reasoning']}\n\n")
    content.append("---\n")

# Salva file
with open("$DECISIONS_MARKDOWN", "w") as f:
    f.writelines(content)
EOF
}

# Funzione per modificare status decisione
update_decision_status() {
    local decision_id="$1"
    local new_status="$2"
    local superseded_by="$3"
    
    if [[ -z "$decision_id" || -z "$new_status" ]]; then
        echo -e "${RED}❌ ID decisione e nuovo status richiesti${NC}"
        return 1
    fi
    
    python3 << EOF
import json

with open("$DECISIONS_DB", "r") as f:
    db = json.load(f)

found = False
for decision in db["decisions"]:
    if decision["id"] == "$decision_id" or decision["adr_number"] == "$decision_id":
        decision["status"] = "$new_status"
        if "$superseded_by":
            decision["superseded_by"] = "$superseded_by"
        found = True
        print(f"✅ Status aggiornato: {decision['adr_number']} → $new_status")
        break

if not found:
    print("❌ Decisione non trovata")
else:
    with open("$DECISIONS_DB", "w") as f:
        json.dump(db, f, indent=2)
    
    # Aggiorna markdown
    import subprocess
    subprocess.run(["bash", "-c", "update_decisions_markdown"], capture_output=True)
EOF
}

# Funzione per esportare decisioni
export_decisions() {
    local format="${1:-markdown}"
    local output="${2:-decisions-export}"
    
    if [[ ! -f "$DECISIONS_DB" ]]; then
        echo -e "${RED}❌ Nessuna decisione da esportare${NC}"
        return 1
    fi
    
    case "$format" in
        "json")
            cp "$DECISIONS_DB" "${output}.json"
            echo -e "${GREEN}✅ Esportato in ${output}.json${NC}"
            ;;
        "markdown")
            cp "$DECISIONS_MARKDOWN" "${output}.md"
            echo -e "${GREEN}✅ Esportato in ${output}.md${NC}"
            ;;
        "html")
            python3 << EOF
import json
import html

with open("$DECISIONS_DB", "r") as f:
    db = json.load(f)

html_content = """<!DOCTYPE html>
<html>
<head>
    <title>Architecture Decision Records</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
        .decision { border: 1px solid #ddd; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .high { border-left: 5px solid #ff4444; }
        .medium { border-left: 5px solid #ffaa00; }
        .low { border-left: 5px solid #44ff44; }
        .meta { color: #666; font-size: 0.9em; }
        h1 { color: #333; }
        h2 { color: #555; }
    </style>
</head>
<body>
    <h1>Architecture Decision Records</h1>
    <p>Total decisions: """ + str(db['stats']['total_decisions']) + """</p>
"""

for decision in sorted(db['decisions'], key=lambda x: x['timestamp'], reverse=True):
    html_content += f"""
    <div class="decision {decision['impact']}">
        <h2>{html.escape(decision['adr_number'])}: {html.escape(decision['title'])}</h2>
        <div class="meta">
            <strong>Status:</strong> {decision['status']} | 
            <strong>Project:</strong> {decision['project']} | 
            <strong>Impact:</strong> {decision['impact']} | 
            <strong>Date:</strong> {decision['timestamp']}
        </div>
        <h3>Decision</h3>
        <p>{html.escape(decision['decision'])}</p>
        <h3>Reasoning</h3>
        <p>{html.escape(decision['reasoning'])}</p>
    </div>
    """

html_content += """
</body>
</html>
"""

with open("${output}.html", "w") as f:
    f.write(html_content)

print("✅ Esportato in ${output}.html")
EOF
            ;;
        *)
            echo -e "${RED}❌ Formato non supportato: $format${NC}"
            echo "Formati: json, markdown, html"
            return 1
            ;;
    esac
}

# Help
show_help() {
    echo "Claude Decision Log - Traccia decisioni architetturali"
    echo ""
    echo "Uso: claude-decision-log [comando] [parametri]"
    echo ""
    echo "Comandi:"
    echo "  add <titolo> <decisione> [reasoning] [progetto] [categoria] [impatto]"
    echo "      Registra una nuova decisione"
    echo "      Categorie: architecture, tool, process, security"
    echo "      Impatto: low, medium, high"
    echo ""
    echo "  search <query> [tipo]     - Cerca decisioni (tipo: all, project, category, recent)"
    echo "  dashboard                 - Mostra dashboard decisioni"
    echo "  status <id> <nuovo>       - Aggiorna status (active, superseded, deprecated)"
    echo "  export [formato] [file]   - Esporta (json, markdown, html)"
    echo ""
    echo "Esempi:"
    echo "  claude-decision-log add \"Use PostgreSQL\" \"We will use PostgreSQL for persistence\" \"Proven reliability\""
    echo "  claude-decision-log search \"database\" category"
    echo "  claude-decision-log status ADR-20250613123456 superseded"
}

# Main
case "$1" in
    "add")
        log_decision "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    "search")
        search_decisions "$2" "$3"
        ;;
    "dashboard")
        show_dashboard
        ;;
    "status")
        update_decision_status "$2" "$3" "$4"
        ;;
    "export")
        export_decisions "$2" "$3"
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