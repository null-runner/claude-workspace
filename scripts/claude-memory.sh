#!/bin/bash
# Claude Workspace - Memory Management Script
# Gestisce la memoria persistente di Claude

MEMORY_DIR="$HOME/claude-workspace/.claude/memory"
MEMORY_FILE="$MEMORY_DIR/workspace-memory.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Funzione per mostrare memoria dettagliata
show_detailed_memory() {
    if [[ ! -f "$MEMORY_FILE" ]]; then
        echo -e "${RED}❌ Nessuna memoria trovata${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🧠 MEMORIA CLAUDE WORKSPACE - DETTAGLIATA${NC}"
    echo "============================================="
    
    python3 << 'EOF'
import json
import sys
from datetime import datetime, timezone

try:
    with open("/home/nullrunner/claude-workspace/.claude/memory/workspace-memory.json", "r") as f:
        memory = json.load(f)
    
    # Header info
    print(f"Workspace ID: {memory.get('workspace_id', 'N/A')}")
    print(f"Versione memoria: {memory.get('version', 'N/A')}")
    print()
    
    # Sessione corrente dettagliata
    current = memory.get("current_session", {})
    if current:
        print("📍 SESSIONE CORRENTE:")
        print("─────────────────────")
        for key, value in current.items():
            if value is not None:
                if key in ['started_at', 'last_activity']:
                    # Formatta timestamp
                    dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
                    formatted = dt.strftime("%Y-%m-%d %H:%M:%S")
                    print(f"   {key}: {formatted}")
                elif key == 'active_project' and isinstance(value, dict):
                    print(f"   {key}: {value.get('name')} ({value.get('type')})")
                else:
                    print(f"   {key}: {value}")
        print()
    
    # Storico sessioni
    history = memory.get("session_history", [])
    if history:
        print("📜 STORICO SESSIONI (ultime 5):")
        print("─────────────────────────────────")
        for i, session in enumerate(history[:5]):
            start = session.get('started_at', 'N/A')
            if start != 'N/A':
                dt = datetime.fromisoformat(start.replace('Z', '+00:00'))
                date_str = dt.strftime("%Y-%m-%d %H:%M")
            else:
                date_str = 'N/A'
            
            device = session.get('device', 'N/A')
            note = session.get('session_note', '')
            project = session.get('active_project', {})
            project_name = project.get('name', 'Nessun progetto') if project else 'Nessun progetto'
            
            print(f"   {i+1}. {date_str} - {device}")
            print(f"      Progetto: {project_name}")
            if note:
                print(f"      Note: {note}")
            print()
    
    # Devices dettagliati
    devices = memory.get("devices", {})
    if devices:
        print("💻 DEVICES REGISTRATI:")
        print("──────────────────────")
        for device_name, device_info in devices.items():
            print(f"   {device_name}:")
            for key, value in device_info.items():
                if key == 'last_seen':
                    dt = datetime.fromisoformat(value.replace('Z', '+00:00'))
                    formatted = dt.strftime("%Y-%m-%d %H:%M:%S")
                    print(f"     {key}: {formatted}")
                else:
                    print(f"     {key}: {value}")
            print()
    
    # Context completo
    context = memory.get("context", {})
    if context:
        print("🎯 CONTEXT E OBIETTIVI:")
        print("─────────────────────────")
        for key, value in context.items():
            if isinstance(value, list):
                print(f"   {key}:")
                for item in value:
                    print(f"     - {item}")
            else:
                print(f"   {key}: {value}")
        print()
    
    # Settings
    settings = memory.get("settings", {})
    if settings:
        print("⚙️  CONFIGURAZIONI:")
        print("──────────────────")
        for key, value in settings.items():
            print(f"   {key}: {value}")
        print()

except Exception as e:
    print(f"❌ Errore nel leggere la memoria: {e}")
    sys.exit(1)
EOF
}

# Funzione per pulire memoria
clean_memory() {
    local what="$1"
    
    case "$what" in
        "history")
            echo -e "${YELLOW}🧹 Pulizia storico sessioni...${NC}"
            python3 << 'EOF'
