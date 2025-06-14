#!/bin/bash
# Claude Project Lifecycle Manager
# Gestisce il ciclo di vita completo dei progetti: sandbox → active → production → external

WORKSPACE_DIR="$HOME/claude-workspace"
PROJECTS_DIR="$WORKSPACE_DIR/projects"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Setup - New 4-stage system
mkdir -p "$PROJECTS_DIR"/{sandbox,active,stable,public}
LIFECYCLE_LOG="$WORKSPACE_DIR/.claude/projects/lifecycle.log"
PROJECT_CONFIG="$WORKSPACE_DIR/.claude/projects/project-config.json"

mkdir -p "$(dirname "$LIFECYCLE_LOG")"
mkdir -p "$(dirname "$PROJECT_CONFIG")"

# Logging function
log_lifecycle() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LIFECYCLE_LOG"
}

# Initialize project config if not exists
init_project_config() {
    if [[ ! -f "$PROJECT_CONFIG" ]]; then
        cat > "$PROJECT_CONFIG" << 'EOF'
{
  "version": "1.0",
  "projects": {},
  "external_repos": {},
  "graduation_history": []
}
EOF
    fi
}

# Get project info from config
get_project_info() {
    local project_name="$1"
    if [[ -f "$PROJECT_CONFIG" ]]; then
        python3 -c "
import json
try:
    with open('$PROJECT_CONFIG', 'r') as f:
        config = json.load(f)
    project = config.get('projects', {}).get('$project_name')
    if project:
        print(json.dumps(project))
    else:
        print('null')
except:
    print('null')
"
    else
        echo "null"
    fi
}

# Update project config
update_project_config() {
    local project_name="$1"
    local stage="$2"
    local external_repo="$3"
    local description="$4"
    
    python3 << EOF
import json
import os
from datetime import datetime

config_file = '$PROJECT_CONFIG'
try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {"version": "1.0", "projects": {}, "external_repos": {}, "graduation_history": []}

# Update project info
config['projects']['$project_name'] = {
    "name": "$project_name",
    "current_stage": "$stage",
    "external_repo": "$external_repo" if "$external_repo" else None,
    "description": "$description",
    "created_at": config['projects'].get('$project_name', {}).get('created_at', datetime.now().isoformat()),
    "updated_at": datetime.now().isoformat(),
    "workspace_path": os.path.join("$PROJECTS_DIR", "$stage", "$project_name")
}

# Save config
with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
EOF

    log_lifecycle "INFO" "Updated project config: $project_name -> $stage"
}

# Graduate project to next stage
graduate_project() {
    local project_name="$1"
    local current_stage="$2"
    local target_stage="$3"
    local external_repo="$4"
    
    local current_path="$PROJECTS_DIR/$current_stage/$project_name"
    local target_path="$PROJECTS_DIR/$target_stage/$project_name"
    
    echo -e "${BLUE}🎓 Graduating project: $project_name${NC}"
    echo -e "${CYAN}   From: $current_stage${NC}"
    echo -e "${CYAN}   To: $target_stage${NC}"
    
    # Verify source exists
    if [[ ! -d "$current_path" ]]; then
        echo -e "${RED}❌ Project not found in $current_stage: $current_path${NC}"
        return 1
    fi
    
    # Create target directory if needed
    mkdir -p "$(dirname "$target_path")"
    
    # Copy project files
    echo -e "${YELLOW}📁 Copying project files...${NC}"
    if cp -r "$current_path" "$target_path"; then
        echo -e "${GREEN}✅ Files copied successfully${NC}"
    else
        echo -e "${RED}❌ Failed to copy files${NC}"
        return 1
    fi
    
    # Update project config
    update_project_config "$project_name" "$target_stage" "$external_repo" "Graduated from $current_stage"
    
    # Log graduation
    log_lifecycle "GRADUATION" "$project_name: $current_stage -> $target_stage"
    
    # Record graduation history
    python3 << EOF
import json
from datetime import datetime

config_file = '$PROJECT_CONFIG'
with open(config_file, 'r') as f:
    config = json.load(f)

graduation_record = {
    "project": "$project_name",
    "from_stage": "$current_stage", 
    "to_stage": "$target_stage",
    "external_repo": "$external_repo" if "$external_repo" else None,
    "timestamp": datetime.now().isoformat(),
    "graduation_id": f"grad-{datetime.now().strftime('%Y%m%d-%H%M%S')}-$project_name"
}

config['graduation_history'].append(graduation_record)

with open(config_file, 'w') as f:
    json.dump(config, f, indent=2)
EOF
    
    echo -e "${GREEN}🎉 Project graduated successfully!${NC}"
    echo -e "${YELLOW}💡 Old version remains in $current_stage for backup${NC}"
    
    # Show next steps based on target stage
    if [[ "$target_stage" == "stable" ]]; then
        echo ""
        echo -e "${PURPLE}🎯 Next steps for stable release:${NC}"
        echo -e "   1. Test all features thoroughly"
        echo -e "   2. Update documentation and README"
        echo -e "   3. Consider: ready for users or business release"
    elif [[ "$target_stage" == "public" ]]; then
        echo ""
        echo -e "${PURPLE}🌐 Next steps for public deployment:${NC}"
        if [[ -n "$external_repo" ]]; then
            echo -e "   1. Create external repository: $external_repo"
            echo -e "   2. Run: claude-project-lifecycle sync $project_name"
            echo -e "   3. Setup CI/CD pipeline and community features"
        else
            echo -e "   1. Consider adding external repository URL"
            echo -e "   2. Prepare for API documentation"
            echo -e "   3. Setup community guidelines"
        fi
    fi
    
    return 0
}

# Sync project to external repository
sync_to_external() {
    local project_name="$1"
    local project_info
    project_info=$(get_project_info "$project_name")
    
    if [[ "$project_info" == "null" ]]; then
        echo -e "${RED}❌ Project not found in config: $project_name${NC}"
        return 1
    fi
    
    local external_repo
    external_repo=$(echo "$project_info" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('external_repo', ''))")
    
    if [[ -z "$external_repo" ]]; then
        echo -e "${RED}❌ No external repository configured for $project_name${NC}"
        echo -e "${YELLOW}💡 Use: claude-project-lifecycle graduate $project_name public <repo-url>${NC}"
        return 1
    fi
    
    local workspace_path="$PROJECTS_DIR/public/$project_name"
    
    if [[ ! -d "$workspace_path" ]]; then
        echo -e "${RED}❌ Project not found in public stage: $workspace_path${NC}"
        return 1
    fi
    
    echo -e "${BLUE}🔄 Syncing project to external repository...${NC}"
    echo -e "${CYAN}   Project: $project_name${NC}"
    echo -e "${CYAN}   External repo: $external_repo${NC}"
    
    # Check if external repo directory exists
    local external_dir="$WORKSPACE_DIR/external-repos/$project_name"
    
    if [[ ! -d "$external_dir" ]]; then
        echo -e "${YELLOW}📥 Cloning external repository...${NC}"
        mkdir -p "$(dirname "$external_dir")"
        
        if git clone "$external_repo" "$external_dir"; then
            echo -e "${GREEN}✅ Repository cloned${NC}"
        else
            echo -e "${RED}❌ Failed to clone repository${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}🔄 Updating external repository...${NC}"
        cd "$external_dir" && git pull
    fi
    
    # Sync files (excluding .git)
    echo -e "${YELLOW}📁 Syncing files...${NC}"
    rsync -av --exclude='.git' "$workspace_path/" "$external_dir/"
    
    # Commit and push changes
    cd "$external_dir"
    
    if git diff --quiet && git diff --staged --quiet; then
        echo -e "${YELLOW}ℹ️  No changes to sync${NC}"
        return 0
    fi
    
    git add .
    git commit -m "🔄 Sync from workspace: $(date '+%Y-%m-%d %H:%M:%S')

Synced from claude-workspace project: $project_name
Workspace path: $workspace_path

🤖 Generated with Claude Workspace
"
    
    if git push; then
        echo -e "${GREEN}🚀 Successfully synced to external repository!${NC}"
        log_lifecycle "SYNC" "$project_name synced to $external_repo"
    else
        echo -e "${RED}❌ Failed to push to external repository${NC}"
        return 1
    fi
}

# List all projects with their stages
list_projects() {
    echo -e "${BLUE}📋 Project Lifecycle Status${NC}"
    echo ""
    
    init_project_config
    
    export PROJECT_CONFIG PROJECTS_DIR
    
    python3 << 'EOF'
import json
import os

config_file = os.environ.get('PROJECT_CONFIG')
projects_dir = os.environ.get('PROJECTS_DIR')

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    config = {"projects": {}}

projects = config.get('projects', {})

if not projects:
    print("No projects found.")
    exit()

# Group by stage
stages = {}
for name, project in projects.items():
    stage = project.get('current_stage', 'unknown')
    if stage not in stages:
        stages[stage] = []
    stages[stage].append(project)

# Display by stage
stage_colors = {
    'sandbox': '\033[1;33m',     # Yellow
    'active': '\033[0;32m',      # Green  
    'stable': '\033[0;34m',      # Blue
    'public': '\033[0;35m',      # Purple
}

for stage in ['sandbox', 'active', 'stable', 'public']:
    if stage in stages:
        color = stage_colors.get(stage, '\033[0m')
        print(f"{color}🏷️  {stage.upper()}:\033[0m")
        
        for project in stages[stage]:
            name = project['name']
            desc = project.get('description', 'No description')
            external = project.get('external_repo')
            
            print(f"   📦 {name}")
            print(f"      📝 {desc}")
            if external:
                print(f"      🔗 {external}")
            print()
EOF
}

# Show graduation history
show_history() {
    echo -e "${BLUE}📜 Project Graduation History${NC}"
    echo ""
    
    export PROJECT_CONFIG
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

config_file = os.environ.get('PROJECT_CONFIG')

try:
    with open(config_file, 'r') as f:
        config = json.load(f)
except:
    print("No graduation history found.")
    exit()

history = config.get('graduation_history', [])

if not history:
    print("No graduations recorded yet.")
    exit()

for record in reversed(history[-10:]):  # Show last 10
    timestamp = record['timestamp']
    project = record['project']
    from_stage = record['from_stage']
    to_stage = record['to_stage']
    
    # Parse timestamp
    try:
        dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
        time_str = dt.strftime('%Y-%m-%d %H:%M')
    except:
        time_str = timestamp
    
    print(f"🎓 {time_str}: {project}")
    print(f"   {from_stage} → {to_stage}")
    if record.get('external_repo'):
        print(f"   🔗 {record['external_repo']}")
    print()
EOF
}

# Show help
show_help() {
    echo -e "${BLUE}Claude Project Lifecycle Manager${NC}"
    echo ""
    echo "Usage:"
    echo "  claude-project-lifecycle <command> [options]"
    echo ""
    echo "Commands:"
    echo -e "  ${GREEN}list${NC}                              List all projects by stage"
    echo -e "  ${GREEN}graduate${NC} <project> <target-stage>  Graduate project to next stage"
    echo -e "  ${GREEN}graduate${NC} <project> external <repo> Graduate to external with repo URL"
    echo -e "  ${GREEN}sync${NC} <project>                    Sync project to external repository"
    echo -e "  ${GREEN}history${NC}                           Show graduation history"
    echo -e "  ${GREEN}info${NC} <project>                    Show project information"
    echo ""
    echo "Stages:"
    echo -e "  ${YELLOW}sandbox${NC}     → Development and experimentation"
    echo -e "  ${GREEN}active${NC}      → Active development"
    echo -e "  ${BLUE}stable${NC}      → Ready for users, business-ready"
    echo -e "  ${PURPLE}public${NC}      → External repository, API, community"
    echo ""
    echo "Examples:"
    echo "  claude-project-lifecycle graduate my-app active"
    echo "  claude-project-lifecycle graduate my-app stable"
    echo "  claude-project-lifecycle graduate my-app public git@github.com:user/my-app.git"
    echo "  claude-project-lifecycle sync my-app"
}

# Show project info
show_project_info() {
    local project_name="$1"
    local project_info
    project_info=$(get_project_info "$project_name")
    
    if [[ "$project_info" == "null" ]]; then
        echo -e "${RED}❌ Project not found: $project_name${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📋 Project Information: $project_name${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime

project = json.loads('$project_info')

print(f"📦 Name: {project['name']}")
print(f"🏷️  Stage: {project['current_stage']}")
print(f"📝 Description: {project.get('description', 'No description')}")
print(f"📁 Workspace Path: {project['workspace_path']}")

if project.get('external_repo'):
    print(f"🔗 External Repo: {project['external_repo']}")

# Parse dates
try:
    created = datetime.fromisoformat(project['created_at'].replace('Z', '+00:00'))
    updated = datetime.fromisoformat(project['updated_at'].replace('Z', '+00:00'))
    print(f"📅 Created: {created.strftime('%Y-%m-%d %H:%M')}")
    print(f"🔄 Updated: {updated.strftime('%Y-%m-%d %H:%M')}")
except:
    print(f"📅 Created: {project.get('created_at', 'Unknown')}")
    print(f"🔄 Updated: {project.get('updated_at', 'Unknown')}")
EOF
}

# Initialize
init_project_config

# Main logic
case "${1:-}" in
    "list")
        list_projects
        ;;
    "graduate")
        if [[ $# -lt 3 ]]; then
            echo -e "${RED}❌ Usage: claude-project-lifecycle graduate <project> <target-stage> [external-repo]${NC}"
            exit 1
        fi
        
        project_name="$2"
        target_stage="$3"
        external_repo="$4"
        
        # Detect current stage from config first, then fallback to directory detection
        project_info=$(get_project_info "$project_name")
        if [[ "$project_info" != "null" ]]; then
            current_stage=$(echo "$project_info" | python3 -c "import json, sys; data=json.load(sys.stdin); print(data.get('current_stage', ''))")
        else
            current_stage=""
        fi
        
        # Fallback to directory detection if not in config
        if [[ -z "$current_stage" ]]; then
            for stage in sandbox active stable public; do
                if [[ -d "$PROJECTS_DIR/$stage/$project_name" ]]; then
                    current_stage="$stage"
                    break
                fi
            done
        fi
        
        if [[ -z "$current_stage" ]]; then
            echo -e "${RED}❌ Project not found in any stage: $project_name${NC}"
            exit 1
        fi
        
        graduate_project "$project_name" "$current_stage" "$target_stage" "$external_repo"
        ;;
    "sync")
        if [[ $# -lt 2 ]]; then
            echo -e "${RED}❌ Usage: claude-project-lifecycle sync <project>${NC}"
            exit 1
        fi
        sync_to_external "$2"
        ;;
    "history")
        show_history
        ;;
    "info")
        if [[ $# -lt 2 ]]; then
            echo -e "${RED}❌ Usage: claude-project-lifecycle info <project>${NC}"
            exit 1
        fi
        show_project_info "$2"
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac