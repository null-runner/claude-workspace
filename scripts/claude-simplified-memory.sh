#!/bin/bash
# Claude Simplified Memory - Enhanced Sessions puramente per Claude Context
# Solo context restoration, no activity tracking, no scoring

WORKSPACE_DIR="$HOME/claude-workspace"
MEMORY_DIR="$WORKSPACE_DIR/.claude/memory"
CONTEXT_FILE="$MEMORY_DIR/enhanced-context.json"
CONTEXT_BACKUP="$MEMORY_DIR/enhanced-context.json.backup"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$MEMORY_DIR"

# Funzione per salvare context semplificato
save_context() {
    local save_reason="${1:-manual}"
    local conversation_summary="${2:-}"
    local open_issues="${3:-}"
    local next_actions="${4:-}"
    
    echo -e "${YELLOW}💾 Saving simplified context...${NC}"
    
    # Backup del context precedente
    if [[ -f "$CONTEXT_FILE" ]]; then
        cp "$CONTEXT_FILE" "$CONTEXT_BACKUP"
    fi
    
    export save_reason conversation_summary open_issues next_actions
    export WORKSPACE_DIR CONTEXT_FILE
    
    python3 << 'EOF'
import json
import os
import subprocess
from datetime import datetime

def get_git_status():
    """Get simplified git status"""
    try:
        # Check if we're in a git repository
        subprocess.run(['git', 'rev-parse', '--git-dir'], 
                      capture_output=True, check=True, 
                      cwd=os.environ.get('WORKSPACE_DIR'))
        
        # Get current branch
        branch_result = subprocess.run(['git', 'branch', '--show-current'], 
                                     capture_output=True, text=True,
                                     cwd=os.environ.get('WORKSPACE_DIR'))
        current_branch = branch_result.stdout.strip() if branch_result.returncode == 0 else "unknown"
        
        # Check for changes
        status_result = subprocess.run(['git', 'status', '--porcelain'], 
                                     capture_output=True, text=True,
                                     cwd=os.environ.get('WORKSPACE_DIR'))
        
        if status_result.returncode == 0:
            dirty_files = [line for line in status_result.stdout.strip().split('\n') if line]
            has_changes = len(dirty_files) > 0
            dirty_files_count = len(dirty_files)
        else:
            has_changes = False
            dirty_files_count = 0
        
        # Get last commit info
        try:
            commit_result = subprocess.run(['git', 'log', '-1', '--oneline'], 
                                         capture_output=True, text=True,
                                         cwd=os.environ.get('WORKSPACE_DIR'))
            last_commit = commit_result.stdout.strip() if commit_result.returncode == 0 else "No commits"
        except:
            last_commit = "No commits"
        
        return {
            "branch": current_branch,
            "has_changes": has_changes,
            "dirty_files_count": dirty_files_count,
            "last_commit": last_commit,
            "is_git_repo": True
        }
        
    except subprocess.CalledProcessError:
        return {
            "branch": "not-a-git-repo",
            "has_changes": False,
            "dirty_files_count": 0,
            "last_commit": "Not a git repository",
            "is_git_repo": False
        }

def get_current_project():
    """Detect current project from working directory"""
    try:
        cwd = os.getcwd()
        workspace_dir = os.environ.get('WORKSPACE_DIR')
        
        if workspace_dir and cwd.startswith(workspace_dir):
            # Check if we're in projects/active/PROJECT_NAME
            relative_path = os.path.relpath(cwd, workspace_dir)
            path_parts = relative_path.split(os.sep)
            
            if len(path_parts) >= 3 and path_parts[0] == "projects" and path_parts[1] == "active":
                return path_parts[2]
            elif len(path_parts) >= 2 and path_parts[0] == "projects":
                return path_parts[1]
        
        return None
    except:
        return None

def parse_env_arrays(env_var):
    """Parse environment variable as array"""
    value = os.environ.get(env_var, '')
    if not value:
        return []
    # Simple parsing: split by comma and strip whitespace
    return [item.strip() for item in value.split(',') if item.strip()]

# Get environment variables
save_reason = os.environ.get('save_reason', 'manual')
conversation_summary = os.environ.get('conversation_summary', '')
open_issues_str = os.environ.get('open_issues', '')
next_actions_str = os.environ.get('next_actions', '')

# Parse arrays
open_issues = parse_env_arrays('open_issues') if open_issues_str else []
next_actions = parse_env_arrays('next_actions') if next_actions_str else []

# Create simplified context
context = {
    "session_id": datetime.now().isoformat() + "Z",
    "timestamp": datetime.now().isoformat() + "Z", 
    "device": os.uname().nodename,
    "working_directory": os.getcwd(),
    "current_project": get_current_project(),
    "git_status": get_git_status(),
    "conversation_summary": conversation_summary or None,
    "open_issues": open_issues,
    "next_actions": next_actions,
    "last_save_reason": save_reason,
    "context_version": "simplified-v1"
}

# Save context
context_file = os.environ.get('CONTEXT_FILE')
with open(context_file, 'w') as f:
    json.dump(context, f, indent=2)

print(f"✅ Context saved successfully")
print(f"📁 Project: {context['current_project'] or 'None detected'}")
print(f"🌿 Branch: {context['git_status']['branch']}")
print(f"📝 Changes: {context['git_status']['dirty_files_count']} files")
print(f"💡 Reason: {save_reason}")

EOF
}

