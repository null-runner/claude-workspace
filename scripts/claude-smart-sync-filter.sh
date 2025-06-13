#!/bin/bash
# Claude Workspace - Ultra-Smart Sync Filter
# Prevents autonomous system loops while enabling instant user sync
# Uses multi-layered process-based and pattern-based filtering

WORKSPACE_DIR="$HOME/claude-workspace"
FILTER_STATE_DIR="$WORKSPACE_DIR/.claude/sync-filter"
LOG_FILE="$WORKSPACE_DIR/logs/smart-filter.log"
PROCESS_CACHE="$FILTER_STATE_DIR/process-cache.json"
SYSTEM_PATTERNS_FILE="$FILTER_STATE_DIR/system-patterns.conf"

# Performance optimization
declare -A PROCESS_CACHE_MAP
declare -A FILE_OWNER_CACHE
declare -A AUTONOMOUS_PIDS

# Setup
mkdir -p "$FILTER_STATE_DIR" "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log_filter() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    
    # Real-time output for debugging
    if [[ "${FILTER_DEBUG:-0}" == "1" ]]; then
        case "$level" in
            "FILTER") echo -e "${BLUE}[FILTER]${NC} $message" ;;
            "ALLOW") echo -e "${GREEN}[ALLOW]${NC} $message" ;;
            "BLOCK") echo -e "${RED}[BLOCK]${NC} $message" ;;
            "WARN") echo -e "${YELLOW}[WARN]${NC} $message" ;;
        esac
    fi
}

# Initialize system patterns configuration
init_system_patterns() {
    cat > "$SYSTEM_PATTERNS_FILE" <<'EOF'
# Claude Autonomous System File Patterns
# Format: TYPE:PATTERN:REASON

# Autonomous system files (always block)
BLOCK:.claude/autonomous/service-status.json:System status updates
BLOCK:.claude/autonomous/.*\.pid:Process ID files
BLOCK:.claude/memory/enhanced-context.json:Auto-saved context
BLOCK:.claude/memory/.*\.backup:Backup files
BLOCK:.claude/intelligence/.*\.log:Intelligence logs
BLOCK:.claude/intelligence/last-extraction.json:Auto-extraction data
BLOCK:.claude/metrics/.*:Performance metrics
BLOCK:logs/.*\.log:System logs

# Temporary files (always block)  
BLOCK:.*\.tmp:Temporary files
BLOCK:.*\.swp:Vim swap files
BLOCK:.*~:Backup files
BLOCK:.*\.#.*:Lock files
BLOCK:\.git/.*:Git internal files

# User-created content (always allow with high priority)
ALLOW:scripts/.*\.sh:User shell scripts
ALLOW:docs/.*\.md:User documentation
ALLOW:projects/.*:User project files
ALLOW:CLAUDE\.md:Main config file
ALLOW:README\.md:Documentation

# Mixed files (need process analysis)
ANALYZE:.claude/contexts/.*:Context files
ANALYZE:.claude/decisions/.*:Decision logs
ANALYZE:.claude/tools/.*:Tool configurations
EOF
}

# Load system patterns into memory for fast lookup
load_system_patterns() {
    if [[ ! -f "$SYSTEM_PATTERNS_FILE" ]]; then
        init_system_patterns
    fi
    
    # Load patterns into associative arrays for O(1) lookup
    while IFS=':' read -r action pattern reason; do
        [[ "$action" =~ ^#.*$ ]] && continue  # Skip comments
        [[ -z "$action" ]] && continue        # Skip empty lines
        
        case "$action" in
            "BLOCK") BLOCK_PATTERNS["$pattern"]="$reason" ;;
            "ALLOW") ALLOW_PATTERNS["$pattern"]="$reason" ;;
            "ANALYZE") ANALYZE_PATTERNS["$pattern"]="$reason" ;;
        esac
    done < "$SYSTEM_PATTERNS_FILE"
}

declare -A BLOCK_PATTERNS
declare -A ALLOW_PATTERNS  
declare -A ANALYZE_PATTERNS

