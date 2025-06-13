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

def extract_todo_comments():
    """Extract TODO/FIXME/BUG comments from project files"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR')
        if not workspace_dir:
            return []
            
        current_project = get_current_project()
        if not current_project:
            return []
            
        # Determine search path based on project type
        if current_project.get("type") == "meta":
            # For workspace development, search in scripts and docs
            search_paths = [
                os.path.join(workspace_dir, "scripts"),
                os.path.join(workspace_dir, "docs"),
                os.path.join(workspace_dir, "CLAUDE.md"),
                os.path.join(workspace_dir, "README.md")
            ]
        else:
            # For regular projects, search in project directory
            project_path = current_project.get("path", "")
            if project_path and os.path.exists(project_path):
                search_paths = [project_path]
            else:
                return []
        
        todos = []
        todo_patterns = ["TODO", "FIXME", "BUG", "HACK", "NOTE", "IMPORTANT"]
        
        for search_path in search_paths:
            if not os.path.exists(search_path):
                continue
                
            if os.path.isfile(search_path):
                # Single file
                todos.extend(_extract_from_file(search_path, todo_patterns))
            else:
                # Directory - search recursively
                for root, dirs, files in os.walk(search_path):
                    # Skip hidden directories and .claude
                    dirs[:] = [d for d in dirs if not d.startswith('.')]
                    
                    for file in files:
                        if file.endswith(('.sh', '.py', '.js', '.md', '.txt', '.json')):
                            file_path = os.path.join(root, file)
                            todos.extend(_extract_from_file(file_path, todo_patterns))
        
        # Limit to most recent/relevant 5 TODOs
        return todos[:5]
        
    except Exception as e:
        return []

def _extract_from_file(file_path, patterns):
    """Extract TODO comments from a single file"""
    todos = []
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()
            
        for i, line in enumerate(lines):
            line = line.strip()
            for pattern in patterns:
                if pattern.lower() in line.lower():
                    # Extract the TODO text
                    todo_text = line
                    # Remove comment markers
                    todo_text = todo_text.replace('#', '').replace('//', '').replace('/*', '').replace('*/', '').strip()
                    
                    # Clean up the text
                    if len(todo_text) > 100:
                        todo_text = todo_text[:100] + "..."
                    
                    relative_path = os.path.relpath(file_path, os.environ.get('WORKSPACE_DIR', '/'))
                    
                    todos.append({
                        "text": todo_text,
                        "file": relative_path,
                        "line": i + 1,
                        "type": pattern.lower()
                    })
                    break  # Only one TODO per line
    except:
        pass
    
    return todos

def generate_next_actions():
    """Generate smart next actions from git commits and project state"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR')
        if not workspace_dir:
            return []
            
        next_actions = []
        
        # Analyze recent commits for patterns
        try:
            result = subprocess.run(['git', 'log', '--oneline', '-5'], 
                                  capture_output=True, text=True, cwd=workspace_dir)
            if result.returncode == 0:
                commits = result.stdout.strip().split('\n')
                
                # Analyze commit patterns
                has_fixes = any('fix' in commit.lower() or 'bug' in commit.lower() for commit in commits)
                has_features = any('feat' in commit.lower() or 'add' in commit.lower() for commit in commits)
                has_docs = any('doc' in commit.lower() or 'readme' in commit.lower() for commit in commits)
                has_tests = any('test' in commit.lower() for commit in commits)
                
                # Generate contextual next actions
                if has_fixes:
                    next_actions.append("Verify fixes are working correctly")
                    next_actions.append("Add tests for recently fixed issues")
                
                if has_features:
                    next_actions.append("Test new features thoroughly")
                    next_actions.append("Update documentation for new features")
                
                # Look for incomplete work indicators in recent commits
                for commit in commits:
                    if 'wip' in commit.lower() or 'progress' in commit.lower():
                        next_actions.append("Continue work on: " + commit.split(' ', 1)[1][:50])
                    elif 'partial' in commit.lower():
                        next_actions.append("Complete partial implementation")
        except:
            pass
        
        # Check git status for pending work
        try:
            result = subprocess.run(['git', 'status', '--porcelain'], 
                                  capture_output=True, text=True, cwd=workspace_dir)
            if result.returncode == 0 and result.stdout.strip():
                modified_files = result.stdout.strip().split('\n')
                
                # Analyze modified files
                script_changes = any('.sh' in line for line in modified_files)
                doc_changes = any('.md' in line for line in modified_files)
                config_changes = any('CLAUDE.md' in line or '.json' in line for line in modified_files)
                
                if script_changes:
                    next_actions.append("Test modified scripts for functionality")
                
                if doc_changes:
                    next_actions.append("Review documentation changes")
                
                if config_changes:
                    next_actions.append("Validate configuration changes")
                
                # General action for uncommitted changes
                if len(modified_files) > 0:
                    next_actions.append(f"Commit current changes ({len(modified_files)} files modified)")
        except:
            pass
        
        # Project-specific next actions
        current_project = get_current_project()
        if current_project:
            project_type = current_project.get("type")
            
            if project_type == "meta":
                meta_context = current_project.get("meta_context", "")
                if "script_development" in meta_context:
                    next_actions.append("Test script changes thoroughly")
                elif "documentation" in meta_context:
                    next_actions.append("Review and proofread documentation")
                elif "system_configuration" in meta_context:
                    next_actions.append("Verify system configuration changes")
        
        # Remove duplicates and limit to 5 most relevant
        unique_actions = list(dict.fromkeys(next_actions))
        return unique_actions[:5]
        
    except Exception as e:
        return []

def get_intelligence_insights():
    """Extract intelligence insights for context enrichment"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR')
        if not workspace_dir:
            return None
            
        intelligence_dir = os.path.join(workspace_dir, '.claude', 'intelligence')
        
        insights = {
            "recent_learnings": [],
            "recent_decisions": [],
            "current_focus": None,
            "system_insights": {}
        }
        
        # Load auto-learnings
        learnings_file = os.path.join(intelligence_dir, 'auto-learnings.json')
        if os.path.exists(learnings_file):
            with open(learnings_file, 'r') as f:
                learnings_data = json.load(f)
                # Get most recent 3 learnings
                recent_learnings = learnings_data.get('auto_learnings', [])[-3:]
                insights["recent_learnings"] = [
                    {
                        "title": learning.get("title"),
                        "lesson": learning.get("lesson"),
                        "category": learning.get("category"),
                        "severity": learning.get("severity")
                    }
                    for learning in recent_learnings
                ]
        
        # Load auto-decisions
        decisions_file = os.path.join(intelligence_dir, 'auto-decisions.json')
        if os.path.exists(decisions_file):
            with open(decisions_file, 'r') as f:
                decisions_data = json.load(f)
                # Get most recent 5 decisions
                recent_decisions = decisions_data.get('auto_decisions', [])[-5:]
                insights["recent_decisions"] = [
                    {
                        "title": decision.get("title"),
                        "category": decision.get("category"),
                        "impact": decision.get("impact"),
                        "source": decision.get("source")
                    }
                    for decision in recent_decisions
                ]
        
        # Infer current focus from recent decisions
        if insights["recent_decisions"]:
            categories = [d.get("category") for d in insights["recent_decisions"]]
            category_counts = {}
            for cat in categories:
                category_counts[cat] = category_counts.get(cat, 0) + 1
            
            most_common = max(category_counts, key=category_counts.get)
            insights["current_focus"] = f"{most_common}_focused_development"
        
        # System insights summary
        if insights["recent_learnings"]:
            high_severity = [l for l in insights["recent_learnings"] if l.get("severity") == "high"]
            if high_severity:
                insights["system_insights"]["critical_issues"] = len(high_severity)
            
            stability_issues = [l for l in insights["recent_learnings"] 
                             if "stability" in l.get("category", "").lower()]
            if stability_issues:
                insights["system_insights"]["stability_focus"] = True
        
        return insights if any(insights.values()) else None
        
    except Exception as e:
        return None

def get_current_project():
    """Detect current project using advanced project detector"""
    try:
        import subprocess
        import json
        
        workspace_dir = os.environ.get('WORKSPACE_DIR')
        if not workspace_dir:
            return None
            
        # Use the advanced project detector (detect command outputs JSON)
        result = subprocess.run([
            os.path.join(workspace_dir, 'scripts', 'claude-auto-project-detector.sh'),
            'detect'
        ], capture_output=True, text=True, cwd=workspace_dir,
           env=dict(os.environ, WORKSPACE_DIR=workspace_dir))
        
        if result.returncode == 0:
            project_json = result.stdout.strip()
            if project_json and project_json != "null":
                project_data = json.loads(project_json)
                return {
                    "name": project_data.get("name"),
                    "type": project_data.get("type"),
                    "path": project_data.get("path"),
                    "depth": project_data.get("depth", 0),
                    "meta_context": project_data.get("meta_context"),
                    "full_path": project_data.get("full_path")
                }
        
        return None
    except Exception as e:
        # Fallback to simple detection
        try:
            cwd = os.getcwd()
            workspace_dir = os.environ.get('WORKSPACE_DIR')
            
            if workspace_dir and cwd.startswith(workspace_dir):
                relative_path = os.path.relpath(cwd, workspace_dir)
                path_parts = relative_path.split(os.sep)
                
                if len(path_parts) >= 3 and path_parts[0] == "projects" and path_parts[1] == "active":
                    return {"name": path_parts[2], "type": "active"}
                elif len(path_parts) >= 2 and path_parts[0] == "projects":
                    return {"name": path_parts[1], "type": "unknown"}
            
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

# Auto-populate open_issues from TODO comments if not provided
if not open_issues:
    todo_comments = extract_todo_comments()
    if todo_comments:
        open_issues = [
            f"{todo['type'].upper()}: {todo['text']} ({todo['file']}:{todo['line']})"
            for todo in todo_comments
        ]

# Auto-populate next_actions if not provided
if not next_actions:
    auto_next_actions = generate_next_actions()
    if auto_next_actions:
        next_actions = auto_next_actions

# Get intelligence insights
intelligence_insights = get_intelligence_insights()

# Auto-generate conversation summary from intelligence if not provided
if not conversation_summary and intelligence_insights:
    summary_parts = []
    if intelligence_insights.get("recent_decisions"):
        recent_count = len(intelligence_insights["recent_decisions"])
        summary_parts.append(f"Recent development: {recent_count} decisions tracked")
    
    if intelligence_insights.get("recent_learnings"):
        for learning in intelligence_insights["recent_learnings"]:
            if learning.get("severity") in ["high", "medium"]:
                summary_parts.append(f"Key insight: {learning.get('lesson')}")
    
    if intelligence_insights.get("current_focus"):
        focus = intelligence_insights["current_focus"].replace("_", " ")
        summary_parts.append(f"Current focus: {focus}")
    
    if summary_parts:
        conversation_summary = ". ".join(summary_parts[:3])  # Limit to 3 parts for brevity

# Create simplified context
context = {
    "session_id": datetime.now().isoformat() + "Z",
    "timestamp": datetime.now().isoformat() + "Z", 
    "device": os.uname().nodename,
    "working_directory": os.getcwd(),
    "current_project": get_current_project(),
    "git_status": get_git_status(),
    "intelligence_insights": intelligence_insights,
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