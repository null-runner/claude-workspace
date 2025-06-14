#!/bin/bash
# Claude Workspace - Resume Session Script
# Riprende l'ultima sessione salvata

MEMORY_DIR="$HOME/claude-workspace/.claude/memory"
MEMORY_FILE="$MEMORY_DIR/workspace-memory.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Verifica se esiste memoria
if [[ ! -f "$MEMORY_FILE" ]]; then
    echo -e "${RED}❌ Nessuna sessione salvata trovata${NC}"
    echo "💡 Usa 'claude-save' per iniziare a salvare sessioni"
    exit 1
fi

# Funzione per mostrare memoria
show_memory() {
    echo -e "${BLUE}🧠 MEMORIA CLAUDE WORKSPACE${NC}"
    echo "============================="
    
    python3 << 'EOF'
import json
import sys
from datetime import datetime, timezone

try:
    with open("/home/nullrunner/claude-workspace/.claude/memory/workspace-memory.json", "r") as f:
        memory = json.load(f)
    
    # Sessione corrente
    current = memory.get("current_session", {})
    if current:
        print(f"\n📍 ULTIMA SESSIONE:")
        print(f"   Device: {current.get('device', 'N/A')}")
        
        if current.get('last_activity'):
            # Calcola tempo trascorso
            from datetime import datetime
            last_time = datetime.fromisoformat(current['last_activity'].replace('Z', '+00:00'))
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
            
            print(f"   Quando: {time_ago}")
        
        if current.get('active_project'):
            proj = current['active_project']
            print(f"   Progetto: {proj['name']} ({proj['type']})")
        
        if current.get('session_note'):
            print(f"   Note: {current['session_note']}")
        
        if current.get('working_directory'):
            print(f"   Directory: {current['working_directory']}")
    
    # Progetti recenti
    recent_projects = memory.get("recent_projects", [])
    if recent_projects:
        print(f"\n📁 PROGETTI RECENTI:")
        for i, proj in enumerate(recent_projects[:5]):
            status = "🟢" if proj.get('device') == current.get('device') else "🔵"
            print(f"   {i+1}. {status} {proj['name']} ({proj['type']}) - {proj.get('device', 'N/A')}")
    
    # Devices
    devices = memory.get("devices", {})
    if devices:
        print(f"\n💻 DEVICES:")
        for device_name, device_info in devices.items():
            status = "🟢 Online" if device_info.get('active') else "⚪ Offline"
            device_type = device_info.get('type', 'unknown')
            print(f"   {device_name} ({device_type}): {status}")
    
    # Context/obiettivi
    context = memory.get("context", {})
    if context:
        if context.get("current_goal"):
            print(f"\n🎯 OBIETTIVO CORRENTE:")
            print(f"   {context['current_goal']}")
        
        if context.get("next_steps"):
            print(f"\n📋 PROSSIMI PASSI:")
            for i, step in enumerate(context["next_steps"][:3]):
                print(f"   {i+1}. {step}")

except Exception as e:
    print(f"❌ Errore nel leggere la memoria: {e}")
    sys.exit(1)
EOF
}

# Funzione per riprendere ultimo progetto
resume_project() {
    python3 << 'EOF'
import json
import os
import sys

try:
    with open("/home/nullrunner/claude-workspace/.claude/memory/workspace-memory.json", "r") as f:
        memory = json.load(f)
    
    current = memory.get("current_session", {})
    active_project = current.get("active_project")
    
    if active_project:
        project_path = f"/home/nullrunner/claude-workspace/projects/{active_project['path']}"
        if os.path.exists(project_path):
            print(f"cd {project_path}")
            print(f"🚀 Riprendendo progetto: {active_project['name']}")
            
            # Mostra file recenti del progetto
            print(f"\n📝 File recenti modificati:")
            import glob
            import time
            
            files = []
            for ext in ['*.py', '*.js', '*.jsx', '*.ts', '*.tsx', '*.md', '*.json']:
                files.extend(glob.glob(f"{project_path}/**/{ext}", recursive=True))
            
            # Ordina per tempo di modifica
            files.sort(key=lambda x: os.path.getmtime(x), reverse=True)
            
            for i, file in enumerate(files[:3]):
                rel_path = file.replace(project_path + "/", "")
                mod_time = time.ctime(os.path.getmtime(file))
                print(f"   {i+1}. {rel_path}")
            
            if len(files) > 3:
                print(f"   ... e altri {len(files)-3} file")
        else:
            print(f"⚠️  Progetto {active_project['name']} non trovato")
    else:
        print("💡 Nessun progetto attivo nella sessione precedente")
        recent_projects = memory.get("recent_projects", [])
        if recent_projects:
            print(f"\n📁 Progetti recenti disponibili:")
            for i, proj in enumerate(recent_projects[:3]):
                print(f"   {i+1}. {proj['name']} ({proj['type']})")
            print(f"\n💡 Usa: claude-goto <numero> per aprire un progetto")

except Exception as e:
    print(f"❌ Errore: {e}")
    sys.exit(1)
EOF
}

# Gestione parametri
case "$1" in
    "--show" | "-s")
        show_memory
        ;;
    "--project" | "-p")
        resume_project
        ;;
    "--help" | "-h")
        echo "Uso: claude-resume [opzione]"
        echo ""
        echo "Opzioni:"
        echo "  --show, -s     Mostra memoria completa"
        echo "  --project, -p  Riprendi ultimo progetto"
        echo "  --help, -h     Mostra questo help"
        echo ""
        echo "Senza opzioni: mostra memoria e riprende progetto"
        ;;
    *)
        show_memory
        echo ""
        resume_project
        ;;
esac