# Get autonomous system PIDs with caching
get_autonomous_pids() {
    local cache_file="$FILTER_STATE_DIR/autonomous-pids.cache"
    local cache_ttl=30  # 30 seconds cache
    
    # Check cache validity
    if [[ -f "$cache_file" ]]; then
        local cache_age=$(($(date +%s) - $(stat -c %Y "$cache_file")))
        if [[ $cache_age -lt $cache_ttl ]]; then
            cat "$cache_file"
            return 0
        fi
    fi
    
    # Refresh autonomous PIDs
    {
        # Master daemon PID
        [[ -f "$WORKSPACE_DIR/.claude/autonomous/autonomous-system.pid" ]] && 
            cat "$WORKSPACE_DIR/.claude/autonomous/autonomous-system.pid"
        
        # All autonomous processes
        pgrep -f "claude-autonomous"
        pgrep -f "claude-.*-monitor"
        pgrep -f "claude-intelligence"
        pgrep -f "claude-simplified-memory"
        
        # System background processes
        pgrep -f "inotifywait.*\.claude"
        
    } 2>/dev/null | sort -u > "$cache_file"
    
    cat "$cache_file"
}

# Advanced process-based filtering
is_system_process() {
    local file="$1"
    local process_info
    
    # Get process that last modified the file
    if command -v lsof >/dev/null 2>&1; then
        # Method 1: lsof to find processes with file open
        local pids=$(lsof "$file" 2>/dev/null | awk 'NR>1 {print $2}' | sort -u)
        
        for pid in $pids; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                local cmdline=$(cat "/proc/$pid/cmdline" 2>/dev/null | tr '\0' ' ')
                
                # Check if it's an autonomous process
                if echo "$cmdline" | grep -qE "(claude-autonomous|claude-.*-monitor|claude-intelligence|claude-simplified-memory)"; then
                    log_filter "FILTER" "System process detected: PID $pid ($cmdline) modified $file"
                    return 0
                fi
            fi
        done
    fi
    
    # Method 2: Check if recent autonomous activity
    local autonomous_pids=($(get_autonomous_pids))
    local file_mtime=$(stat -c %Y "$file" 2>/dev/null || echo 0)
    local now=$(date +%s)
    local time_window=10  # 10 seconds
    
    if [[ $((now - file_mtime)) -lt $time_window ]]; then
        # File was modified recently, check autonomous processes
        for pid in "${autonomous_pids[@]}"; do
            if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
                # Check if this process had recent activity
                local proc_start=$(stat -c %Y "/proc/$pid" 2>/dev/null || echo 0)
                if [[ $proc_start -gt 0 ]] && [[ $file_mtime -gt $((proc_start - 5)) ]]; then
                    log_filter "FILTER" "Temporal correlation: file modified during autonomous process activity"
                    return 0
                fi
            fi
        done
    fi
    
    return 1
}

# Content-based analysis for system-generated changes
is_system_content() {
    local file="$1"
    
    # Check file content patterns that indicate system generation
    if [[ -f "$file" ]]; then
        case "$file" in
            *.json)
                # JSON files with system patterns
                if grep -q '"last_update":\|"timestamp":\|"session_id":' "$file" 2>/dev/null; then
                    # Check if it's ONLY system fields being updated
                    local temp_file=$(mktemp)
                    git show "HEAD:${file#$WORKSPACE_DIR/}" 2>/dev/null > "$temp_file" || echo "{}" > "$temp_file"
                    
                    # Compare with previous version, ignoring timestamp fields
                    if python3 -c "
import json, sys
try:
    with open('$file', 'r') as f: current = json.load(f)
    with open('$temp_file', 'r') as f: previous = json.load(f)
    
    # Remove timestamp fields for comparison
    for data in [current, previous]:
        data.pop('last_update', None)
        data.pop('timestamp', None)
        data.pop('session_id', None)
        if 'services' in data:
            for service in data['services'].values():
                service.pop('last_update', None)
    
    # If content is identical after removing timestamps, it's system-only
    sys.exit(0 if current == previous else 1)
except:
    sys.exit(1)
" 2>/dev/null; then
                        rm -f "$temp_file"
                        log_filter "FILTER" "System content detected: only timestamps changed in $file"
                        return 0
                    fi
                    rm -f "$temp_file"
                fi
                ;;
            *.log)
                # Log files are generally system-generated
                return 0
                ;;
        esac
    fi
    
    return 1
}

# Main filtering logic with multiple layers
should_sync_file() {
    local file="$1"
    local relative_path="${file#$WORKSPACE_DIR/}"
    
    # Layer 1: Pattern-based filtering (fastest)
    for pattern in "${!BLOCK_PATTERNS[@]}"; do
        if [[ "$relative_path" =~ $pattern ]]; then
            log_filter "BLOCK" "$relative_path - Pattern: $pattern (${BLOCK_PATTERNS[$pattern]})"
            return 1
        fi
    done
    
    for pattern in "${!ALLOW_PATTERNS[@]}"; do
        if [[ "$relative_path" =~ $pattern ]]; then
            log_filter "ALLOW" "$relative_path - Pattern: $pattern (${ALLOW_PATTERNS[$pattern]})"
            return 0
        fi
    done
    
    # Layer 2: Process-based filtering for analyze patterns
    for pattern in "${!ANALYZE_PATTERNS[@]}"; do
        if [[ "$relative_path" =~ $pattern ]]; then
            log_filter "FILTER" "$relative_path - Analyzing: $pattern (${ANALYZE_PATTERNS[$pattern]})"
            
            # Check if modified by system process
            if is_system_process "$file"; then
                log_filter "BLOCK" "$relative_path - System process modification"
                return 1
            fi
            
            # Check content analysis
            if is_system_content "$file"; then
                log_filter "BLOCK" "$relative_path - System content detected"
                return 1
            fi
            
            log_filter "ALLOW" "$relative_path - User modification confirmed"
            return 0
        fi
    done
    
    # Layer 3: Default policy for unknown files
    # If it's in a protected system directory, be conservative
    if [[ "$relative_path" =~ ^\.claude/ ]]; then
        log_filter "WARN" "$relative_path - Unknown system file, blocking by default"
        return 1
    fi
    
    # Otherwise allow (user files)
    log_filter "ALLOW" "$relative_path - Unknown user file, allowing by default"
    return 0
}

# Batch analysis for performance
analyze_file_batch() {
    local files=("$@")
    local sync_files=()
    local blocked_files=()
    
    log_filter "FILTER" "Analyzing batch of ${#files[@]} files"
    
    for file in "${files[@]}"; do
        if should_sync_file "$file"; then
            sync_files+=("$file")
        else
            blocked_files+=("$file")
        fi
    done
    
    # Output results
    if [[ ${#sync_files[@]} -gt 0 ]]; then
        echo "SYNC:${sync_files[*]}"
    fi
    
    if [[ ${#blocked_files[@]} -gt 0 ]]; then
        echo "BLOCK:${blocked_files[*]}"
    fi
    
    log_filter "FILTER" "Batch result: ${#sync_files[@]} to sync, ${#blocked_files[@]} blocked"
}

# inotify event processor with smart filtering
process_inotify_stream() {
    local debounce_time=2
    declare -A pending_files
    
    log_filter "FILTER" "Starting smart inotify stream processing"
    
    while IFS='|' read -r path event; do
        # Skip if file doesn't exist (might be deleted)
        [[ ! -e "$path" ]] && continue
        
        # Add to pending files with timestamp
        pending_files["$path"]=$(date +%s.%N)
        
        # Process pending files after debounce
        local now=$(date +%s.%N)
        local files_to_process=()
        
        for file in "${!pending_files[@]}"; do
            local file_time="${pending_files[$file]}"
            local time_diff=$(echo "$now - $file_time" | bc -l 2>/dev/null || echo 999)
            
            if (( $(echo "$time_diff >= $debounce_time" | bc -l) )); then
                files_to_process+=("$file")
                unset pending_files["$file"]
            fi
        done
        
        # Process debounced files
        if [[ ${#files_to_process[@]} -gt 0 ]]; then
            analyze_file_batch "${files_to_process[@]}"
        fi
        
    done
}

# Start intelligent monitoring with filtering
start_smart_monitoring() {
    log_filter "FILTER" "Starting smart sync filter (PID: $$)"
    
    # Initialize
    load_system_patterns
    
    # Monitor with multiple inotify streams for different priorities
    {
        # High priority: User content areas
        inotifywait -m -r -e modify,create,delete,move \
            --format '%w%f|%e' \
            "$WORKSPACE_DIR/scripts" \
            "$WORKSPACE_DIR/docs" \
            "$WORKSPACE_DIR/projects" \
            2>/dev/null &
        
        # Medium priority: Configuration files
        inotifywait -m -e modify,create,delete,move \
            --format '%w%f|%e' \
            "$WORKSPACE_DIR/CLAUDE.md" \
            "$WORKSPACE_DIR/README.md" \
            2>/dev/null &
        
        # Low priority: System areas (heavily filtered)
        inotifywait -m -r -e modify,create,delete,move \
            --format '%w%f|%e' \
            "$WORKSPACE_DIR/.claude" \
            2>/dev/null &
            
    } | process_inotify_stream
}

# Testing and validation
test_filter() {
    echo -e "${BLUE}Testing Smart Sync Filter${NC}"
    
    load_system_patterns
    
    # Test files
    local test_files=(
        "$WORKSPACE_DIR/.claude/autonomous/service-status.json"
        "$WORKSPACE_DIR/.claude/memory/enhanced-context.json"
        "$WORKSPACE_DIR/scripts/test.sh"
        "$WORKSPACE_DIR/docs/test.md"
        "$WORKSPACE_DIR/CLAUDE.md"
    )
    
    for file in "${test_files[@]}"; do
        echo -n "Testing $file ... "
        if should_sync_file "$file"; then
            echo -e "${GREEN}ALLOW${NC}"
        else
            echo -e "${RED}BLOCK${NC}"
        fi
    done
}

# Status and statistics
show_status() {
    echo -e "${BLUE}Smart Sync Filter Status${NC}"
    echo "Filter state dir: $FILTER_STATE_DIR"
    echo "System patterns: $(wc -l < "$SYSTEM_PATTERNS_FILE" 2>/dev/null || echo 0) rules"
    echo "Autonomous processes: $(get_autonomous_pids | wc -l) detected"
    echo "Log file: $LOG_FILE ($(wc -l < "$LOG_FILE" 2>/dev/null || echo 0) entries)"
    
    if [[ -f "$LOG_FILE" ]]; then
        echo
        echo "Recent activity:"
        tail -10 "$LOG_FILE" | while read -r line; do
            if [[ "$line" =~ \[ALLOW\] ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" =~ \[BLOCK\] ]]; then
                echo -e "${RED}$line${NC}"
            else
                echo "$line"
            fi
        done
    fi
}

# Command handling
case "${1:-monitor}" in
    "monitor")
        start_smart_monitoring
        ;;
    "test")
        test_filter
        ;;
    "status")
        show_status
        ;;
    "debug")
        export FILTER_DEBUG=1
        start_smart_monitoring
        ;;
    "patterns")
        echo "System patterns configuration:"
        cat "$SYSTEM_PATTERNS_FILE" 2>/dev/null || echo "Patterns file not found"
        ;;
    *)
        echo "Usage: $0 {monitor|test|status|debug|patterns}"
        echo
        echo "  monitor  - Start smart filtering (default)"
        echo "  test     - Test filter against sample files"  
        echo "  status   - Show filter status and recent activity"
        echo "  debug    - Start monitoring with debug output"
        echo "  patterns - Show system patterns configuration"
        exit 1
        ;;
esac