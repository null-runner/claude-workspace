#!/bin/bash
# Claude Learning Tracker - Traccia cosa hai imparato per evitare errori
# Documenta lezioni apprese e pattern da evitare

WORKSPACE_DIR="$HOME/claude-workspace"
LEARNING_DIR="$WORKSPACE_DIR/.claude/learning"
LEARNING_DB="$LEARNING_DIR/learnings.json"
PATTERNS_FILE="$LEARNING_DIR/patterns.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Crea directory
mkdir -p "$LEARNING_DIR"

# Funzione per registrare lezione appresa
log_learning() {
    local title="$1"
    local lesson="$2"
    local context="$3"
    local category="${4:-general}"  # bug-fix, performance, security, design, process
    local severity="${5:-medium}"    # low, medium, high, critical
    local project="${6:-general}"
    
    if [[ -z "$title" || -z "$lesson" ]]; then
        echo -e "${RED}❌ Titolo e lezione sono richiesti${NC}"
        echo "Uso: claude-learning-tracker learn <titolo> <lezione> [contesto] [categoria] [severità] [progetto]"
        return 1
    fi
    
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local learning_id="learn-$(date +%s)-$(echo $RANDOM)"
    
    echo -e "${YELLOW}📚 Registrando lezione appresa...${NC}"
    
    python3 << EOF
import json
import os
from datetime import datetime

# Carica o crea database
if os.path.exists("$LEARNING_DB"):
    with open("$LEARNING_DB", "r") as f:
        db = json.load(f)
else:
    db = {
        "version": "1.0",
        "learnings": [],
        "categories": {
            "bug-fix": {"count": 0, "learnings": []},
            "performance": {"count": 0, "learnings": []},
            "security": {"count": 0, "learnings": []},
            "design": {"count": 0, "learnings": []},
            "process": {"count": 0, "learnings": []}
        },
        "projects": {},
        "tags": {},
        "stats": {
            "total_learnings": 0,
            "prevented_issues": 0,
            "by_severity": {"low": 0, "medium": 0, "high": 0, "critical": 0}
        }
    }

# Estrai tags dalla lezione (parole che iniziano con #)
import re
tags = re.findall(r'#(\w+)', "$lesson")

# Crea record
learning_record = {
    "id": "$learning_id",
    "timestamp": "$timestamp",
    "title": "$title",
    "lesson": "$lesson",
    "context": "$context" if "$context" else "Not specified",
    "category": "$category",
    "severity": "$severity",
    "project": "$project",
    "tags": tags,
    "applied_count": 0,
    "prevented_issues": [],
    "related_errors": [],
    "references": []
}

# Aggiungi al database
db["learnings"].append(learning_record)

# Aggiorna categorie
if "$category" in db["categories"]:
    db["categories"]["$category"]["count"] += 1
    db["categories"]["$category"]["learnings"].append({
        "id": "$learning_id",
        "title": "$title",
        "timestamp": "$timestamp",
        "severity": "$severity"
    })

# Aggiorna progetti
if "$project" not in db["projects"]:
    db["projects"]["$project"] = {
        "learnings_count": 0,
        "categories": {},
        "prevented_issues": 0
    }

db["projects"]["$project"]["learnings_count"] += 1
if "$category" not in db["projects"]["$project"]["categories"]:
    db["projects"]["$project"]["categories"]["$category"] = 0
db["projects"]["$project"]["categories"]["$category"] += 1

# Aggiorna tags
for tag in tags:
    if tag not in db["tags"]:
        db["tags"][tag] = {"count": 0, "learnings": []}
    db["tags"][tag]["count"] += 1
    db["tags"][tag]["learnings"].append("$learning_id")

# Aggiorna stats
db["stats"]["total_learnings"] += 1
db["stats"]["by_severity"]["$severity"] += 1

# Salva database
with open("$LEARNING_DB", "w") as f:
    json.dump(db, f, indent=2)

print(f"✅ Lezione registrata: {learning_record['title']}")
print(f"📂 Categoria: $category | ⚠️  Severità: $severity")
if tags:
    print(f"🏷️  Tags: {', '.join(tags)}")

# Controlla pattern simili
similar_count = 0
for existing in db["learnings"][:-1]:  # Escludi quello appena aggiunto
    # Cerca somiglianze nel titolo o lezione
    if any(word in existing["title"].lower() for word in "$title".lower().split()) or \
       any(word in existing["lesson"].lower() for word in "$title".lower().split() if len(word) > 4):
        similar_count += 1

if similar_count > 0:
    print(f"\n💡 Trovate {similar_count} lezioni simili. Usa 'search' per vederle.")
EOF
}

# Funzione per registrare quando una lezione previene un problema
record_prevention() {
    local learning_id="$1"
    local issue_description="$2"
    local impact="${3:-medium}"  # low, medium, high, critical
    
    if [[ -z "$learning_id" || -z "$issue_description" ]]; then
        echo -e "${RED}❌ ID lezione e descrizione problema sono richiesti${NC}"
        return 1
    fi
    
    python3 << EOF
import json
from datetime import datetime

with open("$LEARNING_DB", "r") as f:
    db = json.load(f)

found = False
for learning in db["learnings"]:
    if learning["id"] == "$learning_id" or "$learning_id" in learning["title"]:
        # Aggiungi prevenzione
        prevention = {
            "timestamp": datetime.now().isoformat() + "Z",
            "description": "$issue_description",
            "impact": "$impact"
        }
        learning["prevented_issues"].append(prevention)
        learning["applied_count"] += 1
        
        # Aggiorna stats globali
        db["stats"]["prevented_issues"] += 1
        
        # Aggiorna stats progetto
        if learning["project"] in db["projects"]:
            db["projects"][learning["project"]]["prevented_issues"] += 1
        
        found = True
        print(f"✅ Prevenzione registrata per: {learning['title']}")
        print(f"🛡️  Problema evitato: $issue_description")
        print(f"💪 Questa lezione ha prevenuto {len(learning['prevented_issues'])} problemi!")
        break

if not found:
    print("❌ Lezione non trovata")
else:
    with open("$LEARNING_DB", "w") as f:
        json.dump(db, f, indent=2)
EOF
}

# Funzione per cercare lezioni
search_learnings() {
    local query="$1"
    local filter_type="${2:-all}"  # all, category, tag, project, recent
    
    if [[ ! -f "$LEARNING_DB" ]]; then
        echo -e "${RED}❌ Nessuna lezione trovata${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔍 Ricerca lezioni: '$query'${NC}"
    echo ""
    
    python3 << EOF
import json
import re
from datetime import datetime, timedelta

with open("$LEARNING_DB", "r") as f:
    db = json.load(f)

query = "$query".lower()
filter_type = "$filter_type"

# Filtra lezioni
filtered = []

for learning in db["learnings"]:
    if filter_type == "all":
        if (query in learning["title"].lower() or 
            query in learning["lesson"].lower() or
            query in learning["context"].lower() or
            any(query in tag.lower() for tag in learning["tags"])):
            filtered.append(learning)
    
    elif filter_type == "category":
        if learning["category"] == query:
            filtered.append(learning)
    
    elif filter_type == "tag":
        if any(tag.lower() == query for tag in learning["tags"]):
            filtered.append(learning)
    
    elif filter_type == "project":
        if learning["project"].lower() == query:
            filtered.append(learning)
    
    elif filter_type == "recent":
        days = int(query) if query.isdigit() else 7
        cutoff = datetime.now() - timedelta(days=days)
        learning_date = datetime.fromisoformat(learning["timestamp"].replace("Z", "+00:00"))
        if learning_date > cutoff:
            filtered.append(learning)

# Mostra risultati
if not filtered:
    print("❌ Nessuna lezione trovata")
else:
    print(f"📚 Trovate {len(filtered)} lezioni:\n")
    
    for learning in sorted(filtered, key=lambda x: x["timestamp"], reverse=True):
        severity_icons = {"low": "🟢", "medium": "🟡", "high": "🟠", "critical": "🔴"}
        icon = severity_icons.get(learning["severity"], "⚪")
        
        print(f"{icon} {learning['title']}")
        print(f"   📝 {learning['lesson'][:100]}...")
        print(f"   📂 {learning['category']} | 📁 {learning['project']}")
        print(f"   🛡️  Ha prevenuto {len(learning['prevented_issues'])} problemi")
        if learning["tags"]:
            print(f"   🏷️  {', '.join(learning['tags'])}")
        print()
EOF
}

# Funzione per mostrare pattern comuni
analyze_patterns() {
    if [[ ! -f "$LEARNING_DB" ]]; then
        echo -e "${RED}❌ Nessun dato per analisi pattern${NC}"
        return 1
    fi
    
    echo -e "${PURPLE}🔍 ANALISI PATTERN E TENDENZE${NC}"
    echo ""
    
    python3 << EOF
import json
from collections import Counter, defaultdict
import re

with open("$LEARNING_DB", "r") as f:
    db = json.load(f)

print("📊 PATTERN COMUNI IDENTIFICATI")
print("=" * 50)

# Analizza parole frequenti nelle lezioni (escludi parole comuni)
stop_words = {"the", "a", "an", "and", "or", "but", "in", "on", "at", "to", "for", 
              "of", "with", "by", "from", "as", "is", "was", "are", "were", "be",
              "have", "has", "had", "do", "does", "did", "will", "would", "could",
              "should", "may", "might", "must", "can", "this", "that", "these",
              "those", "i", "you", "he", "she", "it", "we", "they", "what", "which"}

word_freq = Counter()
error_patterns = defaultdict(int)

for learning in db["learnings"]:
    # Estrai parole significative
    words = re.findall(r'\b\w+\b', learning["lesson"].lower())
    significant_words = [w for w in words if len(w) > 3 and w not in stop_words]
    word_freq.update(significant_words)
    
    # Cerca pattern di errore comuni
    if "error" in learning["lesson"].lower():
        error_patterns["error"] += 1
    if "bug" in learning["lesson"].lower():
        error_patterns["bug"] += 1
    if "performance" in learning["lesson"].lower():
        error_patterns["performance"] += 1
    if "security" in learning["lesson"].lower():
        error_patterns["security"] += 1
    if "memory" in learning["lesson"].lower():
        error_patterns["memory"] += 1

# Top parole chiave
print("\n🔤 TOP KEYWORDS:")
for word, count in word_freq.most_common(10):
    if count > 1:
        print(f"   • {word}: {count} occorrenze")

# Pattern di errore
if error_patterns:
    print("\n⚠️  PATTERN DI ERRORE:")
    for pattern, count in sorted(error_patterns.items(), key=lambda x: x[1], reverse=True):
        print(f"   • {pattern}: {count} occorrenze")

# Categorie più problematiche
print("\n📂 CATEGORIE PIÙ FREQUENTI:")
category_severity = defaultdict(lambda: {"count": 0, "high_severity": 0})
for learning in db["learnings"]:
    category_severity[learning["category"]]["count"] += 1
    if learning["severity"] in ["high", "critical"]:
        category_severity[learning["category"]]["high_severity"] += 1

for category, data in sorted(category_severity.items(), key=lambda x: x[1]["count"], reverse=True):
    high_pct = (data["high_severity"] / data["count"] * 100) if data["count"] > 0 else 0
    print(f"   • {category}: {data['count']} lezioni ({high_pct:.0f}% alta severità)")

# Progetti con più lezioni
if len(db["projects"]) > 1:
    print("\n📁 PROGETTI CON PIÙ LEZIONI:")
    sorted_projects = sorted(db["projects"].items(), 
                           key=lambda x: x[1]["learnings_count"], 
                           reverse=True)[:5]
    for project, data in sorted_projects:
        prevention_rate = (data["prevented_issues"] / data["learnings_count"] * 100) if data["learnings_count"] > 0 else 0
        print(f"   • {project}: {data['learnings_count']} lezioni")
        print(f"     (Tasso prevenzione: {prevention_rate:.0f}%)")

# Tag più usati
if db["tags"]:
    print("\n🏷️  TAG PIÙ USATI:")
    sorted_tags = sorted(db["tags"].items(), key=lambda x: x[1]["count"], reverse=True)[:10]
    for tag, data in sorted_tags:
        print(f"   #{tag}: {data['count']} usi")

# Suggerimenti basati su pattern
print("\n💡 SUGGERIMENTI BASATI SUI PATTERN:")
if error_patterns.get("performance", 0) > 3:
    print("   ⚡ Molte lezioni su performance - considera profiling regolare")
if error_patterns.get("security", 0) > 2:
    print("   🔒 Pattern di sicurezza ricorrenti - implementa security review")
if error_patterns.get("memory", 0) > 2:
    print("   💾 Problemi di memoria frequenti - monitora utilizzo risorse")

# Salva pattern analysis
patterns_data = {
    "analysis_date": datetime.now().isoformat() + "Z",
    "top_keywords": dict(word_freq.most_common(20)),
    "error_patterns": dict(error_patterns),
    "category_severity": dict(category_severity),
    "suggestions": []
}

with open("$PATTERNS_FILE", "w") as f:
    json.dump(patterns_data, f, indent=2)

print(f"\n💾 Analisi salvata in patterns.json")
EOF
}

# Funzione per dashboard
show_dashboard() {
    if [[ ! -f "$LEARNING_DB" ]]; then
        echo -e "${RED}❌ Nessuna lezione registrata${NC}"
        return 1
    fi
    
    echo -e "${PURPLE}📚 LEARNING TRACKER DASHBOARD${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime, timedelta

with open("$LEARNING_DB", "r") as f:
    db = json.load(f)

print("📊 STATISTICHE GLOBALI")
print("=" * 40)
print(f"📚 Lezioni totali: {db['stats']['total_learnings']}")
print(f"🛡️  Problemi prevenuti: {db['stats']['prevented_issues']}")
effectiveness = (db['stats']['prevented_issues'] / db['stats']['total_learnings'] * 100) if db['stats']['total_learnings'] > 0 else 0
print(f"📈 Efficacia: {effectiveness:.1f}%")
print()

# Severità
print("⚠️  DISTRIBUZIONE SEVERITÀ")
severity_icons = {"low": "🟢", "medium": "🟡", "high": "🟠", "critical": "🔴"}
for severity, count in db['stats']['by_severity'].items():
    icon = severity_icons.get(severity, "⚪")
    percentage = (count / db['stats']['total_learnings'] * 100) if db['stats']['total_learnings'] > 0 else 0
    print(f"   {icon} {severity.capitalize()}: {count} ({percentage:.1f}%)")
print()

# Categorie
print("📂 LEZIONI PER CATEGORIA")
for category, data in sorted(db['categories'].items(), key=lambda x: x[1]['count'], reverse=True):
    if data['count'] > 0:
        print(f"   • {category}: {data['count']} lezioni")
print()

# Lezioni più efficaci (che hanno prevenuto più problemi)
effective_learnings = sorted(
    [l for l in db['learnings'] if len(l['prevented_issues']) > 0],
    key=lambda x: len(x['prevented_issues']),
    reverse=True
)[:5]

if effective_learnings:
    print("🏆 LEZIONI PIÙ EFFICACI")
    for learning in effective_learnings:
        print(f"   • {learning['title']}")
        print(f"     Prevenuti: {len(learning['prevented_issues'])} problemi")
print()

# Trend ultimi 30 giorni
print("📈 TREND ULTIMI 30 GIORNI")
daily_counts = {}
for learning in db['learnings']:
    date = learning['timestamp'].split('T')[0]
    daily_counts[date] = daily_counts.get(date, 0) + 1

# Ordina e mostra ultimi 7 giorni con attività
recent_days = sorted(daily_counts.items(), reverse=True)[:7]
for date, count in recent_days:
    bar = "█" * min(count * 3, 20)
    print(f"   {date}: {bar} {count}")

# Quick insights
print("\n💡 QUICK INSIGHTS")
if db['stats']['total_learnings'] > 10:
    avg_preventions = db['stats']['prevented_issues'] / db['stats']['total_learnings']
    print(f"   • Media prevenzioni per lezione: {avg_preventions:.1f}")

high_severity = db['stats']['by_severity'].get('high', 0) + db['stats']['by_severity'].get('critical', 0)
if high_severity > 5:
    print(f"   • ⚠️  {high_severity} lezioni ad alta severità - considera review processo")

if db['tags']:
    print(f"   • 🏷️  {len(db['tags'])} tag unici utilizzati")
EOF
}

# Funzione per esportare lezioni
export_learnings() {
    local format="${1:-markdown}"
    local output="${2:-learnings-export}"
    
    if [[ ! -f "$LEARNING_DB" ]]; then
        echo -e "${RED}❌ Nessuna lezione da esportare${NC}"
        return 1
    fi
    
    case "$format" in
        "markdown")
            python3 << EOF
import json
from datetime import datetime

with open("$LEARNING_DB", "r") as f:
    db = json.load(f)

content = ["# Learning Tracker Report\n\n"]
content.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
content.append(f"Total learnings: {db['stats']['total_learnings']}\n")
content.append(f"Prevented issues: {db['stats']['prevented_issues']}\n\n")

# Per categoria
content.append("## Learnings by Category\n\n")
for category in ["critical", "high", "medium", "low"]:
    learnings = [l for l in db['learnings'] if l['severity'] == category]
    if learnings:
        content.append(f"### {category.upper()} Severity\n\n")
        for learning in sorted(learnings, key=lambda x: x['timestamp'], reverse=True):
            content.append(f"#### {learning['title']}\n")
            content.append(f"- **Date**: {learning['timestamp']}\n")
            content.append(f"- **Category**: {learning['category']}\n")
            content.append(f"- **Project**: {learning['project']}\n")
            content.append(f"- **Prevented**: {len(learning['prevented_issues'])} issues\n\n")
            content.append(f"**Lesson**: {learning['lesson']}\n\n")
            content.append(f"**Context**: {learning['context']}\n\n")
            if learning['tags']:
                content.append(f"**Tags**: {', '.join(['#' + tag for tag in learning['tags']])}\n\n")
            content.append("---\n\n")

with open("${output}.md", "w") as f:
    f.writelines(content)

print(f"✅ Esportato in ${output}.md")
EOF
            ;;
        "json")
            cp "$LEARNING_DB" "${output}.json"
            echo -e "${GREEN}✅ Esportato in ${output}.json${NC}"
            ;;
        *)
            echo -e "${RED}❌ Formato non supportato: $format${NC}"
            echo "Formati: markdown, json"
            return 1
            ;;
    esac
}

# Help
show_help() {
    echo "Claude Learning Tracker - Traccia lezioni apprese"
    echo ""
    echo "Uso: claude-learning-tracker [comando] [parametri]"
    echo ""
    echo "Comandi:"
    echo "  learn <titolo> <lezione> [contesto] [categoria] [severità] [progetto]"
    echo "      Registra una nuova lezione appresa"
    echo "      Categorie: bug-fix, performance, security, design, process"
    echo "      Severità: low, medium, high, critical"
    echo ""
    echo "  prevent <id> <descrizione> [impatto]"
    echo "      Registra quando una lezione previene un problema"
    echo ""
    echo "  search <query> [tipo]    - Cerca lezioni (all, category, tag, project, recent)"
    echo "  patterns                 - Analizza pattern comuni"
    echo "  dashboard                - Mostra dashboard"
    echo "  export [formato] [file]  - Esporta (markdown, json)"
    echo ""
    echo "Esempi:"
    echo "  claude-learning-tracker learn \"Always validate input\" \"SQL injection prevented by validating all user inputs\""
    echo "  claude-learning-tracker prevent learn-123456 \"Prevented XSS attack\" high"
    echo "  claude-learning-tracker patterns"
}

# Main
case "$1" in
    "learn")
        log_learning "$2" "$3" "$4" "$5" "$6" "$7"
        ;;
    "prevent")
        record_prevention "$2" "$3" "$4"
        ;;
    "search")
        search_learnings "$2" "$3"
        ;;
    "patterns")
        analyze_patterns
        ;;
    "dashboard")
        show_dashboard
        ;;
    "export")
        export_learnings "$2" "$3"
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