import json
try:
    with open("/home/nullrunner/claude-workspace/.claude/memory/workspace-memory.json", "r") as f:
        memory = json.load(f)
    
    memory["session_history"] = []
    
    with open("/home/nullrunner/claude-workspace/.claude/memory/workspace-memory.json", "w") as f:
        json.dump(memory, f, indent=2)
    
    print("✅ Storico sessioni pulito")
except Exception as e:
    print(f"❌ Errore: {e}")
EOF
            ;;
        "projects")
            echo -e "${YELLOW}🧹 Pulizia progetti recenti...${NC}"
            python3 << 'EOF'
import json
try:
    with open("/home/nullrunner/claude-workspace/.claude/memory/workspace-memory.json", "r") as f:
        memory = json.load(f)
    
    memory["recent_projects"] = []
    
    with open("/home/nullrunner/claude-workspace/.claude/memory/workspace-memory.json", "w") as f:
        json.dump(memory, f, indent=2)
    
    print("✅ Lista progetti recenti pulita")
except Exception as e:
    print(f"❌ Errore: {e}")
EOF
            ;;
        "all")
            echo -e "${YELLOW}🧹 Reset completo memoria...${NC}"
            read -p "Sei sicuro? Questo cancellerà TUTTA la memoria (s/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Ss]$ ]]; then
                rm -f "$MEMORY_FILE"
                echo -e "${GREEN}✅ Memoria completamente resettata${NC}"
            else
                echo "❌ Operazione annullata"
            fi
            ;;
        *)
            echo "Uso: claude-memory clean [history|projects|all]"
            ;;
    esac
}

# Funzione per aggiornare context
update_context() {
    local goal="$1"
    shift
    local steps=("$@")
    
    if [[ -z "$goal" ]]; then
        echo "Uso: claude-memory context \"obiettivo\" \"step1\" \"step2\" ..."
        return 1
    fi
    
    echo -e "${YELLOW}🎯 Aggiornamento context...${NC}"
    
    python3 << EOF
import json
import sys

try:
    # Leggi memoria esistente
    try:
        with open("$MEMORY_FILE", "r") as f:
            memory = json.load(f)
    except FileNotFoundError:
        memory = {"context": {}}
    
    # Aggiorna context
    if "context" not in memory:
        memory["context"] = {}
    
    memory["context"]["current_goal"] = "$goal"
    memory["context"]["last_conversation_topic"] = "Aggiornamento obiettivi"
    
    steps_list = []
$(for step in "${steps[@]}"; do echo "    steps_list.append(\"$step\")"; done)
    
    if steps_list:
        memory["context"]["next_steps"] = steps_list
    
    # Salva
    with open("$MEMORY_FILE", "w") as f:
        json.dump(memory, f, indent=2)
    
    print("✅ Context aggiornato")
    print(f"   Obiettivo: $goal")
    if steps_list:
        print("   Prossimi passi:")
        for i, step in enumerate(steps_list):
            print(f"     {i+1}. {step}")

except Exception as e:
    print(f"❌ Errore: {e}")
    sys.exit(1)
EOF
}

# Gestione comandi
case "$1" in
    "show"|"")
        show_detailed_memory
        ;;
    "clean")
        clean_memory "$2"
        ;;
    "context")
        shift
        update_context "$@"
        ;;
    "--help"|"-h")
        echo "Uso: claude-memory [comando] [opzioni]"
        echo ""
        echo "Comandi:"
        echo "  show              Mostra memoria dettagliata (default)"
        echo "  clean [tipo]      Pulisce memoria (history/projects/all)"
        echo "  context <goal>    Aggiorna obiettivo corrente"
        echo ""
        echo "Esempi:"
        echo "  claude-memory"
        echo "  claude-memory clean history"
        echo "  claude-memory context \"Creare sito web\" \"Design homepage\" \"Setup database\""
        ;;
    *)
        echo "❌ Comando non riconosciuto: $1"
        echo "Usa 'claude-memory --help' per vedere i comandi disponibili"
        exit 1
        ;;
esac