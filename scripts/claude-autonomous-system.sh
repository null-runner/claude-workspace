#!/bin/bash
# Claude Autonomous System - Master daemon che gestisce tutto
# Unified background system per memoria, progetti, intelligence extraction

WORKSPACE_DIR="$HOME/claude-workspace"
AUTONOMOUS_DIR="$WORKSPACE_DIR/.claude/autonomous"
MASTER_LOG="$AUTONOMOUS_DIR/autonomous-system.log"
MASTER_PID_FILE="$AUTONOMOUS_DIR/autonomous-system.pid"
SERVICE_STATUS_FILE="$AUTONOMOUS_DIR/service-status.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Setup
mkdir -p "$AUTONOMOUS_DIR"

# Master logging function
log_master() {
    local level="$1"
    local service="$2"
    local message="$3"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$service] $message" >> "$MASTER_LOG"
    
    # Optional: echo to stdout for startup feedback
    if [[ "$level" == "ERROR" || "$level" == "STARTUP" ]]; then
        echo -e "${CYAN}[AUTONOMOUS]${NC} [$service] $message"
    fi
}

# Check if master daemon is running
check_master_running() {
    if [[ -f "$MASTER_PID_FILE" ]]; then
        local pid=$(cat "$MASTER_PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            # Stale PID file
            rm -f "$MASTER_PID_FILE"
            return 1  # Not running
        fi
    fi
    return 1  # Not running
}

# Update service status
update_service_status() {
    local service="$1"
    local status="$2"
    local message="$3"
    
    export service status message SERVICE_STATUS_FILE
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

status_file = os.environ.get('SERVICE_STATUS_FILE')
service = os.environ.get('service')
status = os.environ.get('status')
message = os.environ.get('message')

# Load existing status
try:
    with open(status_file, 'r') as f:
        service_status = json.load(f)
except:
    service_status = {
        'last_update': '',
        'services': {}
    }

# Update service status
service_status['services'][service] = {
    'status': status,
    'message': message,
    'last_update': datetime.now().isoformat() + 'Z'
}

service_status['last_update'] = datetime.now().isoformat() + 'Z'

# Save status
with open(status_file, 'w') as f:
    json.dump(service_status, f, indent=2)

EOF
}

# Check if atomic sync is requesting pause
check_sync_pause() {
    [[ -f "$WORKSPACE_DIR/.claude/autonomous/sync-pause.lock" ]]
}

# Wait for sync operation to complete
wait_for_sync_completion() {
    local service_name="$1"
    local max_wait=300  # 5 minutes max wait
    local wait_count=0
    
    while check_sync_pause && [[ $wait_count -lt $max_wait ]]; do
        update_service_status "$service_name" "paused" "Waiting for atomic sync to complete"
        sleep 5
        ((wait_count += 5))
    done
    
    if [[ $wait_count -ge $max_wait ]]; then
        log_master "WARN" "$service_name" "Sync pause timeout - resuming operations"
        return 1
    fi
    
    return 0
}

# Enhanced context monitoring (every 5 minutes)
run_context_monitor() {
    while true; do
        # Check for sync pause before file operations
        if check_sync_pause; then
            wait_for_sync_completion "CONTEXT"
        fi
        
        if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
            "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" auto-save >/dev/null 2>&1
            local result=$?
            
            if [[ $result -eq 0 ]]; then
                update_service_status "context_monitor" "active" "Auto-save completed"
            else
                update_service_status "context_monitor" "warning" "Auto-save skipped (no changes)"
            fi
        else
            update_service_status "context_monitor" "error" "Simplified memory script not found"
            log_master "ERROR" "CONTEXT" "Simplified memory script not found"
        fi
        
        sleep 300  # 5 minutes
    done
}

# Project detection monitoring (every 30 seconds)
run_project_monitor() {
    while true; do
        # Check for sync pause before file operations
        if check_sync_pause; then
            wait_for_sync_completion "PROJECT"
        fi
        
        if [[ -f "$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" ]]; then
            WORKSPACE_DIR="$WORKSPACE_DIR" "$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh" check >/dev/null 2>&1
            local result=$?
            
            if [[ $result -eq 0 ]]; then
                update_service_status "project_monitor" "active" "Project detection completed"
            else
                update_service_status "project_monitor" "warning" "Project detection had issues"
            fi
        else
            update_service_status "project_monitor" "error" "Project detector script not found"
            log_master "ERROR" "PROJECT" "Project detector script not found"
        fi
        
        sleep 30  # 30 seconds
    done
}

# Intelligence extraction (every 15 minutes)
run_intelligence_extractor() {
    while true; do
        # Check for sync pause before file operations
        if check_sync_pause; then
            wait_for_sync_completion "INTELLIGENCE"
        fi
        
        if [[ -f "$WORKSPACE_DIR/scripts/claude-intelligence-extractor.sh" ]]; then
            "$WORKSPACE_DIR/scripts/claude-intelligence-extractor.sh" extract >/dev/null 2>&1
            local result=$?
            
            if [[ $result -eq 0 ]]; then
                update_service_status "intelligence_extractor" "active" "Intelligence extraction completed"
            else
                update_service_status "intelligence_extractor" "warning" "Intelligence extraction had issues"
            fi
        else
            update_service_status "intelligence_extractor" "error" "Intelligence extractor script not found"
            log_master "ERROR" "INTELLIGENCE" "Intelligence extractor script not found"
        fi
        
        sleep 900  # 15 minutes
    done
}

# Health monitor (every 60 seconds)
run_health_monitor() {
    while true; do
        # Smart health check - look at actual service activity, not just processes
        export SERVICE_STATUS_FILE
        
        local health_output
        health_output=$(python3 << 'EOF'
import json
import os
from datetime import datetime, timedelta

def check_service_health():
    try:
        status_file = os.environ.get('SERVICE_STATUS_FILE')
        if not status_file or not os.path.exists(status_file):
            return "degraded", "No status file found"
        
        with open(status_file, 'r') as f:
            status = json.load(f)
        
        services = status.get('services', {})
        
        # Check core services (ignore 'null' entries and 'health_monitor' self-reference)
        core_services = ['context_monitor', 'project_monitor', 'intelligence_extractor']
        active_services = 0
        recent_activity = 0
        
        now = datetime.now()
        
        for service_name in core_services:
            if service_name in services:
                service = services[service_name]
                service_status = service.get('status')
                last_update = service.get('last_update')
                
                if service_status in ['active', 'running']:
                    active_services += 1
                
                # Check if service updated in last 20 minutes (reasonable for background services)
                if last_update:
                    try:
                        update_time = datetime.fromisoformat(last_update.replace('Z', ''))
                        if (now - update_time).total_seconds() < 1200:  # 20 minutes
                            recent_activity += 1
                    except:
                        pass
        
        # Health logic: if most services are active AND have recent activity
        if active_services >= 2 and recent_activity >= 2:
            return "healthy", f"All core services operational ({active_services}/3 active, {recent_activity}/3 recent)"
        elif active_services >= 1:
            return "degraded", f"Some services may be slow ({active_services}/3 active, {recent_activity}/3 recent)"
        else:
            return "critical", "Core services not responding"
            
    except Exception as e:
        return "degraded", f"Health check error: {str(e)}"

health_status, health_message = check_service_health()
print(f"{health_status}:{health_message}")
EOF
)
        
        local health_status=$(echo "$health_output" | cut -d: -f1)
        local health_message=$(echo "$health_output" | cut -d: -f2-)
        
        # Update health status
        update_service_status "health_monitor" "$health_status" "$health_message"
        
        # Log only if there are real issues
        if [[ "$health_status" != "healthy" ]]; then
            log_master "WARN" "HEALTH" "$health_message"
        fi
        
        sleep 60  # 1 minute
    done
}

# Start master autonomous daemon
start_autonomous_daemon() {
    if check_master_running; then
        echo -e "${YELLOW}⚠️  Autonomous system already running${NC}"
        return 1
    fi
    
    echo -e "${CYAN}🤖 Starting Claude Autonomous System...${NC}"
    log_master "STARTUP" "MASTER" "Starting autonomous system daemon"
    
    # Create PID file
    echo $$ > "$MASTER_PID_FILE"
    
    # Initialize service status
    update_service_status "master" "starting" "Initializing autonomous system"
    
    # Start background monitors
    echo -e "${BLUE}   📝 Starting context monitor...${NC}"
    run_context_monitor &
    local context_pid=$!
    
    echo -e "${BLUE}   📁 Starting project monitor...${NC}"  
    run_project_monitor &
    local project_pid=$!
    
    echo -e "${BLUE}   🧠 Starting intelligence extractor...${NC}"
    run_intelligence_extractor &
    local intelligence_pid=$!
    
    echo -e "${BLUE}   🏥 Starting health monitor...${NC}"
    run_health_monitor &
    local health_pid=$!
    
    # Update status
    update_service_status "master" "running" "All background services started"
    log_master "STARTUP" "MASTER" "All background services started successfully"
    
    # Setup signal handlers for graceful shutdown
    trap "shutdown_autonomous_system $context_pid $project_pid $intelligence_pid $health_pid" SIGTERM SIGINT
    
    echo -e "${GREEN}✅ Autonomous system started successfully${NC}"
    echo -e "${CYAN}   PID: $$${NC}"
    echo -e "${CYAN}   Logs: $MASTER_LOG${NC}"
    
    # Keep master process alive
    while true; do
        sleep 10
        
        # Check if PID file still exists (external shutdown signal)
        if [[ ! -f "$MASTER_PID_FILE" ]]; then
            log_master "INFO" "MASTER" "PID file removed - shutting down"
            break
        fi
    done
}

# Shutdown autonomous system
shutdown_autonomous_system() {
    local context_pid="$1"
    local project_pid="$2" 
    local intelligence_pid="$3"
    local health_pid="$4"
    
    echo -e "${YELLOW}🛑 Shutting down autonomous system...${NC}"
    log_master "SHUTDOWN" "MASTER" "Graceful shutdown initiated"
    
    # Update status
    update_service_status "master" "stopping" "Graceful shutdown in progress"
    
    # Kill background processes
    if [[ -n "$context_pid" ]]; then
        kill "$context_pid" 2>/dev/null
        update_service_status "context_monitor" "stopped" "Stopped by master shutdown"
    fi
    
    if [[ -n "$project_pid" ]]; then
        kill "$project_pid" 2>/dev/null
        update_service_status "project_monitor" "stopped" "Stopped by master shutdown"
    fi
    
    if [[ -n "$intelligence_pid" ]]; then
        kill "$intelligence_pid" 2>/dev/null
        update_service_status "intelligence_extractor" "stopped" "Stopped by master shutdown"
    fi
    
    if [[ -n "$health_pid" ]]; then
        kill "$health_pid" 2>/dev/null
        update_service_status "health_monitor" "stopped" "Stopped by master shutdown"
    fi
    
    # Final context save
    if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" save "autonomous_system_shutdown" >/dev/null 2>&1
    fi
    
    # Clean up
    rm -f "$MASTER_PID_FILE"
    update_service_status "master" "stopped" "Autonomous system stopped gracefully"
    log_master "SHUTDOWN" "MASTER" "Autonomous system stopped gracefully"
    
    echo -e "${GREEN}✅ Autonomous system stopped${NC}"
    exit 0
}

# Start daemon in background
start_background_daemon() {
    if check_master_running; then
        echo -e "${YELLOW}⚠️  Autonomous system already running${NC}"
        show_system_status
        return 1
    fi
    
    echo -e "${CYAN}🚀 Starting autonomous system in background...${NC}"
    
    # Start in background with nohup
    nohup "$0" daemon >/dev/null 2>&1 &
    local daemon_pid=$!
    
    # Wait a moment for startup
    sleep 2
    
    if check_master_running; then
        echo -e "${GREEN}✅ Autonomous system started successfully${NC}"
        show_system_status
    else
        echo -e "${RED}❌ Failed to start autonomous system${NC}"
        return 1
    fi
}

# Stop autonomous system
stop_autonomous_system() {
    if ! check_master_running; then
        echo -e "${YELLOW}⚠️  Autonomous system not running${NC}"
        return 1
    fi
    
    local pid=$(cat "$MASTER_PID_FILE")
    echo -e "${YELLOW}🛑 Stopping autonomous system (PID: $pid)...${NC}"
    
    # Send SIGTERM for graceful shutdown
    if kill -TERM "$pid" 2>/dev/null; then
        # Wait for graceful shutdown
        local count=0
        while check_master_running && [[ $count -lt 10 ]]; do
            sleep 1
            ((count++))
        done
        
        if check_master_running; then
            # Force kill if still running
            echo -e "${RED}⚠️  Forcing shutdown...${NC}"
            kill -KILL "$pid" 2>/dev/null
            rm -f "$MASTER_PID_FILE"
        fi
        
        echo -e "${GREEN}✅ Autonomous system stopped${NC}"
    else
        echo -e "${RED}❌ Failed to stop autonomous system${NC}"
        # Clean up stale PID file
        rm -f "$MASTER_PID_FILE"
        return 1
    fi
}

# Show system status
show_system_status() {
    echo -e "${PURPLE}🤖 AUTONOMOUS SYSTEM STATUS${NC}"
    echo ""
    
    if check_master_running; then
        local pid=$(cat "$MASTER_PID_FILE")
        echo -e "${GREEN}✅ Master daemon: RUNNING (PID: $pid)${NC}"
    else
        echo -e "${RED}❌ Master daemon: NOT RUNNING${NC}"
    fi
    
    echo ""
    
    # Show service status
    if [[ -f "$SERVICE_STATUS_FILE" ]]; then
        export SERVICE_STATUS_FILE
        python3 << 'EOF'
import json
import os
from datetime import datetime

try:
    with open(os.environ.get('SERVICE_STATUS_FILE'), 'r') as f:
        status = json.load(f)
    
    print("📊 SERVICE STATUS:")
    
    status_icons = {
        'active': '✅', 'running': '✅', 'healthy': '✅',
        'warning': '⚠️', 'degraded': '⚠️',
        'error': '❌', 'stopped': '⏹️', 'stopping': '🛑'
    }
    
    for service, info in status['services'].items():
        icon = status_icons.get(info['status'], '❓')
        print(f"   {icon} {service}: {info['status'].upper()}")
        if info.get('message'):
            print(f"      {info['message']}")
    
    print(f"\n🕐 Last update: {status.get('last_update', 'Unknown')}")
    
except Exception as e:
    print("📊 SERVICE STATUS: No status data available")

EOF
    else
        echo "📊 SERVICE STATUS: No status data available"
    fi
    
    echo ""
    echo "📁 Log file: $MASTER_LOG"
}

# Show recent logs
show_logs() {
    local lines="${1:-20}"
    
    if [[ -f "$MASTER_LOG" ]]; then
        echo -e "${CYAN}📋 RECENT AUTONOMOUS SYSTEM LOGS (last $lines lines):${NC}"
        echo ""
        tail -n "$lines" "$MASTER_LOG"
    else
        echo -e "${YELLOW}⚠️  No log file found${NC}"
    fi
}

# Emergency context save
emergency_context_save() {
    echo -e "${RED}🚨 Emergency context save...${NC}"
    
    if [[ -f "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-simplified-memory.sh" save "emergency_save" \
            "Emergency context save triggered" \
            "System emergency or manual trigger" \
            "Check system logs for details"
        
        echo -e "${GREEN}✅ Emergency context saved${NC}"
    else
        echo -e "${RED}❌ Emergency save failed - script not found${NC}"
    fi
}

# Help
show_help() {
    echo "Claude Autonomous System - Master daemon for workspace automation"
    echo ""
    echo "Usage: claude-autonomous-system [command] [options]"
    echo ""
    echo "Commands:"
    echo "  start                        Start autonomous system in background"
    echo "  stop                         Stop autonomous system gracefully"
    echo "  restart                      Restart autonomous system"
    echo "  status                       Show system and service status"
    echo "  logs [lines]                 Show recent logs (default: 20)"
    echo "  emergency-save               Force emergency context save"
    echo "  daemon                       Run daemon (internal use)"
    echo ""
    echo "Background Services:"
    echo "  • Context Monitor           Auto-save simplified memory every 5min"
    echo "  • Project Monitor           Auto-detect project changes every 30s"
    echo "  • Intelligence Extractor    Auto-extract insights every 15min"
    echo "  • Health Monitor            Check service health every 60s"
    echo ""
    echo "Examples:"
    echo "  claude-autonomous-system start"
    echo "  claude-autonomous-system status"
    echo "  claude-autonomous-system logs 50"
}

# Main logic
case "${1:-}" in
    "start")
        start_background_daemon
        ;;
    "stop")
        stop_autonomous_system
        ;;
    "restart")
        stop_autonomous_system
        sleep 2
        start_background_daemon
        ;;
    "status")
        show_system_status
        ;;
    "logs")
        show_logs "${2:-20}"
        ;;
    "emergency-save")
        emergency_context_save
        ;;
    "daemon")
        # Internal command for background daemon
        start_autonomous_daemon
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_system_status
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac