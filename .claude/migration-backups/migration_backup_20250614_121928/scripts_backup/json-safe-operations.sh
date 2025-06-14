#!/bin/bash
# JSON Safe Operations - Bash wrapper for safe_json_operations.py
# Provides shell functions for safe JSON operations with file locking

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
SAFE_JSON_SCRIPT="$WORKSPACE_DIR/scripts/safe_json_operations.py"
LOCKS_DIR="$WORKSPACE_DIR/.claude/locks"
LOCK_TIMEOUT=30  # seconds

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Ensure locks directory exists
mkdir -p "$LOCKS_DIR"

# Critical JSON files that always need locking
declare -A CRITICAL_JSON_FILES=(
    ["memory/enhanced-context.json"]="memory"
    ["memory/workspace-memory.json"]="memory"
    ["memory/current-session-context.json"]="memory"
    ["memory/enhanced-sessions.json"]="memory"
    ["sync/config.json"]="sync"
    ["sync/sync-config.json"]="sync"
    ["autonomous/service-status.json"]="autonomous"
    ["intelligence/auto-learnings.json"]="intelligence"
    ["intelligence/auto-decisions.json"]="intelligence"
    ["intelligence/last-extraction.json"]="intelligence"
    ["decisions/decisions.json"]="decisions"
    ["activity/activity.json"]="activity"
    ["activity/current-session.json"]="activity"
    ["settings.local.json"]="settings"
    ["auto-projects/current.json"]="projects"
    ["projects/project-config.json"]="projects"
)

# Log function
log_json_operation() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local log_file="$WORKSPACE_DIR/logs/json-operations.log"
    
    mkdir -p "$(dirname "$log_file")"
    echo "[$timestamp] [$level] $message" >> "$log_file"
    
    case "$level" in
        "ERROR") echo -e "${RED}[JSON-ERROR]${NC} $message" >&2 ;;
        "WARN") echo -e "${YELLOW}[JSON-WARN]${NC} $message" >&2 ;;
        "INFO") echo -e "${BLUE}[JSON-INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[JSON-OK]${NC} $message" ;;
    esac
}

# Check if file is critical and needs locking
is_critical_json_file() {
    local file_path="$1"
    local relative_path="${file_path#$WORKSPACE_DIR/.claude/}"
    
    # Check if it's in our critical files list
    if [[ -n "${CRITICAL_JSON_FILES[$relative_path]}" ]]; then
        return 0
    fi
    
    # Check if it's a JSON file in .claude directory
    if [[ "$file_path" =~ \.claude/.*\.json$ ]]; then
        return 0
    fi
    
    return 1
}

# Get lock file path for a JSON file
get_lock_file() {
    local json_file="$1"
    local lock_name=$(echo "$json_file" | sed 's/[^a-zA-Z0-9]/_/g')
    echo "$LOCKS_DIR/${lock_name}.lock"
}

# Check if Python safe_json_operations is available
check_safe_json_available() {
    if [[ ! -f "$SAFE_JSON_SCRIPT" ]]; then
        log_json_operation "ERROR" "safe_json_operations.py not found at $SAFE_JSON_SCRIPT"
        return 1
    fi
    
    if ! python3 -c "import sys; sys.path.insert(0, '$(dirname "$SAFE_JSON_SCRIPT")'); import safe_json_operations" 2>/dev/null; then
        log_json_operation "ERROR" "safe_json_operations.py cannot be imported"
        return 1
    fi
    
    return 0
}

# Cleanup orphaned lock files
cleanup_orphaned_locks() {
    local max_age_seconds="${1:-3600}"  # Default 1 hour
    local cleaned_count=0
    
    if [[ ! -d "$LOCKS_DIR" ]]; then
        return 0
    fi
    
    for lock_file in "$LOCKS_DIR"/*.lock; do
        if [[ ! -f "$lock_file" ]]; then
            continue
        fi
        
        # Check if lock file is older than max age
        if [[ $(find "$lock_file" -mmin +$((max_age_seconds/60)) 2>/dev/null) ]]; then
            # Try to read PID from lock file
            if [[ -f "$lock_file" ]]; then
                local lock_pid=$(cat "$lock_file" 2>/dev/null)
                
                # Check if process is still running
                if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                    rm -f "$lock_file"
                    ((cleaned_count++))
                    log_json_operation "INFO" "Cleaned orphaned lock: $(basename "$lock_file")"
                fi
            fi
        fi
    done
    
    if [[ $cleaned_count -gt 0 ]]; then
        log_json_operation "INFO" "Cleaned $cleaned_count orphaned lock files"
    fi
}

# Safe JSON read function
safe_json_read() {
    local json_file="$1"
    local default_value="${2:-null}"
    local max_retries="${3:-10}"
    
    # Ensure absolute path
    if [[ ! "$json_file" =~ ^/ ]]; then
        json_file="$WORKSPACE_DIR/.claude/$json_file"
    fi
    
    # Check if safe_json_operations is available
    if ! check_safe_json_available; then
        # Fallback to regular JSON read
        if [[ -f "$json_file" ]]; then
            cat "$json_file"
        else
            echo "$default_value"
        fi
        return 0
    fi
    
    # Cleanup old locks before operation
    cleanup_orphaned_locks
    
    # Write default value to temp file to handle None/null properly
    local temp_default=$(mktemp)
    echo "$default_value" > "$temp_default"
    
    # Use Python safe operations
    local result
    result=$(python3 -c "
import sys
import os
import json
sys.path.insert(0, '$(dirname "$SAFE_JSON_SCRIPT")')
from safe_json_operations import safe_json_read, SafeJSONError

try:
    # Read default value from temp file
    with open('$temp_default', 'r') as f:
        default_data = json.load(f)
    
    data = safe_json_read('$json_file', default_data, $max_retries)
    if data is not None:
        print(json.dumps(data, indent=2))
    else:
        print(json.dumps(default_data, indent=2))
except SafeJSONError as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR: Unexpected error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1)
    
    # Cleanup temp file
    rm -f "$temp_default"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        echo "$result"
        log_json_operation "SUCCESS" "Read JSON file: $json_file"
        return 0
    else
        log_json_operation "ERROR" "Failed to read JSON file: $json_file - $result"
        echo "$default_value"
        return 1
    fi
}

# Safe JSON write function
safe_json_write() {
    local json_file="$1"
    local json_data="$2"
    local indent="${3:-2}"
    local max_retries="${4:-10}"
    local backup="${5:-true}"
    
    # Ensure absolute path
    if [[ ! "$json_file" =~ ^/ ]]; then
        json_file="$WORKSPACE_DIR/.claude/$json_file"
    fi
    
    # Check if safe_json_operations is available
    if ! check_safe_json_available; then
        log_json_operation "ERROR" "safe_json_operations.py not available for writing $json_file"
        return 1
    fi
    
    # Cleanup old locks before operation
    cleanup_orphaned_locks
    
    # Create directory if needed
    mkdir -p "$(dirname "$json_file")"
    
    # Write JSON data to temporary file to avoid shell escaping issues
    local temp_json=$(mktemp)
    echo "$json_data" > "$temp_json"
    
    # Use Python safe operations
    local result
    result=$(python3 -c "
import sys
import os
import json
sys.path.insert(0, '$(dirname "$SAFE_JSON_SCRIPT")')
from safe_json_operations import safe_json_write, SafeJSONError

try:
    # Read JSON data from temp file
    with open('$temp_json', 'r') as f:
        data = json.load(f)
    
    # Write safely
    backup_bool = '$backup' == 'true'
    success = safe_json_write('$json_file', data, $indent, $max_retries, backup_bool)
    
    if success:
        print('SUCCESS')
    else:
        print('FAILED')
        sys.exit(1)
        
except json.JSONDecodeError as e:
    print(f'ERROR: Invalid JSON data: {e}', file=sys.stderr)
    sys.exit(1)
except SafeJSONError as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR: Unexpected error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1)
    
    local exit_code=$?
    
    # Cleanup temp file
    rm -f "$temp_json"
    
    if [[ $exit_code -eq 0 ]]; then
        log_json_operation "SUCCESS" "Wrote JSON file: $json_file"
        return 0
    else
        log_json_operation "ERROR" "Failed to write JSON file: $json_file - $result"
        return 1
    fi
}

# Safe JSON update function
safe_json_update() {
    local json_file="$1"
    local update_script="$2"
    local default_value="${3:-{}}"
    local max_retries="${4:-10}"
    local backup="${5:-true}"
    
    # Ensure absolute path
    if [[ ! "$json_file" =~ ^/ ]]; then
        json_file="$WORKSPACE_DIR/.claude/$json_file"
    fi
    
    # Check if safe_json_operations is available
    if ! check_safe_json_available; then
        log_json_operation "ERROR" "safe_json_operations.py not available for updating $json_file"
        return 1
    fi
    
    # Cleanup old locks before operation
    cleanup_orphaned_locks
    
    # Write default value and update script to temp files
    local temp_default=$(mktemp)
    local temp_script=$(mktemp)
    echo "$default_value" > "$temp_default"
    echo "$update_script" > "$temp_script"
    
    # Use Python safe operations
    local result
    result=$(python3 -c "
import sys
import os
import json
sys.path.insert(0, '$(dirname "$SAFE_JSON_SCRIPT")')
from safe_json_operations import safe_json_update, SafeJSONError

def update_function(data):
    # Read and execute the update script
    with open('$temp_script', 'r') as f:
        script_code = f.read()
    
    exec(script_code)
    return data

try:
    # Read default value from temp file
    with open('$temp_default', 'r') as f:
        default_data = json.load(f)
    
    backup_bool = '$backup' == 'true'
    updated_data = safe_json_update('$json_file', update_function, default_data, $max_retries, backup_bool)
    print(json.dumps(updated_data, indent=2))
    
except SafeJSONError as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR: Unexpected error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1)
    
    # Cleanup temp files
    rm -f "$temp_default" "$temp_script"
    
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_json_operation "SUCCESS" "Updated JSON file: $json_file"
        echo "$result"
        return 0
    else
        log_json_operation "ERROR" "Failed to update JSON file: $json_file - $result"
        return 1
    fi
}

# Atomic JSON merge function
safe_json_merge() {
    local json_file="$1"
    local merge_data="$2"
    local max_retries="${3:-10}"
    local backup="${4:-true}"
    
    # Ensure absolute path
    if [[ ! "$json_file" =~ ^/ ]]; then
        json_file="$WORKSPACE_DIR/.claude/$json_file"
    fi
    
    # Check if safe_json_operations is available
    if ! check_safe_json_available; then
        log_json_operation "ERROR" "safe_json_operations.py not available for merging $json_file"
        return 1
    fi
    
    # Cleanup old locks before operation
    cleanup_orphaned_locks
    
    # Write merge data to temporary file
    local temp_json=$(mktemp)
    echo "$merge_data" > "$temp_json"
    
    # Use Python safe operations
    local result
    result=$(python3 -c "
import sys
import os
import json
sys.path.insert(0, '$(dirname "$SAFE_JSON_SCRIPT")')
from safe_json_operations import safe_json_update, SafeJSONError

def merge_function(data):
    # Ensure data is a dict
    if not isinstance(data, dict):
        data = {}
    
    # Read merge data from temp file
    with open('$temp_json', 'r') as f:
        merge_data = json.load(f)
    
    # Merge data
    data.update(merge_data)
    return data

try:
    backup_bool = '$backup' == 'true'
    updated_data = safe_json_update('$json_file', merge_function, {}, $max_retries, backup_bool)
    print(json.dumps(updated_data, indent=2))
    
except SafeJSONError as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f'ERROR: Unexpected error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1)
    
    local exit_code=$?
    
    # Cleanup temp file
    rm -f "$temp_json"
    
    if [[ $exit_code -eq 0 ]]; then
        log_json_operation "SUCCESS" "Merged JSON file: $json_file"
        echo "$result"
        return 0
    else
        log_json_operation "ERROR" "Failed to merge JSON file: $json_file - $result"
        return 1
    fi
}

# Test the JSON operations
test_json_operations() {
    echo -e "${BLUE}Testing JSON Safe Operations...${NC}"
    
    local test_file="$WORKSPACE_DIR/.claude/test/test-operations.json"
    local test_data='{"test": true, "timestamp": "2025-01-01T00:00:00Z", "counter": 0}'
    
    # Create test directory
    mkdir -p "$(dirname "$test_file")"
    
    # Test write
    echo "Testing safe_json_write..."
    if safe_json_write "$test_file" "$test_data"; then
        echo -e "${GREEN}✓ Write test passed${NC}"
    else
        echo -e "${RED}✗ Write test failed${NC}"
        return 1
    fi
    
    # Test read
    echo "Testing safe_json_read..."
    local read_result
    read_result=$(safe_json_read "$test_file")
    if [[ $? -eq 0 ]] && [[ -n "$read_result" ]]; then
        echo -e "${GREEN}✓ Read test passed${NC}"
    else
        echo -e "${RED}✗ Read test failed${NC}"
        return 1
    fi
    
    # Test update
    echo "Testing safe_json_update..."
    local update_script='data["counter"] = data.get("counter", 0) + 1; data["updated"] = True'
    if safe_json_update "$test_file" "$update_script" > /dev/null; then
        echo -e "${GREEN}✓ Update test passed${NC}"
    else
        echo -e "${RED}✗ Update test failed${NC}"
        return 1
    fi
    
    # Test merge
    echo "Testing safe_json_merge..."
    local merge_data='{"merged": true, "merge_timestamp": "2025-01-01T12:00:00Z"}'
    if safe_json_merge "$test_file" "$merge_data" > /dev/null; then
        echo -e "${GREEN}✓ Merge test passed${NC}"
    else
        echo -e "${RED}✗ Merge test failed${NC}"
        return 1
    fi
    
    # Test concurrent access
    echo "Testing concurrent access..."
    local concurrent_success=true
    
    # Start multiple background processes
    for i in {1..5}; do
        (
            local worker_data="{\"worker_$i\": true, \"timestamp\": \"$(date -Iseconds)\"}"
            if ! safe_json_merge "$test_file" "$worker_data" > /dev/null 2>&1; then
                echo "Worker $i failed" >&2
                exit 1
            fi
        ) &
    done
    
    # Wait for all workers
    if wait; then
        echo -e "${GREEN}✓ Concurrent access test passed${NC}"
    else
        echo -e "${RED}✗ Concurrent access test failed${NC}"
        concurrent_success=false
    fi
    
    # Cleanup
    rm -f "$test_file"
    
    if [[ "$concurrent_success" == "true" ]]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed!${NC}"
        return 1
    fi
}

# Clean up all lock files
cleanup_all_locks() {
    local force="${1:-false}"
    local cleaned_count=0
    
    if [[ ! -d "$LOCKS_DIR" ]]; then
        echo "No locks directory found"
        return 0
    fi
    
    for lock_file in "$LOCKS_DIR"/*.lock; do
        if [[ ! -f "$lock_file" ]]; then
            continue
        fi
        
        if [[ "$force" == "true" ]]; then
            rm -f "$lock_file"
            ((cleaned_count++))
        else
            # Check if process is still running
            local lock_pid=$(cat "$lock_file" 2>/dev/null)
            if [[ -n "$lock_pid" ]] && ! kill -0 "$lock_pid" 2>/dev/null; then
                rm -f "$lock_file"
                ((cleaned_count++))
            fi
        fi
    done
    
    echo "Cleaned $cleaned_count lock files"
}

# Show status of JSON operations
show_json_status() {
    echo -e "${BLUE}JSON Safe Operations Status${NC}"
    echo
    
    # Check availability
    if check_safe_json_available; then
        echo -e "Python module: ${GREEN}✓ Available${NC}"
    else
        echo -e "Python module: ${RED}✗ Not available${NC}"
    fi
    
    # Show active locks
    local active_locks=0
    if [[ -d "$LOCKS_DIR" ]]; then
        active_locks=$(find "$LOCKS_DIR" -name "*.lock" -type f | wc -l)
    fi
    
    echo "Active locks: $active_locks"
    
    # Show recent operations
    local log_file="$WORKSPACE_DIR/logs/json-operations.log"
    if [[ -f "$log_file" ]]; then
        echo
        echo "Recent operations:"
        tail -5 "$log_file" | while read -r line; do
            if [[ "$line" =~ ERROR ]]; then
                echo -e "${RED}$line${NC}"
            elif [[ "$line" =~ SUCCESS ]]; then
                echo -e "${GREEN}$line${NC}"
            elif [[ "$line" =~ WARN ]]; then
                echo -e "${YELLOW}$line${NC}"
            else
                echo "$line"
            fi
        done
    fi
}

# Command-line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "test")
            test_json_operations
            ;;
        "status")
            show_json_status
            ;;
        "cleanup")
            cleanup_all_locks "${2:-false}"
            ;;
        "read")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 read <json_file> [default_value]"
                exit 1
            fi
            safe_json_read "$2" "${3:-null}"
            ;;
        "write")
            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                echo "Usage: $0 write <json_file> <json_data>"
                exit 1
            fi
            safe_json_write "$2" "$3"
            ;;
        "merge")
            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                echo "Usage: $0 merge <json_file> <json_data>"
                exit 1
            fi
            safe_json_merge "$2" "$3"
            ;;
        "help"|"--help"|"-h")
            echo "JSON Safe Operations - Shell wrapper for safe JSON operations"
            echo
            echo "Usage: $0 [command] [options]"
            echo
            echo "Commands:"
            echo "  test                           - Run tests"
            echo "  status                         - Show status"
            echo "  cleanup [force]                - Clean up lock files"
            echo "  read <file> [default]          - Read JSON file"
            echo "  write <file> <data>            - Write JSON file"
            echo "  merge <file> <data>            - Merge data into JSON file"
            echo
            echo "Shell functions available:"
            echo "  safe_json_read <file> [default] [retries]"
            echo "  safe_json_write <file> <data> [indent] [retries] [backup]"
            echo "  safe_json_update <file> <script> [default] [retries] [backup]"
            echo "  safe_json_merge <file> <data> [retries] [backup]"
            ;;
        "")
            echo "Source this script to use JSON safe operations functions"
            echo "Run '$0 help' for usage information"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
fi