# Funzione per caricare context
load_context() {
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        echo -e "${YELLOW}⚠️  No saved context found${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🧠 Loading context...${NC}"
    
    export CONTEXT_FILE
    
    python3 << 'EOF'
import json
import os
from datetime import datetime, timedelta

context_file = os.environ.get('CONTEXT_FILE')
try:
    with open(context_file, 'r') as f:
        context = json.load(f)
    
    print(f"📅 Last session: {context.get('timestamp', 'Unknown')}")
    print(f"💻 Device: {context.get('device', 'Unknown')}")
    print(f"📁 Project: {context.get('current_project') or 'None'}")
    print(f"🌿 Branch: {context['git_status']['branch']}")
    
    if context['git_status']['has_changes']:
        print(f"📝 Uncommitted changes: {context['git_status']['dirty_files_count']} files")
    else:
        print("✅ Working directory clean")
    
    if context.get('conversation_summary'):
        print(f"💬 Last conversation: {context['conversation_summary']}")
    
    if context.get('open_issues'):
        print("🚨 Open issues:")
        for issue in context['open_issues']:
            print(f"   • {issue}")
    
    if context.get('next_actions'):
        print("🎯 Next actions:")
        for action in context['next_actions']:
            print(f"   • {action}")
    
except Exception as e:
    print(f"❌ Error loading context: {e}")

EOF
}

# Funzione per check se deve salvare
should_save_context() {
    export WORKSPACE_DIR CONTEXT_FILE
    
    python3 << 'EOF'
import json
import os
import subprocess
from datetime import datetime, timedelta

def should_save():
    # Check git status
    try:
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True,
                              cwd=os.environ.get('WORKSPACE_DIR'))
        git_dirty = bool(result.stdout.strip()) if result.returncode == 0 else False
    except:
        git_dirty = False
    
    # Check last save time
    context_file = os.environ.get('CONTEXT_FILE')
    if context_file and os.path.exists(context_file):
        try:
            with open(context_file, 'r') as f:
                context = json.load(f)
            
            last_save = datetime.fromisoformat(context['timestamp'].replace('Z', ''))
            time_diff = datetime.now() - last_save
            time_based_save = time_diff > timedelta(minutes=30)
        except:
            time_based_save = True
    else:
        time_based_save = True
    
    # Decision logic
    if git_dirty:
        print("SAVE:git_dirty")
        return
    elif time_based_save:
        print("SAVE:time_based")
        return
    else:
        print("SKIP:recent_and_clean")
        return

should_save()
EOF
}

# Funzione per auto-save intelligente
auto_save_context() {
    local decision_output=$(should_save_context)
    local decision=$(echo "$decision_output" | cut -d: -f1)
    local reason=$(echo "$decision_output" | cut -d: -f2)
    
    if [[ "$decision" == "SAVE" ]]; then
        echo -e "${GREEN}🤖 Auto-saving context: $reason${NC}"
        save_context "$reason"
        return 0
    else
        echo -e "${BLUE}ℹ️  Context save skipped: $reason${NC}"
        return 1
    fi
}

# Funzione per migrare da old format
migrate_from_old_format() {
    local old_enhanced="$MEMORY_DIR/enhanced-sessions.json"
    local old_current="$MEMORY_DIR/current-session-context.json"
    
    if [[ -f "$old_current" && ! -f "$CONTEXT_FILE" ]]; then
        echo -e "${YELLOW}🔄 Migrating from old format...${NC}"
        
        python3 << 'EOF'
import json
import os

old_file = os.environ.get('MEMORY_DIR') + '/current-session-context.json'
new_file = os.environ.get('CONTEXT_FILE')

try:
    with open(old_file, 'r') as f:
        old_context = json.load(f)
    
    # Extract relevant info for simplified format
    new_context = {
        "session_id": old_context.get('id', ''),
        "timestamp": old_context.get('timestamp', ''),
        "device": old_context.get('device', ''),
        "working_directory": old_context.get('working_directory', ''),
        "current_project": old_context.get('active_project'),
        "git_status": {
            "branch": old_context.get('git_status', {}).get('branch', 'unknown'),
            "has_changes": old_context.get('git_status', {}).get('has_changes', False),
            "dirty_files_count": len(old_context.get('modified_files', [])),
            "last_commit": old_context.get('git_status', {}).get('last_commit', ''),
            "is_git_repo": True
        },
        "conversation_summary": old_context.get('conversation_summary'),
        "open_issues": old_context.get('incomplete_tasks', []),
        "next_actions": old_context.get('next_steps', []),
        "last_save_reason": "migration",
        "context_version": "simplified-v1"
    }
    
    with open(new_file, 'w') as f:
        json.dump(new_context, f, indent=2)
    
    print("✅ Migration completed successfully")
    
except Exception as e:
    print(f"⚠️  Migration failed: {e}")

EOF
    fi
}

# Help
show_help() {
    echo "Claude Simplified Memory - Enhanced Sessions for Claude Context"
    echo ""
    echo "Usage: claude-simplified-memory [command] [options]"
    echo ""
    echo "Commands:"
    echo "  save [reason] [summary] [issues] [actions]  Save current context"
    echo "  load                                        Load and display context"  
    echo "  auto-save                                   Auto-save if needed"
    echo "  should-save                                 Check if save is needed"
    echo "  migrate                                     Migrate from old format"
    echo ""
    echo "Examples:"
    echo "  claude-simplified-memory save manual 'Working on auth' 'JWT expired issue' 'Fix token refresh'"
    echo "  claude-simplified-memory auto-save"
    echo "  claude-simplified-memory load"
}

# Main logic
case "${1:-}" in
    "save")
        save_context "${2:-manual}" "$3" "$4" "$5"
        ;;
    "load")
        load_context
        ;;
    "auto-save")
        auto_save_context
        ;;
    "should-save")
        should_save_context
        ;;
    "migrate")
        migrate_from_old_format
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        # Default: try to load context
        load_context
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac