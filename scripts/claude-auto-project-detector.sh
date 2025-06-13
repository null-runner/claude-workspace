#!/bin/bash
# Claude Auto Project Detector - Rileva automaticamente progetto corrente
# Auto-start/stop activity tracking basato su directory corrente

WORKSPACE_DIR="$HOME/claude-workspace"
PROJECTS_DIR="$WORKSPACE_DIR/projects"
DETECTOR_STATE="$WORKSPACE_DIR/.claude/auto-projects"
CURRENT_PROJECT_FILE="$DETECTOR_STATE/current.json"
DETECTOR_LOG="$DETECTOR_STATE/detector.log"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$DETECTOR_STATE"

# Logging function
log_detector() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$DETECTOR_LOG"
}

# Rileva progetto corrente dalla directory
detect_current_project() {
    python3 << 'EOF'
import os
import json

def detect_project():
    try:
        cwd = os.getcwd()
        workspace_dir = os.environ.get('WORKSPACE_DIR')
        
        if not workspace_dir or not cwd.startswith(workspace_dir):
            return None
        
        # Get relative path from workspace
        relative_path = os.path.relpath(cwd, workspace_dir)
        path_parts = relative_path.split(os.sep)
        
        # Check for projects/active/PROJECT_NAME pattern
        if len(path_parts) >= 3 and path_parts[0] == "projects" and path_parts[1] == "active":
            project_name = path_parts[2]
            project_type = "active"
            depth = len(path_parts) - 3  # Depth inside project
            
            return {
                "name": project_name,
                "type": project_type, 
                "path": os.path.join(workspace_dir, "projects", "active", project_name),
                "relative_path": "/".join(path_parts[:3]),
                "depth": depth,
                "full_path": cwd
            }
        
        # Check for projects/sandbox/PROJECT_NAME pattern  
        elif len(path_parts) >= 3 and path_parts[0] == "projects" and path_parts[1] == "sandbox":
            project_name = path_parts[2]
            project_type = "sandbox"
            depth = len(path_parts) - 3
            
            return {
                "name": project_name,
                "type": project_type,
                "path": os.path.join(workspace_dir, "projects", "sandbox", project_name), 
                "relative_path": "/".join(path_parts[:3]),
                "depth": depth,
                "full_path": cwd
            }
        
        # Check for projects/production/PROJECT_NAME pattern
        elif len(path_parts) >= 3 and path_parts[0] == "projects" and path_parts[1] == "production":
            project_name = path_parts[2]
            project_type = "production"
            depth = len(path_parts) - 3
            
            return {
                "name": project_name,
                "type": project_type,
                "path": os.path.join(workspace_dir, "projects", "production", project_name),
                "relative_path": "/".join(path_parts[:3]), 
                "depth": depth,
                "full_path": cwd
            }
        
        # Not in a recognized project directory
        return None
        
    except Exception as e:
        return None

project = detect_project()
if project:
    print(json.dumps(project))
else:
    print("null")
EOF
}

# Carica stato progetto corrente
load_current_project_state() {
    if [[ -f "$CURRENT_PROJECT_FILE" ]]; then
        python3 -c "
import json
try:
    with open('$CURRENT_PROJECT_FILE', 'r') as f:
        data = json.load(f)
    print(json.dumps(data))
except:
    print('null')
"
    else
        echo "null"
    fi
}

# Salva stato progetto corrente
save_current_project_state() {
    local project_json="$1"
    
    if [[ "$project_json" != "null" ]]; then
        echo "$project_json" > "$CURRENT_PROJECT_FILE"
    else
        rm -f "$CURRENT_PROJECT_FILE"
    fi
}

# Auto-start activity tracking per progetto
auto_start_project_tracking() {
    local project_name="$1"
    local project_type="$2"
    local project_path="$3"
    
    # Verifica se activity tracker script esiste
    if [[ ! -f "$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" ]]; then
        log_detector "WARN" "Activity tracker script not found - skipping auto-start"
        return 1
    fi
    
    log_detector "INFO" "Auto-starting tracking for project: $project_name ($project_type)"
    
    # Auto-start tracking con task description intelligente
    local task_desc="Auto-detected work in $project_path"
    
    # Prova a start tracking - cattura output per vedere se è già attivo
    local start_output
    start_output=$("$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" start "$project_name" "$project_type" "$task_desc" 2>&1)
    local start_result=$?
    
    if [[ $start_result -eq 0 ]]; then
        echo -e "${GREEN}🚀 Auto-started tracking: $project_name${NC}"
        log_detector "SUCCESS" "Tracking started for $project_name"
    else
        # Probabilmente già attivo - va bene
        log_detector "INFO" "Tracking start result: $start_output"
    fi
}

# Auto-stop activity tracking
auto_stop_project_tracking() {
    local project_name="$1"
    local reason="$2"
    
    if [[ ! -f "$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" ]]; then
        return 1
    fi
    
    log_detector "INFO" "Auto-stopping tracking for project: $project_name (reason: $reason)"
    
    local stop_output
    stop_output=$("$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" stop "$reason" 2>&1)
    local stop_result=$?
    
    if [[ $stop_result -eq 0 ]]; then
        echo -e "${YELLOW}⏹️  Auto-stopped tracking: $project_name${NC}"
        log_detector "SUCCESS" "Tracking stopped for $project_name"
    else
        log_detector "WARN" "Stop tracking failed: $stop_output"
    fi
}

# Check e aggiorna stato progetto
check_and_update_project() {
    local current_project_json
    current_project_json=$(detect_current_project)
    
    local previous_project_json
    previous_project_json=$(load_current_project_state)
    
    # Parse project info
    local current_project_name=""
    local current_project_type=""
    local current_project_path=""
    
    if [[ "$current_project_json" != "null" ]]; then
        current_project_name=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('name', ''))")
        current_project_type=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('type', ''))")
        current_project_path=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('path', ''))")
    fi
    
    local previous_project_name=""
    if [[ "$previous_project_json" != "null" ]]; then
        previous_project_name=$(echo "$previous_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('name', ''))")
    fi
    
    # Determine action needed
    if [[ "$current_project_name" != "$previous_project_name" ]]; then
        # Project change detected
        
        if [[ -n "$previous_project_name" && "$previous_project_json" != "null" ]]; then
            # Stop previous project
            auto_stop_project_tracking "$previous_project_name" "Project switch to $current_project_name"
        fi
        
        if [[ -n "$current_project_name" && "$current_project_json" != "null" ]]; then
            # Start new project
            auto_start_project_tracking "$current_project_name" "$current_project_type" "$current_project_path"
            echo -e "${CYAN}📁 Project detected: $current_project_name ($current_project_type)${NC}"
        else
            echo -e "${BLUE}📁 Left project workspace${NC}"
        fi
        
        # Update state
        save_current_project_state "$current_project_json"
        
        log_detector "INFO" "Project change: '$previous_project_name' → '$current_project_name'"
    else
        # No project change - just update timestamp if in project
        if [[ "$current_project_json" != "null" ]]; then
            save_current_project_state "$current_project_json"
        fi
    fi
}

# Show current project status
show_project_status() {
    local current_project_json
    current_project_json=$(detect_current_project)
    
    echo -e "${CYAN}📁 PROJECT DETECTION STATUS${NC}"
    echo ""
    
    if [[ "$current_project_json" != "null" ]]; then
        echo "$current_project_json" | python3 << 'EOF'
import json
import sys

data = json.load(sys.stdin)
print(f"✅ Project detected:")
print(f"   📁 Name: {data['name']}")
print(f"   📂 Type: {data['type']}")
print(f"   📍 Path: {data['relative_path']}")
print(f"   📊 Depth: {data['depth']} levels deep")
print(f"   🗂️  Full: {data['full_path']}")
EOF
    else
        echo "❌ No project detected"
        echo "   💡 Navigate to projects/active/PROJECT_NAME for auto-detection"
    fi
    
    # Show activity tracker status
    echo ""
    if [[ -f "$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" ]]; then
        echo -e "${BLUE}⏱️  Activity Tracker Status:${NC}"
        "$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" status 2>/dev/null || echo "   ❌ No active session"
    else
        echo -e "${YELLOW}⚠️  Activity tracker not available${NC}"
    fi
}

# Daemon mode per monitoring continuo
run_detector_daemon() {
    local check_interval="${1:-30}"  # seconds
    
    echo -e "${CYAN}🤖 Starting auto-project detector daemon (check every ${check_interval}s)${NC}"
    log_detector "INFO" "Detector daemon started with ${check_interval}s interval"
    
    while true; do
        check_and_update_project
        sleep "$check_interval"
    done
}

# Test detection senza side effects
test_detection() {
    echo -e "${CYAN}🧪 Testing project detection...${NC}"
    echo ""
    
    local current_project_json
    current_project_json=$(detect_current_project)
    
    echo "Current directory: $(pwd)"
    echo "Workspace directory: $WORKSPACE_DIR"
    echo ""
    
    if [[ "$current_project_json" != "null" ]]; then
        echo "✅ Detection result:"
        echo "$current_project_json" | python3 -c "
import json
import sys
data = json.load(sys.stdin)
for key, value in data.items():
    print(f'   {key}: {value}')
"
    else
        echo "❌ No project detected"
        echo ""
        echo "💡 Project detection rules:"
        echo "   • Must be in $WORKSPACE_DIR/projects/active/PROJECT_NAME/"
        echo "   • Or in $WORKSPACE_DIR/projects/sandbox/PROJECT_NAME/"  
        echo "   • Or in $WORKSPACE_DIR/projects/production/PROJECT_NAME/"
    fi
}

# Help
show_help() {
    echo "Claude Auto Project Detector - Automatic project detection and tracking"
    echo ""
    echo "Usage: claude-auto-project-detector [command] [options]"
    echo ""
    echo "Commands:"
    echo "  check                    Check and update current project"
    echo "  status                   Show current project detection status"
    echo "  test                     Test detection without side effects"
    echo "  daemon [interval]        Run detector daemon (default: 30s)"
    echo "  start-project            Manually start tracking for detected project"
    echo "  stop-project             Manually stop tracking"
    echo ""
    echo "Examples:"
    echo "  claude-auto-project-detector check"
    echo "  claude-auto-project-detector status"
    echo "  claude-auto-project-detector daemon 15"
    echo ""
    echo "Detection rules:"
    echo "  • Detects projects in: projects/active/, projects/sandbox/, projects/production/"
    echo "  • Auto-starts activity tracking when entering project directory"
    echo "  • Auto-stops tracking when leaving project directory"
}

# Main logic
case "${1:-}" in
    "check")
        check_and_update_project
        ;;
    "status")
        show_project_status
        ;;
    "test")
        test_detection
        ;;
    "daemon")
        run_detector_daemon "${2:-30}"
        ;;
    "start-project")
        current_project_json=$(detect_current_project)
        if [[ "$current_project_json" != "null" ]]; then
            project_name=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data['name'])")
            project_type=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data['type'])")
            project_path=$(echo "$current_project_json" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data['path'])")
            auto_start_project_tracking "$project_name" "$project_type" "$project_path"
        else
            echo -e "${RED}❌ No project detected in current directory${NC}"
        fi
        ;;
    "stop-project")
        auto_stop_project_tracking "manual-stop" "Manual stop requested"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_project_status
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac