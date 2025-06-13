#!/bin/bash
# Claude Safe Process - Wrapper per operazioni sicure sui processi
# Fornisce API semplificata per il process manager

WORKSPACE_DIR="$HOME/claude-workspace"
PROCESS_MANAGER="$WORKSPACE_DIR/scripts/claude-process-manager.sh"

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if process manager is available
check_process_manager() {
    if [[ ! -f "$PROCESS_MANAGER" ]]; then
        echo -e "${RED}❌ Process manager not found at: $PROCESS_MANAGER${NC}" >&2
        return 1
    fi
    return 0
}

# Safe kill by PID with pattern validation
safe_kill_pid() {
    local pid="$1"
    local pattern="${2:-}"
    local timeout="${3:-10}"
    
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: safe_kill_pid <pid> [pattern] [timeout]${NC}" >&2
        return 1
    fi
    
    if ! check_process_manager; then
        return 1
    fi
    
    "$PROCESS_MANAGER" kill-pid "$pid" "$pattern" "$timeout"
}

# Safe kill by process name/pattern
safe_kill_pattern() {
    local pattern="$1"
    local timeout="${2:-10}"
    
    if [[ -z "$pattern" ]]; then
        echo -e "${RED}Usage: safe_kill_pattern <pattern> [timeout]${NC}" >&2
        return 1
    fi
    
    if ! check_process_manager; then
        return 1
    fi
    
    echo -e "${CYAN}🔍 Finding processes matching: $pattern${NC}"
    local pids
    mapfile -t pids < <("$PROCESS_MANAGER" find-processes "$pattern" 2>/dev/null)
    
    if [[ ${#pids[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No processes found matching: $pattern${NC}"
        return 0
    fi
    
    echo -e "${GREEN}Found ${#pids[@]} process(es) to terminate${NC}"
    
    local success=0
    local failed=0
    
    for pid in "${pids[@]}"; do
        if "$PROCESS_MANAGER" kill-pid "$pid" "$pattern" "$timeout"; then
            ((success++))
        else
            ((failed++))
        fi
    done
    
    echo -e "${GREEN}✅ Terminated: $success, Failed: $failed${NC}"
    return $([[ $failed -eq 0 ]])
}

# Safe pgrep replacement - find processes but don't kill
safe_find() {
    local pattern="$1"
    
    if [[ -z "$pattern" ]]; then
        echo -e "${RED}Usage: safe_find <pattern>${NC}" >&2
        return 1
    fi
    
    if ! check_process_manager; then
        return 1
    fi
    
    "$PROCESS_MANAGER" find-processes "$pattern"
}

# Register a service
register_service() {
    local name="$1"
    local pid="$2"
    local description="${3:-}"
    
    if [[ -z "$name" || -z "$pid" ]]; then
        echo -e "${RED}Usage: register_service <name> <pid> [description]${NC}" >&2
        return 1
    fi
    
    if ! check_process_manager; then
        return 1
    fi
    
    "$PROCESS_MANAGER" register "$name" "$pid" "$description"
}

# Kill a registered service
kill_service() {
    local name="$1"
    local timeout="${2:-10}"
    
    if [[ -z "$name" ]]; then
        echo -e "${RED}Usage: kill_service <name> [timeout]${NC}" >&2
        return 1
    fi
    
    if ! check_process_manager; then
        return 1
    fi
    
    "$PROCESS_MANAGER" kill-service "$name" "$timeout"
}

# Check if a process is safe to kill (not whitelisted)
is_safe_to_kill() {
    local pid="$1"
    local pattern="${2:-}"
    
    if [[ -z "$pid" ]]; then
        echo -e "${RED}Usage: is_safe_to_kill <pid> [pattern]${NC}" >&2
        return 1
    fi
    
    if ! check_process_manager; then
        return 1
    fi
    
    "$PROCESS_MANAGER" validate-pid "$pid" "$pattern" >/dev/null 2>&1
}

# List all registered services
list_services() {
    if ! check_process_manager; then
        return 1
    fi
    
    "$PROCESS_MANAGER" list
}

# Emergency stop all registered services
emergency_stop() {
    if ! check_process_manager; then
        return 1
    fi
    
    echo -e "${RED}🚨 EMERGENCY STOP${NC}"
    "$PROCESS_MANAGER" emergency-stop
}

# Cleanup stale PID files
cleanup() {
    if ! check_process_manager; then
        return 1
    fi
    
    "$PROCESS_MANAGER" cleanup
}

# Show help
show_help() {
    echo "Claude Safe Process - Wrapper for safe process management"
    echo ""
    echo "Usage: claude-safe-process [command] [options]"
    echo ""
    echo "Process Operations:"
    echo "  kill-pid <pid> [pattern] [timeout]     Safely kill process by PID"
    echo "  kill-pattern <pattern> [timeout]       Kill all processes matching pattern"
    echo "  find <pattern>                         Find processes (safe pgrep replacement)"
    echo "  is-safe <pid> [pattern]                Check if process is safe to kill"
    echo ""
    echo "Service Management:"
    echo "  register <name> <pid> [description]    Register a service"
    echo "  kill-service <name> [timeout]          Kill registered service"
    echo "  list                                   List registered services"
    echo ""
    echo "Emergency Operations:"
    echo "  emergency-stop                         Stop all registered services"
    echo "  cleanup                                Clean up stale PID files"
    echo ""
    echo "Safety Features:"
    echo "  • Automatic process ownership validation"
    echo "  • Whitelist protection for critical processes"
    echo "  • Graceful termination with fallback"
    echo "  • Comprehensive logging"
    echo ""
    echo "Examples:"
    echo "  claude-safe-process kill-pattern \"claude-sync\" 5"
    echo "  claude-safe-process find \"python.*script\""
    echo "  claude-safe-process register my-daemon 1234 \"My background daemon\""
    echo "  claude-safe-process kill-service my-daemon"
}

# Main command dispatcher
case "${1:-}" in
    "kill-pid")
        safe_kill_pid "$2" "$3" "$4"
        ;;
    "kill-pattern")
        safe_kill_pattern "$2" "$3"
        ;;
    "find")
        safe_find "$2"
        ;;
    "is-safe")
        is_safe_to_kill "$2" "$3"
        ;;
    "register")
        register_service "$2" "$3" "$4"
        ;;
    "kill-service")
        kill_service "$2" "$3"
        ;;
    "list")
        list_services
        ;;
    "emergency-stop")
        emergency_stop
        ;;
    "cleanup")
        cleanup
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