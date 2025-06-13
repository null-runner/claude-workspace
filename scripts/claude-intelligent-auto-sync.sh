#!/bin/bash
# Claude Workspace - Intelligent Auto-Sync with Smart Filtering
# Combines smart filtering with robust sync operations
# Prevents autonomous loops while enabling instant user file sync

WORKSPACE_DIR="$HOME/claude-workspace"
SYNC_LOG="$WORKSPACE_DIR/logs/intelligent-sync.log"
FILTER_SCRIPT="$WORKSPACE_DIR/scripts/claude-smart-sync-filter.sh"
SYNC_SCRIPT="$WORKSPACE_DIR/scripts/claude-robust-sync.sh"
LOCK_SCRIPT="$WORKSPACE_DIR/scripts/claude-sync-lock.sh"

# Configuration
IMMEDIATE_SYNC_PATTERNS=(
    "scripts/.*\.sh"
    "docs/.*\.md"
    "projects/.*"
    "CLAUDE\.md"
    "README\.md"
)

BATCH_SYNC_INTERVAL=300  # 5 minutes for batch sync
USER_PRIORITY_DELAY=2    # 2 seconds for user files
SYSTEM_BATCH_DELAY=300   # 5 minutes for system files

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Setup
mkdir -p "$(dirname "$SYNC_LOG")"
touch "$SYNC_LOG"

# Source shared locking mechanism
if [[ -f "$LOCK_SCRIPT" ]]; then
    source "$LOCK_SCRIPT"
else
    log_sync "ERROR" "Sync lock script not found: $LOCK_SCRIPT"
    exit 1
fi

# Logging
log_sync() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    echo "[$timestamp] [$level] $message" >> "$SYNC_LOG"
    
    case "$level" in
        "SYNC") echo -e "${GREEN}[SYNC]${NC} $message" ;;
        "SKIP") echo -e "${YELLOW}[SKIP]${NC} $message" ;;
        "ERROR") echo -e "${RED}[ERROR]${NC} $message" ;;
        "INFO") echo -e "${BLUE}[INFO]${NC} $message" ;;
    esac
}

# Check if file is high priority for immediate sync
is_high_priority() {
    local file="$1"
    local relative_path="${file#$WORKSPACE_DIR/}"
    
    for pattern in "${IMMEDIATE_SYNC_PATTERNS[@]}"; do
        if [[ "$relative_path" =~ $pattern ]]; then
            return 0
        fi
    done
    return 1
}

# Execute sync with proper coordination
execute_sync() {
    local sync_type="$1"
    local files_info="$2"
    
    log_sync "SYNC" "Starting $sync_type sync: $files_info"
    
    # Coordinate with memory system before sync
    local memory_coordinator="$WORKSPACE_DIR/scripts/claude-memory-coordinator.sh"
    if [[ -x "$memory_coordinator" ]]; then
        # Request coordinated auto-save before sync
        "$memory_coordinator" save auto "pre-sync-auto-save" >/dev/null 2>&1
    fi
    
    # Use sync coordinator for all sync operations to prevent conflicts
    local coordinator_script="$WORKSPACE_DIR/scripts/claude-sync-coordinator.sh"
    
    if [[ -x "$coordinator_script" ]]; then
        # Request coordinated sync through the coordinator
        if "$coordinator_script" request-sync intelligent-auto "intelligent-auto-sync" "normal" "Auto-sync: $files_info"; then
            log_sync "SYNC" "$sync_type sync completed successfully"
            return 0
        else
            log_sync "ERROR" "$sync_type sync failed"
            return 1
        fi
    else
        # Fallback to robust sync if coordinator not available
        log_sync "WARN" "Sync coordinator not available, falling back to robust sync"
        if "$SYNC_SCRIPT" sync; then
            log_sync "SYNC" "$sync_type sync completed successfully (fallback)"
            return 0
        else
            log_sync "ERROR" "$sync_type sync failed (fallback)"
            return 1
        fi
    fi
}

# Process filtered files from smart filter
process_filtered_files() {
    local sync_files=()
    local high_priority_files=()
    local batch_files=()
    
    while IFS= read -r line; do
        if [[ "$line" =~ ^SYNC: ]]; then
            # Extract files from SYNC: output
            local files_list="${line#SYNC:}"
            IFS=' ' read -ra files <<< "$files_list"
            
            for file in "${files[@]}"; do
                if [[ -f "$file" ]]; then
                    sync_files+=("$file")
                    
                    if is_high_priority "$file"; then
                        high_priority_files+=("$file")
                    else
                        batch_files+=("$file")
                    fi
                fi
            done
            
            # Process high priority files immediately
            if [[ ${#high_priority_files[@]} -gt 0 ]]; then
                log_sync "INFO" "Processing ${#high_priority_files[@]} high-priority files"
                sleep "$USER_PRIORITY_DELAY"
                execute_sync "immediate" "${#high_priority_files[@]} files"
                high_priority_files=()
            fi
            
            # Batch process lower priority files
            if [[ ${#batch_files[@]} -gt 5 ]]; then  # Batch threshold
                log_sync "INFO" "Processing batch of ${#batch_files[@]} files"
                execute_sync "batch" "${#batch_files[@]} files"
                batch_files=()
            fi
        fi
        
        # Handle blocked files (log for debugging)
        if [[ "$line" =~ ^BLOCK: ]]; then
            local blocked_files="${line#BLOCK:}"
            local blocked_count=$(echo "$blocked_files" | wc -w)
            log_sync "SKIP" "Blocked $blocked_count system files from sync"
        fi
        
    done
    
    # Process any remaining batch files
    if [[ ${#batch_files[@]} -gt 0 ]]; then
        log_sync "INFO" "Processing final batch of ${#batch_files[@]} files"
        execute_sync "batch" "${#batch_files[@]} files"
    fi
}

# Periodic batch sync for any missed files
periodic_batch_sync() {
    while true; do
        sleep "$BATCH_SYNC_INTERVAL"
        
        log_sync "INFO" "Running periodic batch sync check"
        
        # Check if there are any unsynced changes
        cd "$WORKSPACE_DIR"
        local changes=$(git status --porcelain | wc -l)
        
        if [[ $changes -gt 0 ]]; then
            log_sync "INFO" "Found $changes unsynced changes, running batch sync"
            execute_sync "periodic" "$changes changes"
        else
            log_sync "INFO" "No unsynced changes found"
        fi
    done
}

# Health monitoring
monitor_sync_health() {
    local last_sync_file="$WORKSPACE_DIR/.claude/sync/last_sync"
    local health_check_interval=300  # 5 minutes
    
    while true; do
        sleep "$health_check_interval"
        
        # Check if sync is working
        if [[ -f "$last_sync_file" ]]; then
            local last_sync=$(cat "$last_sync_file")
            local now=$(date +%s)
            local time_since_sync=$((now - last_sync))
            
            if [[ $time_since_sync -gt 1800 ]]; then  # 30 minutes
                log_sync "ERROR" "No sync activity for ${time_since_sync}s, potential issue"
            fi
        fi
        
        # Check filter process health
        if ! pgrep -f "claude-smart-sync-filter.sh" >/dev/null; then
            log_sync "ERROR" "Smart filter process not running"
        fi
    done
}

# Main intelligent sync daemon
start_intelligent_sync() {
    log_sync "INFO" "Starting intelligent auto-sync daemon (PID: $$)"
    
    # Verify dependencies
    if [[ ! -x "$FILTER_SCRIPT" ]]; then
        log_sync "ERROR" "Smart filter script not found or not executable: $FILTER_SCRIPT"
        exit 1
    fi
    
    if [[ ! -x "$SYNC_SCRIPT" ]]; then
        log_sync "ERROR" "Robust sync script not found or not executable: $SYNC_SCRIPT"
        exit 1
    fi
    
    if [[ ! -x "$LOCK_SCRIPT" ]]; then
        log_sync "ERROR" "Sync lock script not found or not executable: $LOCK_SCRIPT"
        exit 1
    fi
    
    # Start background processes
    periodic_batch_sync &
    local batch_sync_pid=$!
    
    monitor_sync_health &
    local health_monitor_pid=$!
    
    # Cleanup function
    cleanup() {
        log_sync "INFO" "Shutting down intelligent sync daemon"
        kill $batch_sync_pid $health_monitor_pid 2>/dev/null
        # Don't release lock here as we don't hold it in this daemon
        # Individual sync operations handle their own locking
        exit 0
    }
    trap cleanup SIGINT SIGTERM EXIT
    
    # Start smart filter and process its output
    log_sync "INFO" "Starting smart filter monitoring"
    "$FILTER_SCRIPT" monitor | process_filtered_files
}

# Testing mode
test_intelligent_sync() {
    echo -e "${BLUE}Testing Intelligent Auto-Sync System${NC}"
    
    # Test smart filter
    echo "Testing smart filter..."
    if "$FILTER_SCRIPT" test; then
        echo -e "${GREEN}✓ Smart filter working${NC}"
    else
        echo -e "${RED}✗ Smart filter failed${NC}"
        return 1
    fi
    
    # Test robust sync
    echo "Testing robust sync..."
    if "$SYNC_SCRIPT" test; then
        echo -e "${GREEN}✓ Robust sync working${NC}"
    else
        echo -e "${RED}✗ Robust sync failed${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✓ All components working correctly${NC}"
}

# Status display
show_status() {
    echo -e "${BLUE}Intelligent Auto-Sync Status${NC}"
    echo
    
    # Process status
    echo "Process Status:"
    if pgrep -f "claude-intelligent-auto-sync.sh" >/dev/null; then
        echo -e "  Main daemon: ${GREEN}RUNNING${NC}"
    else
        echo -e "  Main daemon: ${RED}STOPPED${NC}"
    fi
    
    if pgrep -f "claude-smart-sync-filter.sh" >/dev/null; then
        echo -e "  Smart filter: ${GREEN}RUNNING${NC}"
    else
        echo -e "  Smart filter: ${RED}STOPPED${NC}"
    fi
    
    echo
    
    # Component status
    "$FILTER_SCRIPT" status
    echo
    "$SYNC_SCRIPT" status
    
    echo
    echo "Recent sync activity:"
    if [[ -f "$SYNC_LOG" ]]; then
        tail -10 "$SYNC_LOG" | while read -r line; do
            if [[ "$line" =~ \[SYNC\] ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" =~ \[ERROR\] ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" =~ \[SKIP\] ]]; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "$line"
            fi
        done
    else
        echo "No sync log found"
    fi
}

# Performance benchmark
benchmark_performance() {
    echo -e "${BLUE}Running Intelligent Sync Performance Benchmark${NC}"
    
    local test_files=(
        "$WORKSPACE_DIR/test-user-file.md"
        "$WORKSPACE_DIR/.claude/autonomous/test-system-file.json"
        "$WORKSPACE_DIR/scripts/test-script.sh"
    )
    
    # Create test files
    for file in "${test_files[@]}"; do
        mkdir -p "$(dirname "$file")"
        echo "Test content $(date)" > "$file"
    done
    
    # Measure filter performance
    local start_time=$(date +%s.%N)
    
    for file in "${test_files[@]}"; do
        "$FILTER_SCRIPT" test >/dev/null 2>&1
    done
    
    local end_time=$(date +%s.%N)
    local filter_time=$(echo "$end_time - $start_time" | bc -l)
    
    echo "Filter performance: ${filter_time}s for ${#test_files[@]} files"
    
    # Cleanup
    rm -f "${test_files[@]}"
    
    echo -e "${GREEN}Benchmark completed${NC}"
}

# Command handling
case "${1:-start}" in
    "start"|"monitor")
        start_intelligent_sync
        ;;
    "test")
        test_intelligent_sync
        ;;
    "status")
        show_status
        ;;
    "benchmark")
        benchmark_performance
        ;;
    "stop")
        echo "Stopping intelligent auto-sync..."
        pkill -f "claude-intelligent-auto-sync.sh"
        pkill -f "claude-smart-sync-filter.sh"
        echo "Stopped"
        ;;
    *)
        echo "Usage: $0 {start|test|status|benchmark|stop}"
        echo
        echo "  start     - Start intelligent auto-sync daemon (default)"
        echo "  test      - Test all components"
        echo "  status    - Show status of all components"
        echo "  benchmark - Run performance benchmark"
        echo "  stop      - Stop all auto-sync processes"
        exit 1
        ;;
esac