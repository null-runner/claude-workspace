#!/bin/bash
# Claude Workspace - Intelligent Memory Cleaner
# Pulizia intelligente memoria senza perdere informazioni importanti

MEMORY_BASE="$HOME/claude-workspace/.claude/memory"
PROJECT_MEMORY_DIR="$MEMORY_BASE/projects"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Funzione per compattare memoria progetto
compress_project_memory() {
    local project_memory_file="$1"
    
    if [[ ! -f "$project_memory_file" ]]; then
        return 1
    fi
    
    echo -e "${YELLOW}🧹 Compattazione intelligente: $(basename "$project_memory_file" .json)${NC}"
    
    python3 << 'EOF'
import json
import sys
from datetime import datetime, timedelta
from collections import Counter

try:
    memory_file = "$project_memory_file"
    
    with open(memory_file, "r") as f:
        memory = json.load(f)
    
    changes_made = []
    
    # 1. COMPATTA STORICO SESSIONI
    sessions = memory.get("session_history", [])
    if len(sessions) > 20:
        # Mantieni ultime 20 sessioni
        recent_sessions = sessions[:20]
        old_sessions = sessions[20:]
        
        # Estrai pattern e informazioni importanti dalle vecchie sessioni
        if old_sessions:
            # Analizza pattern di lavoro
            devices_used = Counter([s.get('device', 'unknown') for s in old_sessions])
            common_tasks = [s.get('task') for s in old_sessions if s.get('task')]
            important_notes = [s.get('note') for s in old_sessions if s.get('note') and len(s.get('note', '')) > 20]
            
            # Crea summary delle sessioni archiviate
            archived_summary = {
                "period": f"{old_sessions[-1].get('timestamp', 'unknown')} to {old_sessions[0].get('timestamp', 'unknown')}",
                "total_sessions": len(old_sessions),
                "devices_used": dict(devices_used),
                "common_patterns": {
                    "frequent_tasks": list(set([t for t in common_tasks if t]))[:5],
                    "important_notes": important_notes[:3]
                },
                "compressed_at": datetime.utcnow().isoformat() + "Z"
            }
            
            # Aggiungi a archived_data
            if "archived_data" not in memory:
                memory["archived_data"] = {}
            if "session_summaries" not in memory["archived_data"]:
                memory["archived_data"]["session_summaries"] = []
            
            memory["archived_data"]["session_summaries"].insert(0, archived_summary)
            # Mantieni solo ultimi 5 summary
            memory["archived_data"]["session_summaries"] = memory["archived_data"]["session_summaries"][:5]
        
        memory["session_history"] = recent_sessions
        changes_made.append(f"Compattate {len(old_sessions)} sessioni vecchie")
    
    # 2. COMPATTA NOTE TEMPORANEE  
    context = memory.get("current_context", {})
    notes = context.get("notes", [])
    if len(notes) > 10:
        recent_notes = notes[:10]
        old_notes = notes[10:]
        
        # Identifica note importanti (lunghe, con keywords)
        important_keywords = ["TODO", "IMPORTANTE", "BUG", "ERRORE", "PROBLEMA", "SOLUZIONE", "IDEA"]
        important_old_notes = []
        
        for note in old_notes:
            content = note.get('content', '').upper()
            if any(keyword in content for keyword in important_keywords) or len(content) > 50:
                important_old_notes.append({
                    "content": note.get('content', ''),
                    "timestamp": note.get('timestamp', ''),
                    "importance": "archived"
                })
        
        # Salva note importanti in archived_data
        if important_old_notes:
            if "archived_data" not in memory:
                memory["archived_data"] = {}
            if "important_notes" not in memory["archived_data"]:
                memory["archived_data"]["important_notes"] = []
            
            memory["archived_data"]["important_notes"].extend(important_old_notes[:5])
            # Mantieni solo ultime 20 note importanti archiviate
            memory["archived_data"]["important_notes"] = memory["archived_data"]["important_notes"][:20]
        
        context["notes"] = recent_notes
        changes_made.append(f"Archiviate {len(old_notes)} note vecchie, salvate {len(important_old_notes)} importanti")
    
    # 3. COMPATTA TODO COMPLETATI
    completed = context.get("completed", [])
    if len(completed) > 15:
        recent_completed = completed[:15]
        old_completed = completed[15:]
        
        # Crea statistiche completamenti
        completion_stats = {
            "total_completed_archived": len(old_completed),
            "completion_period": f"{old_completed[-1].get('completed_at', 'unknown')} to {old_completed[0].get('completed_at', 'unknown')}",
            "archived_at": datetime.utcnow().isoformat() + "Z"
        }
        
        if "archived_data" not in memory:
            memory["archived_data"] = {}
        memory["archived_data"]["completion_stats"] = completion_stats
        
        context["completed"] = recent_completed
        changes_made.append(f"Archiviati {len(old_completed)} TODO completati")
    
    # 4. OTTIMIZZA FILE ATTIVI (mantieni solo file realmente esistenti)
    active_files = context.get("active_files", [])
    if active_files:
        project_path = memory.get("project_info", {}).get("path", "").replace("~", "/home/nullrunner")
        if project_path:
            existing_files = []
            for file in active_files:
                full_path = f"{project_path}/{file}"
                try:
                    import os
                    if os.path.exists(full_path):
                        existing_files.append(file)
                except:
                    pass
            
            if len(existing_files) != len(active_files):
                context["active_files"] = existing_files[:10]  # Mantieni solo ultimi 10
                changes_made.append(f"Rimossi {len(active_files) - len(existing_files)} file non esistenti")
    
    # 5. AGGIORNA METADATA PULIZIA
    if "maintenance" not in memory:
        memory["maintenance"] = {}
    
    memory["maintenance"]["last_cleanup"] = datetime.utcnow().isoformat() + "Z"
    memory["maintenance"]["cleanup_count"] = memory["maintenance"].get("cleanup_count", 0) + 1
    memory["maintenance"]["changes_made"] = changes_made
    
    # Salva memoria ottimizzata
    with open(memory_file, "w") as f:
        json.dump(memory, f, indent=2)
    
    if changes_made:
        print(f"✅ Ottimizzazioni applicate:")
        for change in changes_made:
            print(f"   • {change}")
    else:
        print("✅ Memoria già ottimizzata")
    
except Exception as e:
    print(f"❌ Errore nella compattazione: {e}")
    sys.exit(1)
EOF
}

# Funzione per calcolare dimensione memoria
calculate_memory_size() {
    local total_size=0
    
    if [[ -d "$PROJECT_MEMORY_DIR" ]]; then
        for file in "$PROJECT_MEMORY_DIR"/*.json; do
            if [[ -f "$file" ]]; then
                local size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                total_size=$((total_size + size))
            fi
        done
    fi
    
    # Converti in formato leggibile
    if [[ $total_size -gt 1048576 ]]; then
        echo "$(($total_size / 1048576))MB"
    elif [[ $total_size -gt 1024 ]]; then
        echo "$(($total_size / 1024))KB"
    else
        echo "${total_size}B"
    fi
}

# Funzione per pulizia automatica intelligente
auto_cleanup() {
    local force="$1"
    
    echo -e "${BLUE}🧹 PULIZIA INTELLIGENTE MEMORIA${NC}"
    echo "================================="
    
    local memory_size=$(calculate_memory_size)
    echo "📊 Dimensione memoria attuale: $memory_size"
    
    local projects_processed=0
    local total_projects=0
    
    if [[ -d "$PROJECT_MEMORY_DIR" ]]; then
        for file in "$PROJECT_MEMORY_DIR"/*.json; do
            if [[ -f "$file" ]]; then
                total_projects=$((total_projects + 1))
                
                # Verifica se serve pulizia
                local needs_cleanup=false
                
                # Controlla dimensione file
                local file_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo "0")
                if [[ $file_size -gt 50000 ]]; then  # > 50KB
                    needs_cleanup=true
                fi
                
                # Controlla età ultima pulizia
                local last_cleanup=$(python3 -c "
import json
try:
    with open('$file', 'r') as f:
        data = json.load(f)
    last = data.get('maintenance', {}).get('last_cleanup')
    if last:
        from datetime import datetime, timedelta
        last_dt = datetime.fromisoformat(last.replace('Z', '+00:00'))
        week_ago = datetime.now().astimezone() - timedelta(days=7)
        print('old' if last_dt < week_ago else 'recent')
    else:
        print('never')
except:
    print('never')
" 2>/dev/null)
                
                if [[ "$last_cleanup" == "never" || "$last_cleanup" == "old" || "$force" == "--force" ]]; then
                    needs_cleanup=true
                fi
                
                if [[ "$needs_cleanup" == true ]]; then
                    compress_project_memory "$file"
                    projects_processed=$((projects_processed + 1))
                fi
            fi
        done
    fi
    
    local new_memory_size=$(calculate_memory_size)
    
    echo ""
    echo -e "${GREEN}✅ Pulizia completata${NC}"
    echo "📊 Progetti totali: $total_projects"
    echo "🧹 Progetti processati: $projects_processed"
    echo "💾 Dimensione prima: $memory_size"
    echo "💾 Dimensione dopo: $new_memory_size"
}

# Funzione per statistiche memoria
show_stats() {
    echo -e "${BLUE}📊 STATISTICHE MEMORIA PROGETTI${NC}"
    echo "=================================="
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

project_dir = "$PROJECT_MEMORY_DIR"
total_files = 0
total_size = 0
projects_with_archived = 0
total_sessions = 0
total_notes = 0
total_todos = 0

if os.path.exists(project_dir):
    for filename in os.listdir(project_dir):
        if filename.endswith('.json'):
            file_path = os.path.join(project_dir, filename)
            total_files += 1
            
            # Calcola dimensione
            file_size = os.path.getsize(file_path)
            total_size += file_size
            
            try:
                with open(file_path, 'r') as f:
                    data = json.load(f)
                
                # Conta elementi
                sessions = len(data.get('session_history', []))
                notes = len(data.get('current_context', {}).get('notes', []))
                todos = len(data.get('current_context', {}).get('todo', [])) + len(data.get('current_context', {}).get('completed', []))
                
                total_sessions += sessions
                total_notes += notes  
                total_todos += todos
                
                # Verifica se ha dati archiviati
                if 'archived_data' in data:
                    projects_with_archived += 1
                
                # Info progetto
                project_info = data.get('project_info', {})
                project_name = project_info.get('name', filename.replace('.json', ''))
                
                print(f"📁 {project_name}:")
                print(f"   Dimensione: {file_size:,} bytes")
                print(f"   Sessioni: {sessions}, Note: {notes}, TODO: {todos}")
                
                # Ultima attività
                last_activity = data.get('current_context', {}).get('last_activity')
                if last_activity:
                    try:
                        dt = datetime.fromisoformat(last_activity.replace('Z', '+00:00'))
                        days_ago = (datetime.now().astimezone() - dt).days
                        print(f"   Ultima attività: {days_ago} giorni fa")
                    except:
                        print(f"   Ultima attività: {last_activity}")
                
                if 'archived_data' in data:
                    archived_sessions = len(data['archived_data'].get('session_summaries', []))
                    archived_notes = len(data['archived_data'].get('important_notes', []))
                    print(f"   📦 Archiviati: {archived_sessions} session summaries, {archived_notes} note importanti")
                
                print()
                
            except Exception as e:
                print(f"❌ Errore nel leggere {filename}: {e}")

print(f"TOTALI:")
print(f"├─ Progetti: {total_files}")
print(f"├─ Dimensione totale: {total_size:,} bytes ({total_size/1024:.1f} KB)")
print(f"├─ Con dati archiviati: {projects_with_archived}")
print(f"├─ Sessioni totali: {total_sessions}")
print(f"├─ Note totali: {total_notes}")
print(f"└─ TODO totali: {total_todos}")

# Calcola media
if total_files > 0:
    avg_size = total_size / total_files
    print(f"\nMEDIE:")
    print(f"├─ Dimensione media progetto: {avg_size:.0f} bytes")
    print(f"├─ Sessioni per progetto: {total_sessions/total_files:.1f}")
    print(f"└─ Note per progetto: {total_notes/total_files:.1f}")
EOF
}

# Main script
case "$1" in
    "auto")
        auto_cleanup "$2"
        ;;
    "stats")
        show_stats
        ;;
    "project")
        if [[ -n "$2" ]]; then
            project_file="$PROJECT_MEMORY_DIR/${2//\//_}.json"
            if [[ -f "$project_file" ]]; then
                compress_project_memory "$project_file"
            else
                echo -e "${RED}❌ Progetto non trovato: $2${NC}"
            fi
        else
            echo "Uso: claude-memory-cleaner project <nome_progetto>"
        fi
        ;;
    "--help"|"-h")
        echo "Uso: claude-memory-cleaner [comando] [opzioni]"
        echo ""
        echo "Comandi:"
        echo "  auto [--force]         Pulizia automatica intelligente"
        echo "  stats                  Mostra statistiche memoria"
        echo "  project <nome>         Pulisci progetto specifico"
        echo ""
        echo "La pulizia automatica preserva:"
        echo "  ✅ Stato corrente progetto"
        echo "  ✅ Obiettivi e TODO attivi"
        echo "  ✅ Note tecniche importanti"
        echo "  ✅ File attivi esistenti"
        echo ""
        echo "Compatta intelligentemente:"
        echo "  🔄 Storico sessioni (mantiene ultime 20)"
        echo "  🔄 Note temporanee (mantiene ultime 10)" 
        echo "  🔄 TODO completati (mantiene ultimi 15)"
        echo "  📦 Archivia informazioni importanti"
        ;;
    *)
        echo "🧹 Pulizia intelligente memoria - Help disponibile con --help"
        echo ""
        echo "Comandi rapidi:"
        echo "  claude-memory-cleaner auto      # Pulizia automatica"
        echo "  claude-memory-cleaner stats     # Vedi statistiche"
        ;;
esac