#!/bin/bash
# Claude Memory Simplified - Direct operations without coordinator overhead
# Maintains full functionality with minimal complexity for single-user workspace

WORKSPACE_DIR="$HOME/claude-workspace"
MEMORY_DIR="$WORKSPACE_DIR/.claude/memory"
CONTEXT_FILE="$MEMORY_DIR/simplified-context.json"
SESSION_HISTORY="$MEMORY_DIR/session-history.json"
INTELLIGENCE_CACHE="$MEMORY_DIR/intelligence-cache.json"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Setup
mkdir -p "$MEMORY_DIR"

# Safe JSON operations (direct implementation)
safe_json_read() {
    local file="$1"
    local default="$2"
    
    if [[ ! -f "$file" ]]; then
        echo "$default"
        return 0
    fi
    
    # Validate JSON before reading
    if ! python3 -m json.tool "$file" >/dev/null 2>&1; then
        echo "$default"
        return 1
    fi
    
    cat "$file"
}

safe_json_write() {
    local file="$1"
    local content="$2"
    local temp_file="${file}.tmp.$$"
    
    # Write to temp file first
    echo "$content" > "$temp_file"
    
    # Validate JSON
    if python3 -m json.tool "$temp_file" >/dev/null 2>&1; then
        mv "$temp_file" "$file"
        return 0
    else
        rm -f "$temp_file"
        return 1
    fi
}

# Device detection
get_device_info() {
    local hostname=$(hostname)
    local device_type="unknown"
    
    # Simple device detection based on hostname patterns
    case "$hostname" in
        *-DESKTOP-*|*-PC-*|NEURAL-X|DESKTOP-*)
            device_type="desktop"
            ;;
        *-LAPTOP-*|*-NOTEBOOK-*|*MacBook*|*ThinkPad*)
            device_type="laptop"
            ;;
        *)
            # Fallback: check for battery (simple heuristic)
            if [[ -d "/sys/class/power_supply/BAT0" || -d "/sys/class/power_supply/BAT1" ]]; then
                device_type="laptop"
            else
                device_type="desktop"
            fi
            ;;
    esac
    
    echo "$device_type"
}

# Git status extraction
get_git_status() {
    local workspace_dir="${1:-$WORKSPACE_DIR}"
    
    cd "$workspace_dir" || return 1
    
    # Use Python to handle the git commands and JSON generation
    python3 << 'EOF'
import subprocess
import json
import os

try:
    # Get current branch
    result = subprocess.run(['git', 'branch', '--show-current'], 
                          capture_output=True, text=True)
    branch = result.stdout.strip() if result.returncode == 0 else "unknown"
    
    # Get status
    result = subprocess.run(['git', 'status', '--porcelain'], 
                          capture_output=True, text=True)
    
    dirty_files = []
    if result.returncode == 0 and result.stdout:
        dirty_files = [line.strip() for line in result.stdout.strip().split('\n') if line.strip()]
    
    # Get last commit
    result = subprocess.run(['git', 'log', '-1', '--oneline'], 
                          capture_output=True, text=True)
    last_commit = result.stdout.strip() if result.returncode == 0 else "No commits"
    
    # Check if it's a git repo
    result = subprocess.run(['git', 'rev-parse', '--git-dir'], 
                          capture_output=True, text=True)
    is_git_repo = result.returncode == 0
    
    # Create JSON output
    git_status = {
        'branch': branch,
        'has_changes': len(dirty_files) > 0,
        'dirty_files_count': len(dirty_files),
        'dirty_files': dirty_files[:10],  # Limit to first 10
        'last_commit': last_commit,
        'is_git_repo': is_git_repo
    }
    
    print(json.dumps(git_status))
    
except Exception as e:
    # Fallback for non-git directories
    fallback = {
        'branch': 'unknown',
        'has_changes': False,
        'dirty_files_count': 0,
        'dirty_files': [],
        'last_commit': 'Unknown',
        'is_git_repo': False
    }
    print(json.dumps(fallback))
EOF
}

# Project detection
get_current_project() {
    local cwd=$(pwd)
    local workspace_dir="$WORKSPACE_DIR"
    
    # Try advanced detector first
    if [[ -x "$workspace_dir/scripts/claude-auto-project-detector.sh" ]]; then
        local project_json=$("$workspace_dir/scripts/claude-auto-project-detector.sh" detect 2>/dev/null)
        if [[ -n "$project_json" && "$project_json" != "null" ]]; then
            echo "$project_json"
            return 0
        fi
    fi
    
    # Path-based detection
    if [[ "$cwd" == "$workspace_dir"* ]]; then
        local relative_path=$(realpath --relative-to="$workspace_dir" "$cwd")
        local path_parts=(${relative_path//\// })
        
        if [[ ${#path_parts[@]} -ge 3 && "${path_parts[0]}" == "projects" ]]; then
            python3 -c "
import json
print(json.dumps({
    'name': '${path_parts[2]}',
    'type': '${path_parts[1]}',
    'path': '$relative_path',
    'detection_method': 'path_based'
}))
"
            return 0
        fi
    fi
    
    # Meta detection (workspace development)
    if [[ "$cwd" == "$workspace_dir" || "$cwd" == "$workspace_dir"* ]]; then
        if [[ "$cwd" == *"/scripts"* || "$cwd" == *"/docs"* || "$cwd" == "$workspace_dir" ]]; then
            python3 -c "
import json
print(json.dumps({
    'name': 'claude-workspace',
    'type': 'meta',
    'path': '.',
    'meta_context': 'workspace_development',
    'detection_method': 'meta_detection'
}))
"
            return 0
        fi
    fi
    
    echo "null"
}

# Intelligence insights extraction
extract_intelligence_insights() {
    local intelligence_dir="$WORKSPACE_DIR/.claude/intelligence"
    
    # Use Python to handle everything to avoid shell escaping issues
    python3 << EOF
import json
import os
from datetime import datetime, timezone

intelligence_dir = "$intelligence_dir"

# Initialize empty insights
insights = {
    "recent_learnings": [],
    "recent_decisions": [],
    "current_focus": None,
    "extraction_timestamp": datetime.now(timezone.utc).isoformat()
}

# Load auto-learnings if available
learnings_file = os.path.join(intelligence_dir, "auto-learnings.json")
if os.path.exists(learnings_file):
    try:
        with open(learnings_file, 'r') as f:
            learnings_data = json.load(f)
        
        auto_learnings = learnings_data.get('auto_learnings', [])
        
        # Get last 5 learnings
        recent_learnings = auto_learnings[-5:] if auto_learnings else []
        insights["recent_learnings"] = [
            {
                "title": learning.get("title", ""),
                "lesson": learning.get("lesson", ""),
                "category": learning.get("category", ""),
                "severity": learning.get("severity", ""),
                "timestamp": learning.get("timestamp", "")
            }
            for learning in recent_learnings
        ]
    except:
        pass

# Load auto-decisions if available
decisions_file = os.path.join(intelligence_dir, "auto-decisions.json")
if os.path.exists(decisions_file):
    try:
        with open(decisions_file, 'r') as f:
            decisions_data = json.load(f)
        
        auto_decisions = decisions_data.get('auto_decisions', [])
        
        # Get last 8 decisions
        recent_decisions = auto_decisions[-8:] if auto_decisions else []
        insights["recent_decisions"] = [
            {
                "title": decision.get("title", ""),
                "category": decision.get("category", ""),
                "impact": decision.get("impact", ""),
                "source": decision.get("source", ""),
                "timestamp": decision.get("timestamp", "")
            }
            for decision in recent_decisions
        ]
        
        # Determine current focus
        if recent_decisions:
            categories = [d.get("category") for d in recent_decisions]
            category_counts = {}
            for cat in categories:
                if cat:
                    category_counts[cat] = category_counts.get(cat, 0) + 1
            
            if category_counts:
                most_common = max(category_counts, key=category_counts.get)
                insights["current_focus"] = f"{most_common}_focused_development"
    except:
        pass

print(json.dumps(insights))
EOF
}

# Generate next actions based on context
generate_next_actions() {
    local git_status_json="$1"
    local project_json="$2"
    
    # Save to temp files to avoid shell escaping issues
    local temp_git="/tmp/temp_git_$$.json"
    local temp_project="/tmp/temp_project_$$.json"
    
    echo "$git_status_json" > "$temp_git"
    echo "$project_json" > "$temp_project"
    
    python3 << EOF
import json
import subprocess
import os

actions = []

# Load inputs from temp files
try:
    with open('$temp_git', 'r') as f:
        git_status = json.load(f)
except:
    git_status = {}

try:
    with open('$temp_project', 'r') as f:
        project_content = f.read().strip()
        project = json.loads(project_content) if project_content != 'null' else None
except:
    project = None

# Git-based actions
if git_status.get('has_changes', False):
    file_count = git_status.get('dirty_files_count', 0)
    actions.append(f'Commit current changes ({file_count} files modified)')

# Check recent commits for patterns
try:
    os.chdir('$WORKSPACE_DIR')
    result = subprocess.run(['git', 'log', '--oneline', '-5'], 
                          capture_output=True, text=True)
    if result.returncode == 0:
        commits = result.stdout.strip().split('\n')
        
        has_fixes = any('fix' in commit.lower() or 'bug' in commit.lower() for commit in commits)
        has_features = any('feat' in commit.lower() or 'add' in commit.lower() for commit in commits)
        has_wip = any('wip' in commit.lower() or 'progress' in commit.lower() for commit in commits)
        
        if has_fixes:
            actions.append('Verify recent fixes are working correctly')
        if has_features:
            actions.append('Test new features and update documentation')
        if has_wip:
            wip_commit = next((c for c in commits if 'wip' in c.lower()), '')
            if wip_commit:
                actions.append(f'Continue work on: {wip_commit.split(" ", 1)[1][:50]}')
except:
    pass

# Project-specific actions
if project:
    project_type = project.get('type')
    if project_type == 'meta':
        actions.append('Test workspace script changes')
        actions.append('Update documentation if needed')
    elif project_type == 'web':
        actions.append('Run development server and test changes')
    elif project_type == 'python':
        actions.append('Run unit tests and check code quality')

# Limit to 5 actions
actions = actions[:5]

print(json.dumps(actions))
EOF
    
    rm -f "$temp_git" "$temp_project"
}

# Extract TODO comments from current project
extract_todo_comments() {
    local project_json="$1"
    
    # Save to temp file to avoid shell escaping issues
    local temp_project="/tmp/temp_project_todos_$$.json"
    echo "$project_json" > "$temp_project"
    
    python3 << EOF
import json
import os
import re

todos = []

try:
    with open('$temp_project', 'r') as f:
        project_content = f.read().strip()
        project = json.loads(project_content) if project_content != 'null' else None
    
    if not project:
        print(json.dumps(todos))
        exit()
    
    workspace_dir = '$WORKSPACE_DIR'
    todo_patterns = ['TODO', 'FIXME', 'BUG', 'HACK', 'NOTE', 'IMPORTANT']
    
    # Determine search paths
    if project.get('type') == 'meta':
        search_paths = [
            os.path.join(workspace_dir, 'scripts'),
            os.path.join(workspace_dir, 'docs')
        ]
    else:
        project_path = project.get('path', '')
        if project_path:
            full_path = os.path.join(workspace_dir, project_path)
            if os.path.exists(full_path):
                search_paths = [full_path]
            else:
                search_paths = []
        else:
            search_paths = []
    
    for search_path in search_paths:
        if not os.path.exists(search_path):
            continue
        
        for root, dirs, files in os.walk(search_path):
            # Skip hidden directories
            dirs[:] = [d for d in dirs if not d.startswith('.')]
            
            for file in files:
                if file.endswith(('.sh', '.py', '.js', '.md', '.txt')):
                    file_path = os.path.join(root, file)
                    try:
                        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                            lines = f.readlines()
                        
                        for i, line in enumerate(lines):
                            line = line.strip()
                            for pattern in todo_patterns:
                                if pattern.lower() in line.lower():
                                    todo_text = line.replace('#', '').replace('//', '').strip()
                                    if len(todo_text) > 80:
                                        todo_text = todo_text[:80] + '...'
                                    
                                    relative_path = os.path.relpath(file_path, workspace_dir)
                                    
                                    todos.append({
                                        'text': todo_text,
                                        'file': relative_path,
                                        'line': i + 1,
                                        'type': pattern.lower()
                                    })
                                    break
                    except:
                        continue
    
    # Limit to 5 TODOs
    todos = todos[:5]
    
except Exception as e:
    pass

print(json.dumps(todos))
EOF
    
    rm -f "$temp_project"
}

# Main save function
save_context() {
    local save_reason="${1:-manual}"
    local conversation_summary="${2:-}"
    local open_issues="${3:-}"
    local next_actions="${4:-}"
    
    echo -e "${YELLOW}💾 Saving simplified context...${NC}"
    
    # Collect all context data
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local device_type=$(get_device_info)
    local device_name=$(hostname)
    local working_dir=$(pwd)
    local git_status_json=$(get_git_status)
    local project_json=$(get_current_project)
    local intelligence_json=$(extract_intelligence_insights)
    
    # Generate intelligent next actions if not provided
    if [[ -z "$next_actions" ]]; then
        local auto_actions_json=$(generate_next_actions "$git_status_json" "$project_json")
        next_actions=$(echo "$auto_actions_json" | python3 -c "
import json
import sys
try:
    actions = json.load(sys.stdin)
    print('|||'.join(actions))
except:
    print('')
")
    fi
    
    # Extract TODO comments
    local todos_json=$(extract_todo_comments "$project_json")
    
    # Auto-generate summary if not provided
    if [[ -z "$conversation_summary" ]]; then
        conversation_summary=$(python3 -c "
import json
try:
    git_status = json.loads('$git_status_json')
    project = json.loads('$project_json') if '$project_json' != 'null' else None
    
    summary_parts = []
    
    if project:
        proj_name = project.get('name', 'Unknown')
        proj_type = project.get('type', 'unknown')
        summary_parts.append(f'Working on {proj_name} ({proj_type})')
    
    if git_status.get('has_changes', False):
        file_count = git_status.get('dirty_files_count', 0)
        summary_parts.append(f'{file_count} files modified')
    
    if not summary_parts:
        summary_parts.append('Session context saved')
    
    print(' - '.join(summary_parts))
except:
    print('Session context saved')
")
    fi
    
    # Create unified context using temp files to avoid all escaping issues
    local temp_git="/tmp/save_git_$$.json"
    local temp_project="/tmp/save_project_$$.json" 
    local temp_intelligence="/tmp/save_intelligence_$$.json"
    local temp_todos="/tmp/save_todos_$$.json"
    
    echo "$git_status_json" > "$temp_git"
    echo "$project_json" > "$temp_project"
    echo "$intelligence_json" > "$temp_intelligence"
    echo "$todos_json" > "$temp_todos"
    
    local context_json=$(python3 << EOF
import json
from datetime import datetime

# Load all data from temp files
try:
    with open('$temp_git', 'r') as f:
        git_status = json.load(f)
except:
    git_status = {}

try:
    with open('$temp_project', 'r') as f:
        project_content = f.read().strip()
        project = json.loads(project_content) if project_content != 'null' else None
except:
    project = None

try:
    with open('$temp_intelligence', 'r') as f:
        intelligence = json.load(f)
except:
    intelligence = {}

try:
    with open('$temp_todos', 'r') as f:
        todos = json.load(f)
except:
    todos = []

# Parse string inputs
next_actions_str = '''$next_actions'''
open_issues_str = '''$open_issues'''

next_actions_list = next_actions_str.split('|||') if next_actions_str else []
open_issues_list = open_issues_str.split('|||') if open_issues_str else []

# Add TODO comments to open issues
todo_issues = [
    f"{todo['type'].upper()}: {todo['text']} ({todo['file']}:{todo['line']})"
    for todo in todos
]
all_open_issues = open_issues_list + todo_issues

context = {
    'context_version': 'simplified-v1',
    'timestamp': '$timestamp',
    'save_reason': '$save_reason',
    'device': {
        'name': '$device_name',
        'type': '$device_type'
    },
    'working_directory': '$working_dir',
    'current_project': project,
    'git_status': git_status,
    'intelligence_insights': intelligence,
    'conversation_summary': '''$conversation_summary''',
    'open_issues': all_open_issues,
    'next_actions': next_actions_list
}

print(json.dumps(context, indent=2))
EOF
)
    
    rm -f "$temp_git" "$temp_project" "$temp_intelligence" "$temp_todos"
    
    # Save context to file
    if safe_json_write "$CONTEXT_FILE" "$context_json"; then
        # Update session history
        update_session_history "$timestamp" "$save_reason" "$conversation_summary"
        
        # Cache intelligence insights
        echo "$intelligence_json" | safe_json_write "$INTELLIGENCE_CACHE" "$(cat)"
        
        echo -e "${GREEN}✅ Context saved successfully${NC}"
        
        # Show summary
        echo "$context_json" | python3 -c "
import json
import sys

try:
    context = json.load(sys.stdin)
    print(f'📁 Project: {context[\"current_project\"][\"name\"] if context.get(\"current_project\") else \"None\"}')
    print(f'🌿 Branch: {context[\"git_status\"][\"branch\"]}')
    print(f'📝 Changes: {context[\"git_status\"][\"dirty_files_count\"]} files')
    print(f'💡 Reason: {context[\"save_reason\"]}')
    if context.get('conversation_summary'):
        print(f'💬 Summary: {context[\"conversation_summary\"]}')
except:
    pass
"
        return 0
    else
        echo -e "${RED}❌ Failed to save context${NC}"
        return 1
    fi
}

# Update session history
update_session_history() {
    local timestamp="$1"
    local save_reason="$2"
    local summary="$3"
    
    # Load existing history or create new
    local history_data=$(safe_json_read "$SESSION_HISTORY" '{
        "sessions": [],
        "version": "simplified-v1"
    }')
    
    # Use temp file approach for session history too
    local temp_history="/tmp/temp_history_$$.json"
    echo "$history_data" > "$temp_history"
    
    local new_history=$(python3 << EOF
import json

# Load existing history
try:
    with open('$temp_history', 'r') as f:
        history = json.load(f)
except:
    history = {"sessions": [], "version": "simplified-v1"}

sessions = history.get('sessions', [])

# Add new session
new_session = {
    'id': '$timestamp-$save_reason',
    'timestamp': '$timestamp',
    'save_reason': '$save_reason',
    'summary': '''$summary''',
    'device': '$(hostname)'
}

sessions.insert(0, new_session)

# Keep only last 50 sessions
sessions = sessions[:50]

history['sessions'] = sessions
history['last_update'] = '$timestamp'

print(json.dumps(history, indent=2))
EOF
)
    
    rm -f "$temp_history"
    
    # Save updated history
    safe_json_write "$SESSION_HISTORY" "$new_history"
}

# Main load function
load_context() {
    echo -e "${CYAN}🧠 Loading simplified context...${NC}"
    
    if [[ ! -f "$CONTEXT_FILE" ]]; then
        echo -e "${YELLOW}⚠️  No context file found${NC}"
        return 1
    fi
    
    local context_data=$(safe_json_read "$CONTEXT_FILE" '{}')
    
    if [[ "$context_data" == '{}' ]]; then
        echo -e "${RED}❌ Failed to load context${NC}"
        return 1
    fi
    
    # Display context information
    echo "$context_data" | python3 -c "
import json
import sys
from datetime import datetime

try:
    context = json.load(sys.stdin)
    
    print(f'📅 Last session: {context.get(\"timestamp\", \"Unknown\")[:19].replace(\"T\", \" \")}')
    
    device = context.get('device', {})
    if device:
        print(f'💻 Device: {device.get(\"name\", \"Unknown\")} ({device.get(\"type\", \"unknown\")})')
    
    print(f'🎯 Save reason: {context.get(\"save_reason\", \"unknown\")}')
    
    project = context.get('current_project')
    if project:
        print(f'📁 Project: {project.get(\"name\", \"Unknown\")} ({project.get(\"type\", \"unknown\")})')
    
    git_status = context.get('git_status', {})
    if git_status:
        print(f'🌿 Branch: {git_status.get(\"branch\", \"unknown\")}')
        
        if git_status.get('has_changes', False):
            print(f'📝 Uncommitted changes: {git_status.get(\"dirty_files_count\", 0)} files')
        else:
            print('✅ Working directory clean')
    
    if context.get('conversation_summary'):
        print(f'💬 Summary: {context[\"conversation_summary\"]}')
    
    # Intelligence insights
    intelligence = context.get('intelligence_insights', {})
    if intelligence.get('current_focus'):
        focus = intelligence['current_focus'].replace('_', ' ').title()
        print(f'🧠 Current focus: {focus}')
    
    # Open issues
    open_issues = context.get('open_issues', [])
    if open_issues:
        print('🚨 Open issues:')
        for issue in open_issues[:5]:
            print(f'   • {issue}')
    
    # Next actions
    next_actions = context.get('next_actions', [])
    if next_actions:
        print('🎯 Next actions:')
        for action in next_actions[:5]:
            print(f'   • {action}')
    
    # Recent learnings
    recent_learnings = intelligence.get('recent_learnings', [])
    if recent_learnings:
        print('💡 Recent learnings:')
        for learning in recent_learnings[:3]:
            title = learning.get('title', '')
            category = learning.get('category', '')
            if title:
                print(f'   • [{category}] {title}')
    
except Exception as e:
    print(f'❌ Error parsing context: {e}')
    sys.exit(1)
"
    
    return 0
}

# Show status and statistics
show_status() {
    echo -e "${CYAN}📊 Memory System Status${NC}"
    echo ""
    
    # Context file status
    if [[ -f "$CONTEXT_FILE" ]]; then
        local file_size=$(stat -c%s "$CONTEXT_FILE" 2>/dev/null || echo "0")
        local file_time=$(stat -c%Y "$CONTEXT_FILE" 2>/dev/null || echo "0")
        local file_date=$(date -d "@$file_time" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "Unknown")
        
        echo -e "${GREEN}✅ Context file: ${file_size} bytes${NC}"
        echo "   Last updated: $file_date"
    else
        echo -e "${YELLOW}⚠️  No context file found${NC}"
    fi
    
    # Session history status
    if [[ -f "$SESSION_HISTORY" ]]; then
        local session_count=$(safe_json_read "$SESSION_HISTORY" '{}' | python3 -c "
import json
import sys
try:
    data = json.load(sys.stdin)
    sessions = data.get('sessions', [])
    print(len(sessions))
except:
    print('0')
" 2>/dev/null || echo "0")
        
        echo -e "${GREEN}✅ Session history: ${session_count} sessions${NC}"
    else
        echo -e "${YELLOW}⚠️  No session history${NC}"
    fi
    
    # Device info
    echo ""
    echo -e "${BLUE}💻 Device Information:${NC}"
    echo "   Name: $(hostname)"
    echo "   Type: $(get_device_info)"
    echo "   Working directory: $(pwd)"
    
    # Git status
    echo ""
    echo -e "${BLUE}🌿 Git Status:${NC}"
    local git_json=$(get_git_status)
    echo "$git_json" | python3 -c "
import json
import sys
try:
    git_status = json.load(sys.stdin)
    print(f'   Branch: {git_status.get(\"branch\", \"unknown\")}')
    print(f'   Has changes: {\"Yes\" if git_status.get(\"has_changes\", False) else \"No\"}')
    if git_status.get('has_changes', False):
        print(f'   Modified files: {git_status.get(\"dirty_files_count\", 0)}')
    print(f'   Last commit: {git_status.get(\"last_commit\", \"None\")}')
except:
    print('   Status: Unable to read git information')
"
    
    # Project status
    echo ""
    echo -e "${BLUE}📁 Project Status:${NC}"
    local project_json=$(get_current_project)
    if [[ "$project_json" != "null" ]]; then
        echo "$project_json" | python3 -c "
import json
import sys
try:
    project = json.load(sys.stdin)
    print(f'   Name: {project.get(\"name\", \"Unknown\")}')
    print(f'   Type: {project.get(\"type\", \"unknown\")}')
    print(f'   Path: {project.get(\"path\", \"unknown\")}')
    print(f'   Detection: {project.get(\"detection_method\", \"unknown\")}')
except:
    print('   Status: Unable to parse project information')
"
    else
        echo "   Status: No active project detected"
    fi
}

# Help function
show_help() {
    echo "Claude Memory Simplified - Direct operations without coordinator overhead"
    echo ""
    echo "Usage: $0 [command] [options]"
    echo ""
    echo "Main Commands:"
    echo "  save [reason] [summary] [issues] [actions]  Save context with optional parameters"
    echo "  load                                        Load and display context"
    echo "  status                                      Show system status and statistics"
    echo ""
    echo "Parameters:"
    echo "  reason    - Save reason (manual, auto, exit, etc.)"
    echo "  summary   - Brief conversation summary"
    echo "  issues    - Open issues (separated by |||)"
    echo "  actions   - Next actions (separated by |||)"
    echo ""
    echo "Examples:"
    echo "  $0 save manual 'Bug fixing session' 'Memory leak in parser' 'Test fix|||Deploy'"
    echo "  $0 save auto 'Auto-save during development'"
    echo "  $0 load"
    echo "  $0 status"
    echo ""
    echo "Features:"
    echo "  • Direct JSON operations (no coordinator overhead)"
    echo "  • Intelligence integration (auto-learnings, decisions)"
    echo "  • Smart session management with device awareness"
    echo "  • Project detection and context extraction"
    echo "  • TODO comment scanning"
    echo "  • Git status integration"
    echo "  • Auto-generation of summaries and actions"
}

# Main command handling
case "${1:-status}" in
    "save")
        save_context "${2:-manual}" "${3:-}" "${4:-}" "${5:-}"
        ;;
    "load")
        load_context
        ;;
    "status")
        show_status
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac