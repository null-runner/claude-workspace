#!/bin/bash
# Claude Autonomous Exit - Smart exit completamente automatico
# Zero prompt, decisioni autonome basate su git status e tempo

WORKSPACE_DIR="$HOME/claude-workspace"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Funzione per exit autonomo
autonomous_exit() {
    local force_no_save="${1:-false}"
    
    echo -e "${CYAN}👋 Autonomous exit...${NC}"
    
    # Override per emergency exit
    if [[ "$force_no_save" == "true" ]]; then
        echo -e "${YELLOW}⚡ Emergency exit - no save${NC}"
        cleanup_and_exit
        return
    fi
    
    # Check se enhanced sessions devono essere salvate
    if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
        echo -e "${BLUE}🧠 Checking context save...${NC}"
        
        # Usa simplified memory per determinare se salvare
        local save_result
        save_result=$("$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" auto-save 2>&1)
        local save_exit_code=$?
        
        if [[ $save_exit_code -eq 0 ]]; then
            echo -e "${GREEN}💾 Context saved automatically${NC}"
        else
            echo -e "${BLUE}ℹ️  Context save skipped (no changes needed)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Simplified memory not available${NC}"
    fi
    
    # Check autonomous system status
    if [[ -f "$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" ]]; then
        local system_status
        system_status=$("$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" status 2>&1)
        
        if echo "$system_status" | grep -q "RUNNING"; then
            echo -e "${GREEN}🤖 Autonomous system continues running${NC}"
        else
            echo -e "${YELLOW}⚠️  Autonomous system not running${NC}"
        fi
    fi
    
    cleanup_and_exit
}

# Cleanup e exit finale
cleanup_and_exit() {
    # Stop tracking attivo se presente
    if [[ -f "$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" ]]; then
        local current_session="$WORKSPACE_DIR/.claude/activity/current-session.json"
        if [[ -f "$current_session" ]]; then
            echo -e "${BLUE}⏹️  Stopping active project tracking...${NC}"
            "$WORKSPACE_DIR/scripts/claude-activity-tracker.sh" stop "Session ended" >/dev/null 2>&1
        fi
    fi
    
    # Rimuovi lock files temporanei se esistono
    find "$WORKSPACE_DIR/.claude" -name "*.lock" -mtime +0 -delete 2>/dev/null || true
    
    echo -e "${GREEN}✨ Goodbye!${NC}"
    exit 0
}

# Intelligent exit con context analysis
intelligent_exit() {
    echo -e "${PURPLE}🧠 Intelligent exit analysis...${NC}"
    
    # Genera summary intelligente di cosa è stato fatto
    if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
        # Usa simplified memory per generare summary
        echo -e "${CYAN}📋 Session summary:${NC}"
        "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" load 2>/dev/null | head -10
    fi
    
    autonomous_exit
}

# Force exit senza salvataggio (emergency)
force_exit() {
    echo -e "${RED}⚡ Force exit - no save${NC}"
    autonomous_exit true
}

# Override del comando exit builtin
override_exit() {
    # Questa funzione può essere sourcata per override exit
    echo 'alias exit="$HOME/claude-workspace/scripts/claude-autonomous-exit.sh"'
}

# Analisi attività sessione per summary
analyze_session_activity() {
    python3 << 'EOF'
import subprocess
import os
from datetime import datetime, timedelta

def analyze_activity():
    workspace_dir = os.environ.get('WORKSPACE_DIR')
    
    activity_summary = {
        'git_changes': 0,
        'projects_touched': [],
        'session_duration': 'unknown',
        'activity_level': 'minimal'
    }
    
    try:
        # Check git changes
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True,
                              cwd=workspace_dir)
        if result.returncode == 0:
            changes = [line for line in result.stdout.strip().split('\n') if line]
            activity_summary['git_changes'] = len(changes)
        
        # Determine activity level
        if activity_summary['git_changes'] > 10:
            activity_summary['activity_level'] = 'high'
        elif activity_summary['git_changes'] > 3:
            activity_summary['activity_level'] = 'medium'
        elif activity_summary['git_changes'] > 0:
            activity_summary['activity_level'] = 'low'
        
        # Check current project
        try:
            cwd = os.getcwd()
            if 'projects/active' in cwd:
                project_parts = cwd.split('projects/active/')
                if len(project_parts) > 1:
                    project_name = project_parts[1].split('/')[0]
                    activity_summary['projects_touched'].append(project_name)
        except:
            pass
        
        return activity_summary
        
    except Exception as e:
        return activity_summary

# Analyze and print summary
summary = analyze_activity()

print(f"📊 Session Activity Summary:")
print(f"   📝 Git changes: {summary['git_changes']} files")
print(f"   📁 Projects: {', '.join(summary['projects_touched']) if summary['projects_touched'] else 'None detected'}")
print(f"   🎯 Activity level: {summary['activity_level']}")

EOF
    export WORKSPACE_DIR
}

# Help
show_help() {
    echo "Claude Autonomous Exit - Smart exit without prompts"
    echo ""
    echo "Usage: claude-autonomous-exit [command]"
    echo ""
    echo "Commands:"
    echo "  (no args)                    Standard autonomous exit"
    echo "  smart                        Intelligent exit with analysis"
    echo "  force                        Force exit without save (emergency)"
    echo "  override                     Show alias for overriding 'exit' command"
    echo "  analyze                      Show session activity analysis"
    echo ""
    echo "Exit behavior:"
    echo "  • Automatically saves context if git has changes"
    echo "  • Automatically saves if >30min since last save"
    echo "  • Skips save if git clean and recent save"
    echo "  • No user prompts or questions"
    echo "  • Stops active project tracking"
    echo "  • Autonomous system continues running"
    echo ""
    echo "To override standard 'exit' command:"
    echo "  echo 'alias exit=\"\\$HOME/claude-workspace/scripts/claude-autonomous-exit.sh\"' >> ~/.bashrc"
    echo "  source ~/.bashrc"
}

# Main logic
case "${1:-}" in
    "smart")
        intelligent_exit
        ;;
    "force")
        force_exit
        ;;
    "override")
        override_exit
        ;;
    "analyze")
        analyze_session_activity
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        autonomous_exit
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac