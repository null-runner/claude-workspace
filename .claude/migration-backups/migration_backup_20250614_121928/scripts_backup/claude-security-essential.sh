#!/bin/bash

# Claude Security Essential - Practical security without enterprise theater
# Focus: Process protection, safe execution, NO file locking overkill

# Logging & Error Handling
SCRIPT_NAME="claude-security-essential"
LOG_FILE="${CLAUDE_HOME}/.claude/logs/security.log"
ERROR_FILE="${CLAUDE_HOME}/.claude/logs/error.log"

# Colors for better UX
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Basic logging function
log() {
    local message="$1"
    local level="${2:-INFO}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] [$SCRIPT_NAME] $message" | tee -a "$LOG_FILE"
}

error_log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [ERROR] [$SCRIPT_NAME] $message" | tee -a "$ERROR_FILE"
    echo -e "${RED}[ERROR]${NC} $message" >&2
}

success_log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [SUCCESS] [$SCRIPT_NAME] $message" | tee -a "$LOG_FILE"
    echo -e "${GREEN}[SUCCESS]${NC} $message"
}

warn_log() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [WARN] [$SCRIPT_NAME] $message" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}[WARN]${NC} $message"
}

# Process protection - simple whitelist approach
PROTECTED_PROCESSES=(
    "claude-autonomous-system"
    "claude-smart-sync"
    "claude-startup"
    "claude-exit-hook"
    "claude-simplified-memory"
    "claude-intelligent-auto-sync"
    "ssh-agent"
    "systemd"
    "init"
)

# Check if a process should be protected
is_protected_process() {
    local proc_name="$1"
    
    for protected in "${PROTECTED_PROCESSES[@]}"; do
        if [[ "$proc_name" == *"$protected"* ]]; then
            return 0
        fi
    done
    return 1
}

# Safe process termination with whitelist protection
safe_terminate() {
    local pid="$1"
    local signal="${2:-TERM}"
    local timeout="${3:-10}"
    
    if [[ ! "$pid" =~ ^[0-9]+$ ]]; then
        error_log "Invalid PID: $pid"
        return 1
    fi
    
    # Get process info
    local proc_info=$(ps -p "$pid" -o comm= 2>/dev/null)
    if [[ -z "$proc_info" ]]; then
        warn_log "Process $pid not found (already terminated?)"
        return 0
    fi
    
    # Check if process is protected
    if is_protected_process "$proc_info"; then
        warn_log "Process $pid ($proc_info) is protected - not terminating"
        return 1
    fi
    
    log "Terminating process $pid ($proc_info) with signal $signal"
    
    # Send signal
    if kill -"$signal" "$pid" 2>/dev/null; then
        log "Signal $signal sent to process $pid"
    else
        error_log "Failed to send signal $signal to process $pid"
        return 1
    fi
    
    # Wait for termination with timeout
    local count=0
    while [[ $count -lt $timeout ]] && kill -0 "$pid" 2>/dev/null; do
        sleep 1
        ((count++))
    done
    
    if kill -0 "$pid" 2>/dev/null; then
        warn_log "Process $pid didn't terminate after ${timeout}s, sending KILL"
        kill -KILL "$pid" 2>/dev/null
        sleep 1
        if kill -0 "$pid" 2>/dev/null; then
            error_log "Failed to terminate process $pid"
            return 1
        fi
    fi
    
    success_log "Process $pid terminated successfully"
    return 0
}

# Safe script execution with timeout
safe_execute() {
    local script="$1"
    local timeout="${2:-30}"
    local args=("${@:3}")
    
    if [[ ! -f "$script" ]]; then
        error_log "Script not found: $script"
        return 1
    fi
    
    if [[ ! -x "$script" ]]; then
        error_log "Script not executable: $script"
        return 1
    fi
    
    log "Executing script: $script with timeout ${timeout}s"
    
    # Execute with timeout
    timeout "$timeout" "$script" "${args[@]}" 2>&1
    local exit_code=$?
    
    case $exit_code in
        0)
            success_log "Script executed successfully: $script"
            ;;
        124)
            error_log "Script timed out after ${timeout}s: $script"
            ;;
        *)
            error_log "Script failed with exit code $exit_code: $script"
            ;;
    esac
    
    return $exit_code
}

# Basic file validation (NO complex locking)
validate_file() {
    local file="$1"
    local max_size="${2:-10485760}" # 10MB default
    
    if [[ ! -f "$file" ]]; then
        error_log "File not found: $file"
        return 1
    fi
    
    # Size check
    local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
    if [[ $size -gt $max_size ]]; then
        warn_log "File $file is large ($size bytes), may be corrupted"
        return 1
    fi
    
    # Basic permissions check
    if [[ ! -r "$file" ]]; then
        error_log "File not readable: $file"
        return 1
    fi
    
    return 0
}

# Environment sanitization
sanitize_environment() {
    local temp_dirs=("/tmp/claude-*" "/var/tmp/claude-*")
    local cleaned=0
    
    log "Sanitizing environment..."
    
    for pattern in "${temp_dirs[@]}"; do
        for dir in $pattern; do
            if [[ -d "$dir" ]]; then
                local age=$(find "$dir" -maxdepth 0 -mtime +1 2>/dev/null)
                if [[ -n "$age" ]]; then
                    log "Removing old temp directory: $dir"
                    rm -rf "$dir" 2>/dev/null && ((cleaned++))
                fi
            fi
        done
    done
    
    if [[ $cleaned -gt 0 ]]; then
        success_log "Cleaned $cleaned temporary directories"
    else
        log "No cleanup needed"
    fi
    
    return 0
}

# Process monitoring (basic)
monitor_processes() {
    local check_interval="${1:-30}"
    
    log "Starting basic process monitoring (interval: ${check_interval}s)"
    
    while true; do
        # Check for zombie processes
        local zombies=$(ps aux | grep -c '<defunct>' || echo 0)
        if [[ $zombies -gt 0 ]]; then
            warn_log "Found $zombies zombie processes"
        fi
        
        # Check memory usage of Claude processes
        local claude_procs=$(pgrep -f "claude-" | wc -l)
        if [[ $claude_procs -gt 10 ]]; then
            warn_log "High number of Claude processes: $claude_procs"
        fi
        
        sleep "$check_interval"
    done
}

# Show security status
show_status() {
    echo -e "${BLUE}🛡️  Claude Security Essential Status${NC}"
    echo "=================================="
    
    # Protected processes
    echo -e "\n${YELLOW}Protected Processes:${NC}"
    local running_protected=0
    for proc in "${PROTECTED_PROCESSES[@]}"; do
        if pgrep -f "$proc" >/dev/null 2>&1; then
            echo -e "  ✅ $proc (running)"
            ((running_protected++))
        else
            echo -e "  ❌ $proc (not running)"
        fi
    done
    
    echo -e "\n${YELLOW}Summary:${NC}"
    echo "  • Protected processes running: $running_protected/${#PROTECTED_PROCESSES[@]}"
    echo "  • Total Claude processes: $(pgrep -f 'claude-' | wc -l)"
    echo "  • Log file: $LOG_FILE"
    
    # Check temp directories
    local temp_count=$(find /tmp /var/tmp -name "claude-*" -type d 2>/dev/null | wc -l)
    echo "  • Temporary directories: $temp_count"
    
    echo -e "\n${GREEN}✅ Security essentials active - no enterprise theater${NC}"
}

# Main command handling
case "${1:-}" in
    "terminate")
        if [[ -z "$2" ]]; then
            error_log "Usage: $0 terminate <pid> [signal] [timeout]"
            exit 1
        fi
        safe_terminate "$2" "${3:-TERM}" "${4:-10}"
        ;;
    "execute")
        if [[ -z "$2" ]]; then
            error_log "Usage: $0 execute <script> [timeout] [args...]"
            exit 1
        fi
        safe_execute "$2" "${3:-30}" "${@:4}"
        ;;
    "validate")
        if [[ -z "$2" ]]; then
            error_log "Usage: $0 validate <file> [max_size]"
            exit 1
        fi
        validate_file "$2" "$3"
        ;;
    "sanitize")
        sanitize_environment
        ;;
    "monitor")
        monitor_processes "${2:-30}"
        ;;
    "status")
        show_status
        ;;
    *)
        echo "Claude Security Essential - Practical security without enterprise theater"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  terminate <pid> [signal] [timeout]  - Safely terminate process (with whitelist)"
        echo "  execute <script> [timeout] [args]   - Execute script with timeout protection"
        echo "  validate <file> [max_size]          - Basic file validation"
        echo "  sanitize                            - Clean temp directories"
        echo "  monitor [interval]                  - Basic process monitoring"
        echo "  status                              - Show security status"
        echo ""
        echo "Focus: Process protection, safe execution, NO file locking overkill"
        ;;
esac