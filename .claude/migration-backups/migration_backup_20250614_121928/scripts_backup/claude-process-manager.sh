#!/bin/bash
# Claude Process Manager - Sistema centralizzato per gestione sicura processi
# Evita kill accidentali e implementa validazione robusta

WORKSPACE_DIR="$HOME/claude-workspace"
PROCESS_DIR="$WORKSPACE_DIR/.claude/processes"
PID_DIR="$PROCESS_DIR/pids"
WHITELIST_FILE="$PROCESS_DIR/safe-processes.whitelist"
LOG_FILE="$PROCESS_DIR/process-manager.log"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$PID_DIR"

# Log function
log_process() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
    
    if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo -e "${RED}[PROCESS-MANAGER]${NC} $message" >&2
    fi
}

# Initialize whitelist with safe processes
init_whitelist() {
    if [[ ! -f "$WHITELIST_FILE" ]]; then
        cat > "$WHITELIST_FILE" << 'EOF'
# Safe processes whitelist - NEVER kill these processes
# One process pattern per line, supports regex

# System processes
^systemd
^kernel
^init
^kthreadd

# Claude Code and related
^claude-code$
^claude$
^code
^/usr/bin/code
^/snap/code/

# SSH and network
^ssh
^sshd
^NetworkManager
^wpa_supplicant

# Desktop environment
^gnome-
^kde-
^xfce-
^X11
^Xorg
^wayland

# Shell and terminal
^bash$
^zsh$
^fish$
^sh$
^tmux
^screen
^terminal

# Package managers
^apt
^dpkg
^snap
^flatpak
^yum
^dnf

# Development tools (in case Claude is running inside them)
^docker
^containerd
^node
^npm
^yarn
^python3
^java
^mvn
^gradle

# Critical services
^dbus
^systemd-
^udev
^cron
^at
EOF
        log_process "INFO" "Initialized process whitelist"
    fi
}

# Check if process is in whitelist (should NOT be killed)
is_process_whitelisted() {
    local pid="$1"
    local process_cmd="$2"
    local process_args="$3"
    
    if [[ ! -f "$WHITELIST_FILE" ]]; then
        log_process "WARN" "Whitelist file not found, treating as whitelisted: $process_cmd"
        return 0  # Safe default: if no whitelist, don't kill
    fi
    
    # Check against whitelist patterns
    while IFS= read -r pattern; do
        # Skip comments and empty lines
        [[ "$pattern" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$pattern" ]] && continue
        
        # Check command against pattern
        if [[ "$process_cmd" =~ $pattern ]]; then
            log_process "INFO" "Process $pid ($process_cmd) matches whitelist pattern: $pattern"
            return 0  # Whitelisted
        fi
        
        # Check full command line against pattern
        if [[ "$process_args" =~ $pattern ]]; then
            log_process "INFO" "Process $pid ($process_args) matches whitelist pattern: $pattern"
            return 0  # Whitelisted
        fi
        
    done < "$WHITELIST_FILE"
    
    return 1  # Not whitelisted
}

# Enhanced process validation
validate_process() {
    local pid="$1"
    local expected_pattern="${2:-}"
    local require_ownership="${3:-true}"
    
    # Check if PID exists
    if ! kill -0 "$pid" 2>/dev/null; then
        log_process "WARN" "PID $pid not accessible or doesn't exist"
        return 1
    fi
    
    # Get process details
    local process_owner=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')
    local process_cmd=$(ps -o comm= -p "$pid" 2>/dev/null)
    local process_args=$(ps -o args= -p "$pid" 2>/dev/null)
    local current_uid=$(id -u)
    
    if [[ -z "$process_owner" || -z "$process_cmd" ]]; then
        log_process "WARN" "PID $pid: unable to get process details"
        return 1
    fi
    
    # Check process ownership
    if [[ "$require_ownership" == "true" && "$process_owner" != "$current_uid" ]]; then
        log_process "WARN" "PID $pid owned by different user (UID: $process_owner vs $current_uid)"
        return 1
    fi
    
    # Check against whitelist (safety check)
    if is_process_whitelisted "$pid" "$process_cmd" "$process_args"; then
        log_process "ERROR" "SAFETY: PID $pid ($process_cmd) is whitelisted and should NOT be killed!"
        return 1
    fi
    
    # Check expected pattern if provided
    if [[ -n "$expected_pattern" ]]; then
        if [[ ! "$process_cmd" =~ $expected_pattern ]] && [[ ! "$process_args" =~ $expected_pattern ]]; then
            log_process "WARN" "PID $pid doesn't match expected pattern '$expected_pattern': $process_cmd | $process_args"
            return 1
        fi
    fi
    
    log_process "INFO" "PID $pid validated: $process_cmd"
    return 0
}

# Register a process PID file
register_process() {
    local service_name="$1"
    local pid="$2"
    local description="${3:-No description}"
    
    if [[ -z "$service_name" || -z "$pid" ]]; then
        log_process "ERROR" "register_process: service_name and pid required"
        return 1
    fi
    
    local pid_file="$PID_DIR/$service_name.pid"
    local info_file="$PID_DIR/$service_name.info"
    
    # Atomic write
    echo "$pid" > "$pid_file.tmp"
    mv "$pid_file.tmp" "$pid_file"
    
    # Store additional info
    cat > "$info_file" << EOF
{
    "pid": $pid,
    "service": "$service_name",
    "description": "$description",
    "registered_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "registered_by": "$USER",
    "working_dir": "$PWD"
}
EOF
    
    log_process "INFO" "Registered process: $service_name (PID: $pid)"
}

# Unregister a process
unregister_process() {
    local service_name="$1"
    
    local pid_file="$PID_DIR/$service_name.pid"
    local info_file="$PID_DIR/$service_name.info"
    
    rm -f "$pid_file" "$info_file"
    log_process "INFO" "Unregistered process: $service_name"
}

# Get PID for a registered service
get_service_pid() {
    local service_name="$1"
    local pid_file="$PID_DIR/$service_name.pid"
    
    if [[ -f "$pid_file" ]]; then
        cat "$pid_file"
    else
        return 1
    fi
}

# Check if a registered service is running
is_service_running() {
    local service_name="$1"
    local pid_file="$PID_DIR/$service_name.pid"
    
    if [[ -f "$pid_file" ]]; then
        local pid=$(cat "$pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            return 0  # Running
        else
            # Clean up stale PID file
            unregister_process "$service_name"
            return 1  # Not running
        fi
    fi
    return 1  # Not registered
}

# Safe process termination with multiple validation layers
safe_terminate_process() {
    local pid="$1"
    local expected_pattern="${2:-}"
    local timeout="${3:-10}"
    local require_confirmation="${4:-false}"
    
    if [[ -z "$pid" ]]; then
        log_process "ERROR" "safe_terminate_process: PID required"
        return 1
    fi
    
    # Validation step 1: Basic process validation
    if ! validate_process "$pid" "$expected_pattern" "true"; then
        log_process "ERROR" "Process validation failed for PID $pid"
        return 1
    fi
    
    # Get process details for confirmation
    local process_cmd=$(ps -o comm= -p "$pid" 2>/dev/null)
    local process_args=$(ps -o args= -p "$pid" 2>/dev/null)
    
    # Confirmation prompt for dangerous operations
    if [[ "$require_confirmation" == "true" ]]; then
        echo -e "${YELLOW}⚠️  About to terminate process:${NC}"
        echo -e "   PID: $pid"
        echo -e "   Command: $process_cmd"
        echo -e "   Args: $process_args"
        echo ""
        echo -e "${RED}Are you sure? This action cannot be undone.${NC}"
        echo -n "Type 'yes' to confirm: "
        read -r confirmation
        
        if [[ "$confirmation" != "yes" ]]; then
            echo -e "${CYAN}Operation cancelled by user${NC}"
            return 1
        fi
    fi
    
    log_process "INFO" "Attempting safe termination of PID $pid ($process_cmd)"
    
    # Step 1: Graceful shutdown (SIGTERM)
    if kill -TERM "$pid" 2>/dev/null; then
        echo -e "${YELLOW}⏳ Waiting for graceful shutdown...${NC}"
        
        local count=0
        while [[ $count -lt $timeout ]] && kill -0 "$pid" 2>/dev/null; do
            printf "."
            sleep 1
            ((count++))
        done
        echo ""
        
        # Check if process terminated gracefully
        if ! kill -0 "$pid" 2>/dev/null; then
            log_process "INFO" "Process $pid terminated gracefully"
            echo -e "${GREEN}✅ Process terminated gracefully${NC}"
            return 0
        fi
        
        # Step 2: Force termination (SIGKILL) with additional validation
        echo -e "${RED}⚠️  Process still running after $timeout seconds${NC}"
        echo -e "${RED}Attempting force termination...${NC}"
        
        # Re-validate before force kill (extra safety)
        if ! validate_process "$pid" "$expected_pattern" "true"; then
            log_process "ERROR" "Re-validation failed before force kill - ABORTING"
            return 1
        fi
        
        if kill -KILL "$pid" 2>/dev/null; then
            sleep 1
            if ! kill -0 "$pid" 2>/dev/null; then
                log_process "WARN" "Process $pid force terminated"
                echo -e "${YELLOW}⚠️  Process force terminated${NC}"
                return 0
            else
                log_process "ERROR" "Failed to force terminate PID $pid"
                echo -e "${RED}❌ Failed to terminate process${NC}"
                return 1
            fi
        else
            log_process "ERROR" "Failed to send SIGKILL to PID $pid"
            echo -e "${RED}❌ Failed to send kill signal${NC}"
            return 1
        fi
    else
        log_process "ERROR" "Failed to send SIGTERM to PID $pid"
        echo -e "${RED}❌ Failed to send termination signal${NC}"
        return 1
    fi
}

# Safe service termination
safe_terminate_service() {
    local service_name="$1"
    local timeout="${2:-10}"
    local require_confirmation="${3:-false}"
    
    if ! is_service_running "$service_name"; then
        echo -e "${YELLOW}⚠️  Service '$service_name' is not running${NC}"
        return 1
    fi
    
    local pid=$(get_service_pid "$service_name")
    
    # For registered services, we expect them to match the service name pattern
    local expected_pattern="$service_name"
    
    if safe_terminate_process "$pid" "$expected_pattern" "$timeout" "$require_confirmation"; then
        unregister_process "$service_name"
        echo -e "${GREEN}✅ Service '$service_name' terminated successfully${NC}"
        return 0
    else
        echo -e "${RED}❌ Failed to terminate service '$service_name'${NC}"
        return 1
    fi
}

# Find processes matching pattern with safety checks
safe_find_processes() {
    local pattern="$1"
    local exclude_whitelisted="${2:-true}"
    
    if [[ -z "$pattern" ]]; then
        log_process "ERROR" "safe_find_processes: pattern required"
        return 1
    fi
    
    # Use multiple methods to find processes
    local pids=()
    
    # Method 1: pgrep with exact match
    mapfile -t exact_pids < <(pgrep -x "$pattern" 2>/dev/null)
    pids+=("${exact_pids[@]}")
    
    # Method 2: pgrep with partial match
    mapfile -t partial_pids < <(pgrep "$pattern" 2>/dev/null)
    pids+=("${partial_pids[@]}")
    
    # Method 3: pgrep with full command line
    mapfile -t full_pids < <(pgrep -f "$pattern" 2>/dev/null)
    pids+=("${full_pids[@]}")
    
    # Remove duplicates and validate
    local unique_pids=($(printf '%s\n' "${pids[@]}" | sort -u))
    local valid_pids=()
    
    for pid in "${unique_pids[@]}"; do
        if [[ -n "$pid" ]] && validate_process "$pid" "$pattern" "true"; then
            # Check whitelist if requested
            if [[ "$exclude_whitelisted" == "true" ]]; then
                local process_cmd=$(ps -o comm= -p "$pid" 2>/dev/null)
                local process_args=$(ps -o args= -p "$pid" 2>/dev/null)
                
                if is_process_whitelisted "$pid" "$process_cmd" "$process_args"; then
                    log_process "INFO" "Excluding whitelisted process: $pid ($process_cmd)"
                    continue
                fi
            fi
            
            valid_pids+=("$pid")
        fi
    done
    
    # Output results
    for pid in "${valid_pids[@]}"; do
        echo "$pid"
    done
    
    log_process "INFO" "Found ${#valid_pids[@]} valid processes for pattern '$pattern'"
}

# List all registered services
list_services() {
    echo -e "${CYAN}📋 REGISTERED SERVICES${NC}"
    echo ""
    
    if [[ ! -d "$PID_DIR" ]] || [[ -z "$(ls -A "$PID_DIR" 2>/dev/null)" ]]; then
        echo "No registered services"
        return 0
    fi
    
    for pid_file in "$PID_DIR"/*.pid; do
        [[ ! -f "$pid_file" ]] && continue
        
        local service_name=$(basename "$pid_file" .pid)
        local info_file="$PID_DIR/$service_name.info"
        
        if is_service_running "$service_name"; then
            local pid=$(cat "$pid_file")
            local process_cmd=$(ps -o comm= -p "$pid" 2>/dev/null)
            echo -e "${GREEN}✅ $service_name${NC} (PID: $pid, CMD: $process_cmd)"
            
            # Show additional info if available
            if [[ -f "$info_file" ]]; then
                local description=$(python3 -c "import json; print(json.load(open('$info_file')).get('description', ''))" 2>/dev/null)
                [[ -n "$description" ]] && echo -e "   📄 $description"
            fi
        else
            echo -e "${RED}❌ $service_name${NC} (not running)"
        fi
    done
}

# Emergency stop all registered services
emergency_stop_all() {
    echo -e "${RED}🚨 EMERGENCY STOP - Terminating all registered services${NC}"
    echo ""
    
    local services_stopped=0
    local services_failed=0
    
    for pid_file in "$PID_DIR"/*.pid; do
        [[ ! -f "$pid_file" ]] && continue
        
        local service_name=$(basename "$pid_file" .pid)
        
        if is_service_running "$service_name"; then
            echo -e "${YELLOW}🛑 Stopping $service_name...${NC}"
            if safe_terminate_service "$service_name" 5 "false"; then
                ((services_stopped++))
            else
                ((services_failed++))
            fi
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ Services stopped: $services_stopped${NC}"
    if [[ $services_failed -gt 0 ]]; then
        echo -e "${RED}❌ Services failed: $services_failed${NC}"
    fi
    
    log_process "WARN" "Emergency stop completed: $services_stopped stopped, $services_failed failed"
}

# Clean up stale PID files
cleanup_stale_pids() {
    echo -e "${CYAN}🧹 Cleaning up stale PID files...${NC}"
    
    local cleaned=0
    
    for pid_file in "$PID_DIR"/*.pid; do
        [[ ! -f "$pid_file" ]] && continue
        
        local service_name=$(basename "$pid_file" .pid)
        
        if ! is_service_running "$service_name"; then
            echo -e "${YELLOW}🗑️  Removing stale entry: $service_name${NC}"
            unregister_process "$service_name"
            ((cleaned++))
        fi
    done
    
    echo -e "${GREEN}✅ Cleaned up $cleaned stale entries${NC}"
}

# Show help
show_help() {
    echo "Claude Process Manager - Safe process management system"
    echo ""
    echo "Usage: claude-process-manager [command] [options]"
    echo ""
    echo "Service Management:"
    echo "  register <name> <pid> [description]    Register a process as a service"
    echo "  unregister <name>                      Unregister a service"
    echo "  list                                   List all registered services"
    echo "  is-running <name>                      Check if service is running"
    echo "  get-pid <name>                         Get PID of registered service"
    echo ""
    echo "Safe Termination:"
    echo "  kill-service <name> [timeout]          Safely terminate a registered service"
    echo "  kill-pid <pid> [pattern] [timeout]     Safely terminate a process by PID"
    echo "  find-processes <pattern>               Find processes matching pattern"
    echo "  emergency-stop                         Stop all registered services"
    echo ""
    echo "Maintenance:"
    echo "  cleanup                                Clean up stale PID files"
    echo "  init-whitelist                         Initialize process whitelist"
    echo "  validate-pid <pid> [pattern]           Validate a process"
    echo ""
    echo "Safety Features:"
    echo "  • Process ownership validation"
    echo "  • Whitelist protection for critical processes"
    echo "  • Multiple validation layers"
    echo "  • Graceful termination with fallback to force"
    echo "  • Comprehensive logging"
    echo ""
    echo "Examples:"
    echo "  claude-process-manager register sync-daemon 1234 'Background sync'"
    echo "  claude-process-manager kill-service sync-daemon"
    echo "  claude-process-manager find-processes claude"
}

# Initialize whitelist on first run
init_whitelist

# Main command dispatcher
case "${1:-}" in
    "register")
        if [[ -n "$2" && -n "$3" ]]; then
            register_process "$2" "$3" "${4:-}"
        else
            echo -e "${RED}Usage: register <name> <pid> [description]${NC}"
            exit 1
        fi
        ;;
    "unregister")
        if [[ -n "$2" ]]; then
            unregister_process "$2"
        else
            echo -e "${RED}Usage: unregister <name>${NC}"
            exit 1
        fi
        ;;
    "list")
        list_services
        ;;
    "is-running")
        if [[ -n "$2" ]]; then
            if is_service_running "$2"; then
                echo "yes"
                exit 0
            else
                echo "no"
                exit 1
            fi
        else
            echo -e "${RED}Usage: is-running <name>${NC}"
            exit 1
        fi
        ;;
    "get-pid")
        if [[ -n "$2" ]]; then
            if pid=$(get_service_pid "$2"); then
                echo "$pid"
            else
                exit 1
            fi
        else
            echo -e "${RED}Usage: get-pid <name>${NC}"
            exit 1
        fi
        ;;
    "kill-service")
        if [[ -n "$2" ]]; then
            safe_terminate_service "$2" "${3:-10}" "false"
        else
            echo -e "${RED}Usage: kill-service <name> [timeout]${NC}"
            exit 1
        fi
        ;;
    "kill-pid")
        if [[ -n "$2" ]]; then
            safe_terminate_process "$2" "${3:-}" "${4:-10}" "false"
        else
            echo -e "${RED}Usage: kill-pid <pid> [pattern] [timeout]${NC}"
            exit 1
        fi
        ;;
    "find-processes")
        if [[ -n "$2" ]]; then
            safe_find_processes "$2" "true"
        else
            echo -e "${RED}Usage: find-processes <pattern>${NC}"
            exit 1
        fi
        ;;
    "emergency-stop")
        emergency_stop_all
        ;;
    "cleanup")
        cleanup_stale_pids
        ;;
    "init-whitelist")
        rm -f "$WHITELIST_FILE"
        init_whitelist
        echo -e "${GREEN}✅ Whitelist initialized${NC}"
        ;;
    "validate-pid")
        if [[ -n "$2" ]]; then
            if validate_process "$2" "${3:-}"; then
                echo -e "${GREEN}✅ Process $2 is valid${NC}"
            else
                echo -e "${RED}❌ Process $2 validation failed${NC}"
                exit 1
            fi
        else
            echo -e "${RED}Usage: validate-pid <pid> [pattern]${NC}"
            exit 1
        fi
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