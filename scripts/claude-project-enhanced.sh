#!/bin/bash
# Claude Project Enhanced - Smart project management with intelligence integration
# Features: Smart detection, lifecycle tracking, cross-project intelligence, context switching

WORKSPACE_DIR="$HOME/claude-workspace"
PROJECTS_DIR="$WORKSPACE_DIR/projects"
ENHANCED_PROJECT_DIR="$WORKSPACE_DIR/.claude/projects"
PROJECT_CONTEXTS_DIR="$ENHANCED_PROJECT_DIR/contexts"
PROJECT_INTELLIGENCE_DIR="$ENHANCED_PROJECT_DIR/intelligence"
PROJECT_LIFECYCLE_FILE="$ENHANCED_PROJECT_DIR/lifecycle.json"
PROJECT_HISTORY_FILE="$ENHANCED_PROJECT_DIR/history.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Setup
mkdir -p "$ENHANCED_PROJECT_DIR" "$PROJECT_CONTEXTS_DIR" "$PROJECT_INTELLIGENCE_DIR"

# Logging function
log_project() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$ENHANCED_PROJECT_DIR/project-enhanced.log"
}

# Initialize project databases
initialize_project_databases() {
    if [[ ! -f "$PROJECT_LIFECYCLE_FILE" ]]; then
        cat > "$PROJECT_LIFECYCLE_FILE" << 'EOF'
{
  "version": "1.0",
  "projects": {},
  "transitions": [],
  "milestones": {}
}
EOF
    fi
    
    if [[ ! -f "$PROJECT_HISTORY_FILE" ]]; then
        cat > "$PROJECT_HISTORY_FILE" << 'EOF'
{
  "version": "1.0",
  "sessions": [],
  "time_tracking": {},
  "context_switches": []
}
EOF
    fi
}

# Smart project detection with enhanced analysis
detect_project_enhanced() {
    local silent="${1:-false}"
    
    if [[ "$silent" != "true" ]]; then
        echo -e "${CYAN}🔍 Enhanced project detection...${NC}"
    fi
    
    # Use existing detector as base
    local base_detection
    if [[ -x "$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" ]]; then
        base_detection=$("$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" detect)
    else
        base_detection="null"
    fi
    
    # Enhanced analysis with proper variable export
    export WORKSPACE_DIR
    export BASE_DETECTION="$base_detection"
    python3 << 'EOF'
import json
import os
import subprocess
from pathlib import Path
from datetime import datetime

def enhance_project_detection(base_detection_str):
    """Enhance basic project detection with intelligence"""
    
    workspace_dir_str = os.environ.get('WORKSPACE_DIR')
    if not workspace_dir_str:
        return None
    workspace_dir = Path(workspace_dir_str)
    
    if base_detection_str == "null":
        # Check for external projects
        cwd = Path.cwd()
        if not str(cwd).startswith(str(workspace_dir)):
            # We're outside workspace - check if it's a project
            if (cwd / '.git').exists() or (cwd / 'package.json').exists() or (cwd / 'requirements.txt').exists():
                return {
                    "name": cwd.name,
                    "type": "external",
                    "path": str(cwd),
                    "relative_path": f"external/{cwd.name}",
                    "depth": 0,
                    "full_path": str(cwd),
                    "enhanced": True,
                    "detection_confidence": "high",
                    "external_project": True
                }
        return None
    
    # Parse base detection
    try:
        base_data = json.loads(base_detection_str)
    except:
        return None
    
    # Enhance with additional intelligence
    enhanced_data = base_data.copy()
    enhanced_data["enhanced"] = True
    enhanced_data["detection_confidence"] = "high"
    
    # Analyze project characteristics
    project_path = Path(base_data["full_path"])
    characteristics = analyze_project_characteristics(project_path)
    enhanced_data["characteristics"] = characteristics
    
    # Add lifecycle information
    lifecycle_info = detect_lifecycle_stage(base_data, project_path)
    enhanced_data["lifecycle"] = lifecycle_info
    
    # Time tracking
    enhanced_data["session_start"] = datetime.now().isoformat() + 'Z'
    
    return enhanced_data

def analyze_project_characteristics(project_path):
    """Analyze project to determine technology stack and characteristics"""
    
    characteristics = {
        "tech_stack": [],
        "project_size": "unknown",
        "has_tests": False,
        "has_docs": False,
        "git_activity": "unknown"
    }
    
    # Technology stack detection
    if (project_path / 'package.json').exists():
        characteristics["tech_stack"].append("nodejs")
    if (project_path / 'requirements.txt').exists() or (project_path / 'setup.py').exists():
        characteristics["tech_stack"].append("python")
    if (project_path / 'Cargo.toml').exists():
        characteristics["tech_stack"].append("rust")
    if (project_path / 'go.mod').exists():
        characteristics["tech_stack"].append("go")
    if (project_path / 'Dockerfile').exists():
        characteristics["tech_stack"].append("docker")
    
    # Project size estimation
    try:
        file_count = sum(1 for _ in project_path.rglob('*') if _.is_file() and '/.git/' not in str(_))
        if file_count < 10:
            characteristics["project_size"] = "small"
        elif file_count < 100:
            characteristics["project_size"] = "medium"
        else:
            characteristics["project_size"] = "large"
    except:
        pass
    
    # Test detection
    test_dirs = ['test', 'tests', 'spec', '__tests__']
    characteristics["has_tests"] = any((project_path / test_dir).exists() for test_dir in test_dirs)
    
    # Documentation detection
    doc_files = ['README.md', 'README.rst', 'docs', 'documentation']
    characteristics["has_docs"] = any((project_path / doc_file).exists() for doc_file in doc_files)
    
    # Git activity (if .git exists)
    git_dir = project_path / '.git'
    if git_dir.exists():
        try:
            result = subprocess.run(['git', 'log', '--oneline', '-10'], 
                                  capture_output=True, text=True, cwd=project_path)
            if result.returncode == 0:
                commit_count = len(result.stdout.strip().split('\n')) if result.stdout.strip() else 0
                if commit_count > 50:
                    characteristics["git_activity"] = "high"
                elif commit_count > 10:
                    characteristics["git_activity"] = "medium"
                else:
                    characteristics["git_activity"] = "low"
        except:
            pass
    
    return characteristics

def detect_lifecycle_stage(base_data, project_path):
    """Detect project lifecycle stage"""
    
    project_type = base_data.get("type", "unknown")
    
    # Basic stage from project location
    if project_type == "sandbox":
        stage = "experimentation"
    elif project_type == "active":
        stage = "development"
    elif project_type == "production":
        stage = "production"
    elif project_type == "external":
        stage = "external"
    else:
        stage = "unknown"
    
    # Enhanced detection based on project characteristics
    if (project_path / '.git').exists():
        try:
            # Check for release tags
            result = subprocess.run(['git', 'tag', '-l'], capture_output=True, text=True, cwd=project_path)
            if result.returncode == 0 and result.stdout.strip():
                if stage == "development":
                    stage = "pre-release"
        except:
            pass
    
    return {
        "stage": stage,
        "confidence": "medium",
        "detected_at": datetime.now().isoformat() + 'Z'
    }

# Main detection logic
base_detection_str = os.environ.get('BASE_DETECTION', 'null')
enhanced_result = enhance_project_detection(base_detection_str)

if enhanced_result:
    print(json.dumps(enhanced_result))
else:
    print("null")
EOF
}

# Track project lifecycle and milestones
track_project_lifecycle() {
    local project_data_json="$1"
    
    if [[ "$project_data_json" == "null" ]]; then
        return 0
    fi
    
    echo -e "${PURPLE}📊 Tracking project lifecycle...${NC}"
    
    # Export variables for Python
    export PROJECT_LIFECYCLE_FILE
    export project_data_json
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

def update_project_lifecycle(project_data):
    """Update project lifecycle tracking"""
    
    lifecycle_file = os.environ.get('PROJECT_LIFECYCLE_FILE')
    
    # Load existing lifecycle data
    try:
        with open(lifecycle_file, 'r') as f:
            lifecycle_db = json.load(f)
    except:
        lifecycle_db = {
            "version": "1.0",
            "projects": {},
            "transitions": [],
            "milestones": {}
        }
    
    project_name = project_data.get('name', 'unknown')
    project_type = project_data.get('type', 'unknown')
    current_stage = project_data.get('lifecycle', {}).get('stage', 'unknown')
    
    # Update or create project entry
    if project_name not in lifecycle_db['projects']:
        lifecycle_db['projects'][project_name] = {
            'created_at': datetime.now().isoformat() + 'Z',
            'type': project_type,
            'current_stage': current_stage,
            'stage_history': [
                {
                    'stage': current_stage,
                    'entered_at': datetime.now().isoformat() + 'Z',
                    'source': 'auto_detection'
                }
            ],
            'characteristics': project_data.get('characteristics', {}),
            'time_spent': 0,
            'last_activity': datetime.now().isoformat() + 'Z'
        }
        print(f"✅ New project tracked: {project_name} ({current_stage})")
    else:
        # Update existing project
        existing_project = lifecycle_db['projects'][project_name]
        previous_stage = existing_project.get('current_stage', 'unknown')
        
        # Check for stage transition
        if previous_stage != current_stage:
            transition = {
                'project': project_name,
                'from_stage': previous_stage,
                'to_stage': current_stage,
                'timestamp': datetime.now().isoformat() + 'Z',
                'trigger': 'location_change'
            }
            lifecycle_db['transitions'].append(transition)
            
            # Update stage history
            existing_project['stage_history'].append({
                'stage': current_stage,
                'entered_at': datetime.now().isoformat() + 'Z',
                'source': 'auto_detection'
            })
            existing_project['current_stage'] = current_stage
            
            print(f"🔄 Stage transition: {project_name} {previous_stage} → {current_stage}")
        
        # Update activity timestamp
        existing_project['last_activity'] = datetime.now().isoformat() + 'Z'
        existing_project['characteristics'] = project_data.get('characteristics', {})
    
    # Detect milestones based on git activity
    if project_data.get('characteristics', {}).get('git_activity') in ['medium', 'high']:
        milestone_key = f"{project_name}_git_active"
        if milestone_key not in lifecycle_db['milestones']:
            lifecycle_db['milestones'][milestone_key] = {
                'project': project_name,
                'type': 'development_milestone',
                'title': 'Active development detected',
                'achieved_at': datetime.now().isoformat() + 'Z',
                'auto_detected': True
            }
            print(f"🎯 Milestone detected: Active development in {project_name}")
    
    # Save updated lifecycle data
    with open(lifecycle_file, 'w') as f:
        json.dump(lifecycle_db, f, indent=2)

# Main execution
project_data_str = os.environ.get('project_data_json')
if project_data_str and project_data_str != "null":
    try:
        project_data = json.loads(project_data_str)
        update_project_lifecycle(project_data)
    except Exception as e:
        print(f"Error updating lifecycle: {e}")
EOF
}

# Save project-specific context
save_project_context() {
    local project_name="$1"
    local context_type="${2:-switch}"
    
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}❌ No project name provided for context save${NC}"
        return 1
    fi
    
    echo -e "${YELLOW}💾 Saving context for project: $project_name${NC}"
    
    local context_file="$PROJECT_CONTEXTS_DIR/${project_name}.json"
    
    # Create project context
    python3 << EOF
import json
import os
import subprocess
from datetime import datetime
from pathlib import Path

def save_project_context(project_name, context_type):
    """Save current project context"""
    
    context_data = {
        'project_name': project_name,
        'saved_at': datetime.now().isoformat() + 'Z',
        'context_type': context_type,
        'working_directory': os.getcwd(),
        'git_status': {},
        'open_files': [],
        'session_summary': ''
    }
    
    # Capture git status if available
    try:
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            context_data['git_status'] = {
                'has_changes': bool(result.stdout.strip()),
                'changes': result.stdout.strip().split('\n') if result.stdout.strip() else []
            }
    except:
        pass
    
    # Save context file
    context_file = f"$PROJECT_CONTEXTS_DIR/{project_name}.json"
    with open(context_file, 'w') as f:
        json.dump(context_data, f, indent=2)
    
    return context_file

# Execute save
try:
    saved_file = save_project_context("$project_name", "$context_type")
    print(f"✅ Context saved: {saved_file}")
except Exception as e:
    print(f"❌ Failed to save context: {e}")
EOF
}

# Load project-specific context
load_project_context() {
    local project_name="$1"
    
    if [[ -z "$project_name" ]]; then
        echo -e "${RED}❌ No project name provided for context load${NC}"
        return 1
    fi
    
    local context_file="$PROJECT_CONTEXTS_DIR/${project_name}.json"
    
    if [[ ! -f "$context_file" ]]; then
        echo -e "${YELLOW}⚠️  No saved context found for project: $project_name${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🧠 Loading context for project: $project_name${NC}"
    
    python3 << EOF
import json
import os

context_file = "$context_file"
try:
    with open(context_file, 'r') as f:
        context = json.load(f)
    
    print(f"📅 Context saved: {context.get('saved_at', 'unknown')}")
    print(f"📁 Working directory: {context.get('working_directory', 'unknown')}")
    
    git_status = context.get('git_status', {})
    if git_status.get('has_changes', False):
        print(f"📝 Had uncommitted changes: {len(git_status.get('changes', []))} files")
    
    if context.get('session_summary'):
        print(f"💬 Last session: {context['session_summary']}")
        
except Exception as e:
    print(f"❌ Failed to load context: {e}")
EOF
}

# Extract cross-project intelligence patterns
extract_cross_project_intelligence() {
    echo -e "${PURPLE}🧠 Extracting cross-project intelligence...${NC}"
    
    # Feed patterns to intelligence system
    if [[ -x "$WORKSPACE_DIR/scripts/claude-intelligence-extractor.sh" ]]; then
        echo -e "${CYAN}📊 Feeding project patterns to intelligence system...${NC}"
        "$WORKSPACE_DIR/scripts/claude-intelligence-extractor.sh" extract "1 hour ago"
    fi
    
    # Generate project-specific intelligence
    python3 << 'EOF'
import json
import os
from pathlib import Path
from collections import defaultdict, Counter
from datetime import datetime

def analyze_cross_project_patterns():
    """Analyze patterns across projects"""
    
    patterns = {
        'tech_stacks': Counter(),
        'common_issues': defaultdict(list),
        'success_patterns': [],
        'project_transitions': []
    }
    
    # Load project lifecycle data
    lifecycle_file = os.environ.get('PROJECT_LIFECYCLE_FILE')
    if lifecycle_file and Path(lifecycle_file).exists():
        try:
            with open(lifecycle_file, 'r') as f:
                lifecycle_data = json.load(f)
            
            # Analyze tech stack patterns
            for project_name, project_data in lifecycle_data.get('projects', {}).items():
                tech_stack = project_data.get('characteristics', {}).get('tech_stack', [])
                for tech in tech_stack:
                    patterns['tech_stacks'][tech] += 1
            
            # Analyze project transitions
            transitions = lifecycle_data.get('transitions', [])
            for transition in transitions:
                if transition['from_stage'] == 'development' and transition['to_stage'] == 'production':
                    patterns['success_patterns'].append({
                        'project': transition['project'],
                        'completion_time': transition['timestamp'],
                        'pattern_type': 'successful_deployment'
                    })
            
            print("📊 Cross-project intelligence:")
            print(f"   Most used tech stacks: {dict(patterns['tech_stacks'].most_common(3))}")
            print(f"   Successful deployments: {len(patterns['success_patterns'])}")
            print(f"   Total transitions tracked: {len(transitions)}")
            
        except Exception as e:
            print(f"Error analyzing patterns: {e}")
    
    return patterns

# Execute analysis
patterns = analyze_cross_project_patterns()
EOF
}

# Smart project switching with context management
switch_project() {
    local target_project="$1"
    
    if [[ -z "$target_project" ]]; then
        echo -e "${RED}❌ No target project specified${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🔄 Smart project switching to: $target_project${NC}"
    
    # Detect current project
    local current_project_json
    current_project_json=$(detect_project_enhanced)
    
    # Save current context if in a project
    if [[ "$current_project_json" != "null" ]]; then
        local current_name
        current_name=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('name', ''))")
        
        if [[ -n "$current_name" && "$current_name" != "$target_project" ]]; then
            save_project_context "$current_name" "switch"
        fi
    fi
    
    # Find target project and switch
    local target_paths=(
        "$PROJECTS_DIR/active/$target_project"
        "$PROJECTS_DIR/sandbox/$target_project" 
        "$PROJECTS_DIR/production/$target_project"
    )
    
    local found_path=""
    for path in "${target_paths[@]}"; do
        if [[ -d "$path" ]]; then
            found_path="$path"
            break
        fi
    done
    
    if [[ -z "$found_path" ]]; then
        echo -e "${RED}❌ Project not found: $target_project${NC}"
        echo "Available projects:"
        ls -la "$PROJECTS_DIR"/*/
        return 1
    fi
    
    # Switch to project directory
    cd "$found_path" || {
        echo -e "${RED}❌ Failed to switch to: $found_path${NC}"
        return 1
    }
    
    echo -e "${GREEN}✅ Switched to project: $target_project${NC}"
    echo -e "${BLUE}📍 Location: $found_path${NC}"
    
    # Load project context
    load_project_context "$target_project"
    
    # Update project lifecycle
    local new_project_json
    new_project_json=$(detect_project_enhanced)
    track_project_lifecycle "$new_project_json"
    
    # Show project status
    show_project_status_enhanced
}

# Get project JSON without color output
get_project_json() {
    # Use existing detector as base
    local base_detection
    if [[ -x "$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" ]]; then
        base_detection=$("$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" detect)
    else
        base_detection="null"
    fi
    
    # Enhanced analysis with proper variable export
    export WORKSPACE_DIR
    export BASE_DETECTION="$base_detection"
    python3 << 'EOF'
import json
import os
import subprocess
from pathlib import Path
from datetime import datetime

def enhance_project_detection(base_detection_str):
    """Enhance basic project detection with intelligence"""
    
    workspace_dir_str = os.environ.get('WORKSPACE_DIR')
    if not workspace_dir_str:
        return None
    workspace_dir = Path(workspace_dir_str)
    
    if base_detection_str == "null":
        # Check for external projects
        cwd = Path.cwd()
        if not str(cwd).startswith(str(workspace_dir)):
            # We're outside workspace - check if it's a project
            if (cwd / '.git').exists() or (cwd / 'package.json').exists() or (cwd / 'requirements.txt').exists():
                return {
                    "name": cwd.name,
                    "type": "external",
                    "path": str(cwd),
                    "relative_path": f"external/{cwd.name}",
                    "depth": 0,
                    "full_path": str(cwd),
                    "enhanced": True,
                    "detection_confidence": "high",
                    "external_project": True
                }
        return None
    
    # Parse base detection
    try:
        base_data = json.loads(base_detection_str)
    except:
        return None
    
    # Enhance with additional intelligence
    enhanced_data = base_data.copy()
    enhanced_data["enhanced"] = True
    enhanced_data["detection_confidence"] = "high"
    
    # Analyze project characteristics
    project_path = Path(base_data["full_path"])
    characteristics = {
        "tech_stack": [],
        "project_size": "unknown",
        "has_tests": False,
        "has_docs": False,
        "git_activity": "unknown"
    }
    
    # Technology stack detection
    if (project_path / 'package.json').exists():
        characteristics["tech_stack"].append("nodejs")
    if (project_path / 'requirements.txt').exists() or (project_path / 'setup.py').exists():
        characteristics["tech_stack"].append("python")
    if (project_path / 'Cargo.toml').exists():
        characteristics["tech_stack"].append("rust")
    if (project_path / 'go.mod').exists():
        characteristics["tech_stack"].append("go")
    if (project_path / 'Dockerfile').exists():
        characteristics["tech_stack"].append("docker")
    
    # Project size estimation
    try:
        file_count = sum(1 for _ in project_path.rglob('*') if _.is_file() and '/.git/' not in str(_))
        if file_count < 10:
            characteristics["project_size"] = "small"
        elif file_count < 100:
            characteristics["project_size"] = "medium"
        else:
            characteristics["project_size"] = "large"
    except:
        pass
    
    # Test detection
    test_dirs = ['test', 'tests', 'spec', '__tests__']
    characteristics["has_tests"] = any((project_path / test_dir).exists() for test_dir in test_dirs)
    
    # Documentation detection
    doc_files = ['README.md', 'README.rst', 'docs', 'documentation']
    characteristics["has_docs"] = any((project_path / doc_file).exists() for doc_file in doc_files)
    
    enhanced_data["characteristics"] = characteristics
    
    # Add lifecycle information
    enhanced_data["lifecycle"] = {
        "stage": "unknown",
        "confidence": "medium",
        "detected_at": datetime.now().isoformat() + 'Z'
    }
    
    # Time tracking
    enhanced_data["session_start"] = datetime.now().isoformat() + 'Z'
    
    return enhanced_data

# Main detection logic
base_detection_str = os.environ.get('BASE_DETECTION', 'null')
enhanced_result = enhance_project_detection(base_detection_str)

if enhanced_result:
    print(json.dumps(enhanced_result))
else:
    print("null")
EOF
}

# Enhanced project status with intelligence
show_project_status_enhanced() {
    echo -e "${CYAN}📊 ENHANCED PROJECT STATUS${NC}"
    echo ""
    
    local current_project_json
    current_project_json=$(get_project_json)
    
    if [[ "$current_project_json" != "null" ]]; then
        export CURRENT_PROJECT_JSON="$current_project_json"
        python3 << 'EOF'
import json
import sys
import os

try:
    project_json = os.environ.get('CURRENT_PROJECT_JSON', 'null')
    data = json.loads(project_json)
except json.JSONDecodeError as e:
    print(f"❌ Error parsing project data: {e}")
    sys.exit(1)
except Exception as e:
    print(f"❌ Error: {e}")
    sys.exit(1)
print("✅ Current Project:")
print(f"   📁 Name: {data['name']}")
print(f"   📂 Type: {data['type']}")
print(f"   📍 Path: {data.get('relative_path', 'unknown')}")
print(f"   🔍 Detection: {data.get('detection_confidence', 'unknown')} confidence")

# Show lifecycle info
lifecycle = data.get('lifecycle', {})
if lifecycle:
    print(f"   🌱 Stage: {lifecycle.get('stage', 'unknown')}")

# Show characteristics
characteristics = data.get('characteristics', {})
if characteristics:
    print("   🔧 Characteristics:")
    tech_stack = characteristics.get('tech_stack', [])
    if tech_stack:
        print(f"      • Tech stack: {', '.join(tech_stack)}")
    print(f"      • Size: {characteristics.get('project_size', 'unknown')}")
    print(f"      • Has tests: {'Yes' if characteristics.get('has_tests') else 'No'}")
    print(f"      • Has docs: {'Yes' if characteristics.get('has_docs') else 'No'}")
    print(f"      • Git activity: {characteristics.get('git_activity', 'unknown')}")

if data.get('external_project'):
    print("   🌐 External project detected")
EOF
    else
        echo "❌ No project detected"
        echo "   💡 Navigate to a project directory or use switch command"
    fi
    
    # Show recent project activity
    echo ""
    echo -e "${BLUE}📈 Recent Project Activity:${NC}"
    
    if [[ -f "$PROJECT_LIFECYCLE_FILE" ]]; then
        export PROJECT_LIFECYCLE_FILE
        python3 << 'EOF'
import json
import os
from datetime import datetime

lifecycle_file = os.environ.get('PROJECT_LIFECYCLE_FILE')
if not lifecycle_file:
    print("   Error: PROJECT_LIFECYCLE_FILE not set")
elif not os.path.exists(lifecycle_file):
    print("   No lifecycle file found")
else:
    try:
        with open(lifecycle_file, 'r') as f:
            content = f.read().strip()
            if not content:
                print("   Lifecycle file is empty")
            else:
                lifecycle_data = json.loads(content)
        
                # Show recent transitions
                transitions = lifecycle_data.get('transitions', [])
                if transitions:
                    recent_transitions = sorted(transitions, key=lambda x: x['timestamp'], reverse=True)[:3]
                    print("   🔄 Recent transitions:")
                    for transition in recent_transitions:
                        print(f"      • {transition['project']}: {transition['from_stage']} → {transition['to_stage']}")
                else:
                    print("   📊 No project transitions yet")
                
                # Show active projects
                projects = lifecycle_data.get('projects', {})
                if projects:
                    print("   🚀 Tracked projects:")
                    for name, data in projects.items():
                        print(f"      • {name} ({data.get('current_stage', 'unknown')})")
                else:
                    print("   📁 No projects tracked yet")
        
    except json.JSONDecodeError as e:
        print(f"   Error parsing JSON: {e}")
    except Exception as e:
        print(f"   Error loading activity: {e}")
EOF
    else
        echo "   No activity data available"
    fi
}

# Show project lifecycle summary
show_lifecycle_summary() {
    echo -e "${PURPLE}🌱 PROJECT LIFECYCLE SUMMARY${NC}"
    echo ""
    
    if [[ ! -f "$PROJECT_LIFECYCLE_FILE" ]]; then
        echo "No lifecycle data available"
        return 1
    fi
    
    export PROJECT_LIFECYCLE_FILE
    python3 << 'EOF'
import json
import os
from collections import Counter
from datetime import datetime

lifecycle_file = os.environ.get('PROJECT_LIFECYCLE_FILE')
try:
    with open(lifecycle_file, 'r') as f:
        lifecycle_data = json.load(f)
    
    projects = lifecycle_data.get('projects', {})
    transitions = lifecycle_data.get('transitions', [])
    milestones = lifecycle_data.get('milestones', {})
    
    print(f"📊 Total projects tracked: {len(projects)}")
    
    # Stage distribution
    stages = Counter(project['current_stage'] for project in projects.values())
    print("\n🌱 Projects by stage:")
    for stage, count in stages.most_common():
        print(f"   • {stage}: {count}")
    
    # Recent milestones
    if milestones:
        print(f"\n🎯 Milestones achieved: {len(milestones)}")
        recent_milestones = sorted(milestones.values(), 
                                 key=lambda x: x['achieved_at'], reverse=True)[:3]
        for milestone in recent_milestones:
            print(f"   • {milestone['title']} ({milestone['project']})")
    
    # Transition summary
    if transitions:
        print(f"\n🔄 Total transitions: {len(transitions)}")
        successful_completions = [t for t in transitions 
                                if t['to_stage'] == 'production']
        if successful_completions:
            print(f"   • Successful deployments: {len(successful_completions)}")
    
except Exception as e:
    print(f"Error loading lifecycle data: {e}")
EOF
}

# Help function
show_help() {
    echo "Claude Project Enhanced - Smart project management with intelligence"
    echo ""
    echo "Usage: claude-project-enhanced [command] [options]"
    echo ""
    echo "Commands:"
    echo "  detect                       Smart project detection with analysis"
    echo "  switch <project>             Switch to project with context management"
    echo "  status                       Show enhanced project status"
    echo "  lifecycle                    Show project lifecycle summary"
    echo "  intelligence                 Extract cross-project intelligence"
    echo "  save-context [project]       Save current project context"
    echo "  load-context <project>       Load project context"
    echo ""
    echo "Examples:"
    echo "  claude-project-enhanced detect"
    echo "  claude-project-enhanced switch my-webapp"
    echo "  claude-project-enhanced status"
    echo "  claude-project-enhanced lifecycle"
    echo ""
    echo "Features:"
    echo "  • Smart detection (active/sandbox/production/external)"
    echo "  • Project lifecycle tracking (idea → active → production)"
    echo "  • Context switching with state preservation"
    echo "  • Cross-project intelligence patterns"
    echo "  • Technology stack analysis"
    echo "  • Milestone detection"
}

# Initialize databases
initialize_project_databases

# Main command handling
case "${1:-}" in
    "detect")
        detect_project_enhanced false
        ;;
    "switch")
        if [[ -z "$2" ]]; then
            echo -e "${RED}❌ Please specify project name${NC}"
            echo "Usage: $0 switch <project_name>"
            exit 1
        fi
        switch_project "$2"
        ;;
    "status")
        show_project_status_enhanced
        ;;
    "lifecycle")
        show_lifecycle_summary
        ;;
    "intelligence")
        extract_cross_project_intelligence
        ;;
    "save-context")
        current_project_json=$(detect_project_enhanced)
        if [[ "$current_project_json" != "null" ]]; then
            project_name=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('name', ''))")
            save_project_context "$project_name" "manual"
        else
            echo -e "${RED}❌ No project detected${NC}"
        fi
        ;;
    "load-context")
        if [[ -z "$2" ]]; then
            echo -e "${RED}❌ Please specify project name${NC}"
            echo "Usage: $0 load-context <project_name>"
            exit 1
        fi
        load_project_context "$2"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_project_status_enhanced
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac