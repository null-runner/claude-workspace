#!/bin/bash
# Claude Smart Sync - Natural Checkpoints Auto-Sync System
# Monitora checkpoint naturali del workflow e sincronizza automaticamente

WORKSPACE_DIR="$HOME/claude-workspace"
SYNC_DIR="$WORKSPACE_DIR/.claude/sync"
CONFIG_FILE="$SYNC_DIR/config.json"
STATE_DIR="$SYNC_DIR/state"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup directories
mkdir -p "$SYNC_DIR" "$STATE_DIR" "$STATE_DIR/dir-timestamps"

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat > "$CONFIG_FILE" << 'EOF'
{
  "milestone_commit_threshold": 20,
  "context_switch_stability": 600,
  "natural_break_inactivity": 900,
  "intense_session_threshold": 2,
  "max_syncs_per_hour": 6,
  "enable_milestone_commits": true,
  "enable_context_switches": true,
  "enable_natural_breaks": true,
  "enable_exit_sync": true
}
EOF
        echo -e "${GREEN}✅ Created default config at $CONFIG_FILE${NC}"
    fi
    
    # Parse JSON config
    MILESTONE_THRESHOLD=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['milestone_commit_threshold'])")
    CONTEXT_STABILITY=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['context_switch_stability'])")
    BREAK_INACTIVITY=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['natural_break_inactivity'])")
    SESSION_THRESHOLD=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['intense_session_threshold'])")
    MAX_SYNCS_HOUR=$(python3 -c "import json; print(json.load(open('$CONFIG_FILE'))['max_syncs_per_hour'])")
}

# Logging function
log_sync() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $message" >> "$SYNC_DIR/smart-sync.log"
    echo -e "${CYAN}[SMART-SYNC]${NC} $message"
}

# Rate limiting check
check_rate_limit() {
    local sync_log="$SYNC_DIR/sync-timestamps.log"
    local current_time=$(date +%s)
    local hour_ago=$((current_time - 3600))
    
    # Count syncs in last hour
    local recent_syncs=0
    if [[ -f "$sync_log" ]]; then
        recent_syncs=$(awk -v threshold="$hour_ago" '$1 > threshold' "$sync_log" 2>/dev/null | wc -l)
    fi
    
    if [[ $recent_syncs -ge ${MAX_SYNCS_HOUR:-6} ]]; then
        log_sync "Rate limit reached: $recent_syncs/${MAX_SYNCS_HOUR:-6} syncs in last hour"
        return 1
    fi
    
    return 0
}

# Record sync timestamp
record_sync() {
    local reason="$1"
    local current_time=$(date +%s)
    echo "$current_time $reason" >> "$SYNC_DIR/sync-timestamps.log"
}

# Core sync function
trigger_sync() {
    local reason="$1"
    
    cd "$WORKSPACE_DIR"
    
    # Rate limiting
    if ! check_rate_limit; then
        return 1
    fi
    
    log_sync "Triggering sync: $reason"
    
    # Check if there are changes to sync
    if [[ -z $(git status --porcelain) ]]; then
        log_sync "No changes to sync"
        return 0
    fi
    
    # Create list of files to sync (exclude system noise)
    local files_to_sync=""
    
    # Always include user files
    git add scripts/ docs/ CLAUDE.md projects/ 2>/dev/null
    
    # Include important system files
    git add .claude/memory/enhanced-context.json 2>/dev/null
    git add .claude/memory/workspace-memory.json 2>/dev/null
    git add .claude/memory/current-session-context.json 2>/dev/null
    git add .claude/intelligence/auto-learnings.json 2>/dev/null
    git add .claude/intelligence/auto-decisions.json 2>/dev/null
    git add .claude/decisions/ 2>/dev/null
    git add .claude/settings.local.json 2>/dev/null
    
    # Check if anything was actually staged
    if git diff --cached --quiet; then
        log_sync "No meaningful changes to sync"
        return 0
    fi
    
    # Create smart commit message
    local files_changed=$(git diff --cached --name-only | wc -l)
    local commit_msg="🔄 Smart sync: $reason ($files_changed files)"
    
    # Commit and push
    if git commit -m "$commit_msg"; then
        if git push origin main; then
            log_sync "✅ Sync successful: $files_changed files"
            record_sync "$reason"
        else
            log_sync "❌ Push failed for: $reason"
        fi
    else
        log_sync "❌ Commit failed for: $reason"
    fi
}

# Check 1: Milestone Commits
check_milestone_commits() {
    local last_commit_time=$(git log -1 --pretty=format:"%ct" 2>/dev/null)
    local current_time=$(date +%s)
    local last_checked_file="$STATE_DIR/last-milestone-check"
    
    # Skip if no commits
    if [[ -z "$last_commit_time" ]]; then
        return 0
    fi
    
    # Skip if commit too old (>5 minutes)
    if [[ $((current_time - last_commit_time)) -gt 300 ]]; then
        return 0
    fi
    
    # Skip if already checked this commit
    local last_checked_commit=$(cat "$last_checked_file" 2>/dev/null)
    local current_commit=$(git log -1 --pretty=format:"%H")
    if [[ "$last_checked_commit" == "$current_commit" ]]; then
        return 0
    fi
    
    # Analyze commit
    local commit_message=$(git log -1 --pretty=format:"%s")
    local diff_stats=$(git diff HEAD~1 --stat | tail -1)
    local lines_changed=$(echo "$diff_stats" | grep -o '[0-9]\+ insertions\|[0-9]\+ deletions' | head -1 | grep -o '[0-9]\+' || echo "0")
    
    # Check if milestone commit
    if [[ "$commit_message" =~ (add|implement|fix|complete|update|create|build) ]]; then
        # Check significance
        local significant=false
        
        # Significant if enough lines changed
        if [[ ${lines_changed:-0} -gt $MILESTONE_THRESHOLD ]]; then
            significant=true
        fi
        
        # Significant if script/config files
        if git diff HEAD~1 --name-only | grep -qE '\.(sh|py|js|json|md)$'; then
            significant=true
        fi
        
        # Significant if new files
        if git diff HEAD~1 --name-status | grep -q '^A'; then
            significant=true
        fi
        
        if [[ "$significant" == "true" ]]; then
            trigger_sync "Milestone commit: $commit_message"
        fi
    fi
    
    # Record that we checked this commit
    echo "$current_commit" > "$last_checked_file"
}

# Check 2: Context Switches
check_context_switches() {
    local current_dir=$(pwd)
    local current_time=$(date +%s)
    local last_dir_file="$STATE_DIR/last-working-dir"
    local last_dir=$(cat "$last_dir_file" 2>/dev/null)
    
    # Update current directory timestamp
    local dir_name=$(basename "$current_dir")
    touch "$STATE_DIR/dir-timestamps/$dir_name"
    
    # Check if directory changed
    if [[ -n "$last_dir" ]] && [[ "$current_dir" != "$last_dir" ]]; then
        # Check if current directory is stable (>10 minutes)
        local dir_timestamp_file="$STATE_DIR/dir-timestamps/$dir_name"
        if [[ -f "$dir_timestamp_file" ]]; then
            local dir_age=$(find "$dir_timestamp_file" -mmin +$((CONTEXT_STABILITY/60)) 2>/dev/null)
            if [[ -n "$dir_age" ]]; then
                local last_dir_name=$(basename "$last_dir")
                trigger_sync "Context switch: $last_dir_name → $dir_name"
            fi
        fi
    fi
    
    # Save current directory
    echo "$current_dir" > "$last_dir_file"
}

# Check 3: Natural Breaks
check_natural_breaks() {
    local current_time=$(date +%s)
    local last_activity_file="$STATE_DIR/last-activity-time"
    local last_break_sync_file="$STATE_DIR/last-break-sync"
    
    # Update activity time if there are recent file changes
    if find "$WORKSPACE_DIR" -maxdepth 3 -type f \( -name "*.py" -o -name "*.sh" -o -name "*.md" -o -name "*.js" \) -mmin -5 | grep -q .; then
        echo "$current_time" > "$last_activity_file"
        return 0
    fi
    
    # Check inactivity
    local last_activity=$(cat "$last_activity_file" 2>/dev/null || echo "$current_time")
    local inactivity=$((current_time - last_activity))
    
    if [[ $inactivity -gt $BREAK_INACTIVITY ]]; then
        # Check if we had intense session before this break
        local last_break_sync=$(cat "$last_break_sync_file" 2>/dev/null || echo "0")
        
        # Only trigger if we haven't synced for this break yet
        if [[ $last_break_sync -lt $last_activity ]]; then
            local intense_session=$(check_recent_intense_activity)
            if [[ "$intense_session" == "true" ]]; then
                trigger_sync "Natural break after productive session"
                echo "$current_time" > "$last_break_sync_file"
            fi
        fi
    fi
}

# Helper: Check for intense session
check_recent_intense_activity() {
    local hour_ago=$(date -d '1 hour ago' +%s)
    
    # Count recent commits
    local recent_commits=$(git log --since="1 hour ago" --oneline | wc -l)
    
    # Count recently modified files
    local recent_files=$(find "$WORKSPACE_DIR" -maxdepth 3 -type f \( -name "*.py" -o -name "*.sh" -o -name "*.md" -o -name "*.js" \) -mmin -60 | wc -l)
    
    if [[ $recent_commits -gt $SESSION_THRESHOLD ]] || [[ $recent_files -gt 5 ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Main monitoring loop
monitor_checkpoints() {
    log_sync "Starting smart sync monitoring with PID $$"
    
    while true; do
        cd "$WORKSPACE_DIR"
        
        # Load fresh config
        load_config
        
        # Run checks
        check_milestone_commits
        check_context_switches  
        check_natural_breaks
        
        # Sleep for 1 minute
        sleep 60
    done
}

# Status display
show_status() {
    echo -e "${BLUE}🔄 Claude Smart Sync Status${NC}"
    echo ""
    
    # Check if running
    local pid_file="$SYNC_DIR/smart-sync.pid"
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "Status: ${GREEN}✅ Running${NC} (PID: $pid)"
        else
            echo -e "Status: ${RED}❌ Stopped${NC} (stale PID file)"
            rm -f "$pid_file"
        fi
    else
        echo -e "Status: ${RED}❌ Not running${NC}"
    fi
    
    # Show recent syncs
    echo ""
    echo "Recent sync activity:"
    if [[ -f "$SYNC_DIR/smart-sync.log" ]]; then
        tail -5 "$SYNC_DIR/smart-sync.log" | while read line; do
            echo "  $line"
        done
    else
        echo "  No activity logged"
    fi
    
    # Show configuration
    echo ""
    echo "Configuration:"
    if [[ -f "$CONFIG_FILE" ]]; then
        echo "  Milestone threshold: ${MILESTONE_THRESHOLD:-20} lines"
        echo "  Context stability: $((${CONTEXT_STABILITY:-600}/60)) minutes"
        echo "  Break inactivity: $((${BREAK_INACTIVITY:-900}/60)) minutes"
        echo "  Max syncs/hour: ${MAX_SYNCS_HOUR:-6}"
    fi
}

# Start service
start_service() {
    local pid_file="$SYNC_DIR/smart-sync.pid"
    
    if [[ -f "$pid_file" ]]; then
        local existing_pid=$(cat "$pid_file")
        if kill -0 "$existing_pid" 2>/dev/null; then
            echo -e "${YELLOW}Smart sync already running with PID $existing_pid${NC}"
            return 1
        else
            rm -f "$pid_file"
        fi
    fi
    
    # Start in background
    nohup "$0" monitor > "$SYNC_DIR/smart-sync-output.log" 2>&1 &
    local new_pid=$!
    echo "$new_pid" > "$pid_file"
    
    echo -e "${GREEN}✅ Smart sync started with PID $new_pid${NC}"
    echo "Logs: $SYNC_DIR/smart-sync.log"
}

# Stop service
stop_service() {
    local pid_file="$SYNC_DIR/smart-sync.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid"
            rm -f "$pid_file"
            echo -e "${GREEN}✅ Smart sync stopped${NC}"
        else
            echo -e "${RED}Smart sync not running${NC}"
            rm -f "$pid_file"
        fi
    else
        echo -e "${RED}Smart sync not running${NC}"
    fi
}

# Force sync now
force_sync() {
    local reason="${1:-Manual sync request}"
    load_config  # Load config before sync
    trigger_sync "$reason"
}

# Main command handling
case "${1:-}" in
    "start")
        start_service
        ;;
    "stop")
        stop_service
        ;;
    "restart")
        stop_service
        sleep 2
        start_service
        ;;
    "status")
        show_status
        ;;
    "sync")
        force_sync "$2"
        ;;
    "monitor")
        # Internal command for background monitoring
        load_config
        monitor_checkpoints
        ;;
    "config")
        echo "Configuration file: $CONFIG_FILE"
        if [[ -f "$CONFIG_FILE" ]]; then
            cat "$CONFIG_FILE"
        else
            echo "Config file not found. Run 'start' to create default config."
        fi
        ;;
    "logs")
        if [[ -f "$SYNC_DIR/smart-sync.log" ]]; then
            tail -f "$SYNC_DIR/smart-sync.log"
        else
            echo "No logs found. Smart sync may not be running."
        fi
        ;;
    "help"|"-h"|"--help")
        echo "Claude Smart Sync - Natural Checkpoints Auto-Sync"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  start         Start smart sync monitoring"
        echo "  stop          Stop smart sync monitoring"  
        echo "  restart       Restart smart sync monitoring"
        echo "  status        Show current status"
        echo "  sync [reason] Force immediate sync"
        echo "  config        Show configuration"
        echo "  logs          Show real-time logs"
        echo ""
        ;;
    *)
        echo -e "${RED}Unknown command: ${1:-}${NC}"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac