#!/usr/bin/env python3
"""
TODO Parser - Conversione bidirezionale TODO.md ↔ TodoWrite format
Garantisce persistenza TODO tra sessioni Claude Code
"""

import json
import re
import sys
from typing import List, Dict, Any
from pathlib import Path

def parse_todo_md_to_json(todo_file: str) -> List[Dict[str, Any]]:
    """Parse TODO.md file e converte in formato TodoWrite JSON"""
    
    if not Path(todo_file).exists():
        return []
    
    with open(todo_file, 'r', encoding='utf-8') as f:
        content = f.read()
    
    todos = []
    todo_id = 1
    
    # Pattern per matching task nel TODO.md
    # Matches: ### Task Name, #### Task Name, **Status**: status, - **Status**: status
    patterns = [
        # Pattern per sezioni principali (### Nome Task)
        r'^###\s+(.+?)$',
        # Pattern per status in task
        r'- \*\*Status\*\*:\s*(.+?)$',
        r'\*\*Status\*\*:\s*(.+?)$',
        # Pattern per ~~completed tasks~~
        r'^###\s+~~(.+?)~~',
    ]
    
    lines = content.split('\n')
    current_task = None
    
    for line in lines:
        line = line.strip()
        
        # Skip headers e linee vuote
        if not line or line.startswith('#') and len(line.split()) == 1:
            continue
            
        # Match task headers
        if line.startswith('### '):
            task_name = line[4:].strip()
            
            # Check se è completed (strikethrough)
            if task_name.startswith('~~') and task_name.endswith('~~'):
                task_name = task_name[2:-2]
                status = "completed"
            else:
                status = "pending"
            
            # Determina priorità dal context
            priority = "medium"
            if "CRITIC" in task_name.upper() or "URGENT" in task_name.upper():
                priority = "high"
            elif "PROGRESS" in task_name or "IN PROGRESS" in task_name:
                status = "in_progress"
            
            current_task = {
                "id": str(todo_id),
                "content": task_name,
                "status": status,
                "priority": priority
            }
            todos.append(current_task)
            todo_id += 1
            
        # Match status updates
        elif current_task and ("**Status**:" in line or "Status**:" in line):
            status_match = re.search(r'\*\*Status\*\*:\s*(.+?)(?:\s|$)', line)
            if status_match:
                status_text = status_match.group(1).lower()
                
                if "progress" in status_text or "🔄" in status_text:
                    current_task["status"] = "in_progress"
                elif "completed" in status_text or "✅" in status_text:
                    current_task["status"] = "completed"
                elif "pending" in status_text:
                    current_task["status"] = "pending"
    
    return todos

def convert_todos_to_md_section(todos: List[Dict[str, Any]]) -> str:
    """Converte lista TodoWrite in sezione TODO.md"""
    
    if not todos:
        return ""
    
    md_content = []
    
    # Raggruppa per status
    completed = [t for t in todos if t["status"] == "completed"]
    in_progress = [t for t in todos if t["status"] == "in_progress"]
    pending_high = [t for t in todos if t["status"] == "pending" and t["priority"] == "high"]
    pending_medium = [t for t in todos if t["status"] == "pending" and t["priority"] == "medium"]
    pending_low = [t for t in todos if t["status"] == "pending" and t["priority"] == "low"]
    
    # Sezione completati
    if completed:
        md_content.append("## ✅ COMPLETATI SESSIONE CORRENTE\n")
        for todo in completed:
            md_content.append(f"### ~~{todo['content']}~~")
            md_content.append("- **Status**: ✅ COMPLETATO\n")
    
    # Sezione in progress
    if in_progress:
        md_content.append("## 🔄 IN PROGRESS\n")
        for todo in in_progress:
            md_content.append(f"### {todo['content']}")
            md_content.append("- **Status**: 🔄 IN PROGRESS\n")
    
    # Sezione pending alta priorità
    if pending_high:
        md_content.append("## 🚨 PRIORITÀ ALTA\n")
        for todo in pending_high:
            md_content.append(f"### {todo['content']}")
            md_content.append("- **Status**: Pending\n")
    
    # Sezione pending media priorità
    if pending_medium:
        md_content.append("## 🎯 PRIORITÀ MEDIA\n")
        for todo in pending_medium:
            md_content.append(f"### {todo['content']}")
            md_content.append("- **Status**: Pending\n")
    
    # Sezione pending bassa priorità
    if pending_low:
        md_content.append("## 📝 PRIORITÀ BASSA\n")
        for todo in pending_low:
            md_content.append(f"### {todo['content']}")
            md_content.append("- **Status**: Pending\n")
    
    return "\n".join(md_content)

def update_todo_md_with_session_todos(todo_file: str, session_todos: List[Dict[str, Any]]):
    """Aggiorna TODO.md inserendo session todos in sezione dedicata"""
    
    # Leggi TODO.md esistente
    if Path(todo_file).exists():
        with open(todo_file, 'r', encoding='utf-8') as f:
            content = f.read()
    else:
        content = "# Claude Workspace TODO List\n\n"
    
    # Trova e rimuovi sezione session esistente
    session_pattern = r'## ✅ COMPLETATI SESSIONE CORRENTE.*?(?=##|$)'
    content = re.sub(session_pattern, '', content, flags=re.DOTALL)
    
    progress_pattern = r'## 🔄 IN PROGRESS.*?(?=##|$)'
    content = re.sub(progress_pattern, '', content, flags=re.DOTALL)
    
    # Genera nuova sezione session
    session_section = convert_todos_to_md_section(session_todos)
    
    # Inserisci dopo header principale
    if session_section:
        lines = content.split('\n')
        insert_pos = 2  # Dopo "# Claude Workspace TODO List" e linea vuota
        
        lines.insert(insert_pos, session_section)
        lines.insert(insert_pos + 1, "\n---\n")
        
        content = '\n'.join(lines)
    
    # Scrivi file aggiornato
    with open(todo_file, 'w', encoding='utf-8') as f:
        f.write(content)

def main():
    if len(sys.argv) < 2:
        print("Usage: todo-parser.py {parse|update} [file] [json_data]")
        sys.exit(1)
    
    command = sys.argv[1]
    
    if command == "parse":
        todo_file = sys.argv[2] if len(sys.argv) > 2 else "TODO.md"
        todos = parse_todo_md_to_json(todo_file)
        print(json.dumps(todos, indent=2))
        
    elif command == "update":
        todo_file = sys.argv[2] if len(sys.argv) > 2 else "TODO.md"
        json_data = sys.argv[3] if len(sys.argv) > 3 else "[]"
        
        try:
            todos = json.loads(json_data)
            update_todo_md_with_session_todos(todo_file, todos)
            print(f"✅ TODO.md updated with {len(todos)} session todos")
        except json.JSONDecodeError as e:
            print(f"❌ Invalid JSON data: {e}")
            sys.exit(1)
    
    else:
        print(f"❌ Unknown command: {command}")
        sys.exit(1)

if __name__ == "__main__":
    main()