#!/bin/bash
# Atomic File Operations - Provides atomic write operations for critical files
# Prevents corruption during crashes and race conditions

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
ATOMIC_TEMP_DIR="$WORKSPACE_DIR/.claude/temp"
ATOMIC_BACKUP_DIR="$WORKSPACE_DIR/.claude/backups"
ATOMIC_LOG="$WORKSPACE_DIR/.claude/logs/atomic-operations.log"

# Configuration
BACKUP_RETENTION_DAYS=7
MAX_TEMP_AGE_MINUTES=30
ATOMIC_LOCK_TIMEOUT=30

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup directories
mkdir -p "$ATOMIC_TEMP_DIR" "$ATOMIC_BACKUP_DIR" "$(dirname "$ATOMIC_LOG")"

# Logging function
atomic_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    echo "[$timestamp] [$level] [$caller] $message" >> "$ATOMIC_LOG"
    
    case "$level" in
        "ERROR") echo -e "${RED}[ATOMIC-ERROR]${NC} $message" >&2 ;;
        "WARN") echo -e "${YELLOW}[ATOMIC-WARN]${NC} $message" >&2 ;;
        "INFO") echo -e "${BLUE}[ATOMIC-INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[ATOMIC-OK]${NC} $message" ;;
        "DEBUG") [[ "${DEBUG:-}" == "1" ]] && echo -e "${CYAN}[ATOMIC-DEBUG]${NC} $message" ;;
    esac
}

# Generate unique temporary filename
generate_temp_filename() {
    local target_file="$1"
    local basename=$(basename "$target_file")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local random=$(openssl rand -hex 4 2>/dev/null || echo "$RANDOM")
    echo "$ATOMIC_TEMP_DIR/${basename}.${timestamp}.${random}.tmp"
}

# Generate backup filename with versioning
generate_backup_filename() {
    local target_file="$1"
    local basename=$(basename "$target_file")
    local dirname=$(dirname "$target_file")
    local relative_dir="${dirname#$WORKSPACE_DIR/}"
    local backup_dir="$ATOMIC_BACKUP_DIR/${relative_dir}"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    echo "$backup_dir/${basename}.${timestamp}.backup"
}

# Check if file needs atomic operations (critical files)
is_critical_file() {
    local file_path="$1"
    
    # PID files
    if [[ "$file_path" =~ \.pid$ ]]; then
        return 0
    fi
    
    # Lock files
    if [[ "$file_path" =~ \.lock$ ]]; then
        return 0
    fi
    
    # State files
    if [[ "$file_path" =~ \.state$ ]]; then
        return 0
    fi
    
    # Configuration files in .claude
    if [[ "$file_path" =~ \.claude/.*\.(json|conf|config)$ ]]; then
        return 0
    fi
    
    # Specific critical files
    case "$file_path" in
        *"/autonomous-system.pid"|*"/smart-sync.pid"|*"/service-status.json"|*"/coordinator-state.json")
            return 0
            ;;
        *"/exit_type"|*"/auto-memory"*)
            return 0
            ;;
    esac
    
    return 1
}

# Atomic write for text content
atomic_write_text() {
    local target_file="$1"
    local content="$2"
    local create_backup="${3:-true}"
    local file_mode="${4:-644}"
    
    if [[ -z "$target_file" ]]; then
        atomic_log "ERROR" "atomic_write_text: target_file is required"
        return 1
    fi
    
    # Ensure absolute path
    if [[ ! "$target_file" =~ ^/ ]]; then
        target_file="$WORKSPACE_DIR/$target_file"
    fi
    
    atomic_log "DEBUG" "atomic_write_text: $target_file"
    
    # Create target directory if needed
    local target_dir=$(dirname "$target_file")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir" || {
            atomic_log "ERROR" "Failed to create directory: $target_dir"
            return 1
        }
    fi
    
    # Create backup if file exists
    local backup_file=""
    if [[ "$create_backup" == "true" ]] && [[ -f "$target_file" ]]; then
        backup_file=$(generate_backup_filename "$target_file")
        if ! cp "$target_file" "$backup_file" 2>/dev/null; then
            atomic_log "WARN" "Failed to create backup: $backup_file"
        else
            atomic_log "DEBUG" "Created backup: $backup_file"
        fi
    fi
    
    # Generate temporary file
    local temp_file=$(generate_temp_filename "$target_file")
    
    # Write content to temporary file
    if ! echo -n "$content" > "$temp_file" 2>/dev/null; then
        atomic_log "ERROR" "Failed to write to temporary file: $temp_file"
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        return 1
    fi
    
    # Set file mode
    chmod "$file_mode" "$temp_file" 2>/dev/null || {
        atomic_log "WARN" "Failed to set file mode $file_mode on $temp_file"
    }
    
    # Sync to disk before rename
    if command -v sync >/dev/null 2>&1; then
        sync "$temp_file" 2>/dev/null || true
    fi
    
    # Atomic move (rename is atomic on most filesystems)
    if ! mv "$temp_file" "$target_file" 2>/dev/null; then
        atomic_log "ERROR" "Failed to atomically move $temp_file to $target_file"
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        
        # Restore backup if move failed
        if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
            cp "$backup_file" "$target_file" 2>/dev/null || true
            atomic_log "INFO" "Restored backup after failed write"
        fi
        return 1
    fi
    
    atomic_log "SUCCESS" "Atomic write completed: $target_file"
    return 0
}

# Atomic write for binary content from file
atomic_write_file() {
    local source_file="$1"
    local target_file="$2"
    local create_backup="${3:-true}"
    local file_mode="${4:-644}"
    
    if [[ -z "$source_file" ]] || [[ -z "$target_file" ]]; then
        atomic_log "ERROR" "atomic_write_file: source_file and target_file are required"
        return 1
    fi
    
    if [[ ! -f "$source_file" ]]; then
        atomic_log "ERROR" "atomic_write_file: source file does not exist: $source_file"
        return 1
    fi
    
    # Ensure absolute path
    if [[ ! "$target_file" =~ ^/ ]]; then
        target_file="$WORKSPACE_DIR/$target_file"
    fi
    
    atomic_log "DEBUG" "atomic_write_file: $source_file -> $target_file"
    
    # Create target directory if needed
    local target_dir=$(dirname "$target_file")
    if [[ ! -d "$target_dir" ]]; then
        mkdir -p "$target_dir" || {
            atomic_log "ERROR" "Failed to create directory: $target_dir"
            return 1
        }
    fi
    
    # Create backup if file exists
    local backup_file=""
    if [[ "$create_backup" == "true" ]] && [[ -f "$target_file" ]]; then
        backup_file=$(generate_backup_filename "$target_file")
        if ! cp "$target_file" "$backup_file" 2>/dev/null; then
            atomic_log "WARN" "Failed to create backup: $backup_file"
        else
            atomic_log "DEBUG" "Created backup: $backup_file"
        fi
    fi
    
    # Generate temporary file
    local temp_file=$(generate_temp_filename "$target_file")
    
    # Copy source to temporary file
    if ! cp "$source_file" "$temp_file" 2>/dev/null; then
        atomic_log "ERROR" "Failed to copy to temporary file: $temp_file"
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        return 1
    fi
    
    # Set file mode
    chmod "$file_mode" "$temp_file" 2>/dev/null || {
        atomic_log "WARN" "Failed to set file mode $file_mode on $temp_file"
    }
    
    # Sync to disk before rename
    if command -v sync >/dev/null 2>&1; then
        sync "$temp_file" 2>/dev/null || true
    fi
    
    # Atomic move
    if ! mv "$temp_file" "$target_file" 2>/dev/null; then
        atomic_log "ERROR" "Failed to atomically move $temp_file to $target_file"
        [[ -f "$temp_file" ]] && rm -f "$temp_file"
        
        # Restore backup if move failed
        if [[ -n "$backup_file" ]] && [[ -f "$backup_file" ]]; then
            cp "$backup_file" "$target_file" 2>/dev/null || true
            atomic_log "INFO" "Restored backup after failed write"
        fi
        return 1
    fi
    
    atomic_log "SUCCESS" "Atomic file copy completed: $target_file"
    return 0
}

# Atomic PID file operations
atomic_write_pid() {
    local pid_file="$1"
    local pid="${2:-$$}"
    local process_name="${3:-$(basename "$0")}"
    
    if [[ -z "$pid_file" ]]; then
        atomic_log "ERROR" "atomic_write_pid: pid_file is required"
        return 1
    fi
    
    # Ensure absolute path
    if [[ ! "$pid_file" =~ ^/ ]]; then
        pid_file="$WORKSPACE_DIR/$pid_file"
    fi
    
    # Validate PID
    if ! [[ "$pid" =~ ^[0-9]+$ ]]; then
        atomic_log "ERROR" "Invalid PID: $pid"
        return 1
    fi
    
    # Check if PID is running
    if ! kill -0 "$pid" 2>/dev/null; then
        atomic_log "WARN" "PID $pid is not running"
    fi
    
    # Create PID file content with metadata
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    local content="$pid
# Process: $process_name
# Host: $hostname
# Created: $timestamp
# PID: $pid"
    
    atomic_write_text "$pid_file" "$content" false 644
}

# Read PID from PID file
atomic_read_pid() {
    local pid_file="$1"
    
    if [[ -z "$pid_file" ]]; then
        atomic_log "ERROR" "atomic_read_pid: pid_file is required"
        return 1
    fi
    
    # Ensure absolute path
    if [[ ! "$pid_file" =~ ^/ ]]; then
        pid_file="$WORKSPACE_DIR/$pid_file"
    fi
    
    if [[ ! -f "$pid_file" ]]; then
        return 1
    fi
    
    # Read first line (PID)
    local pid=$(head -n 1 "$pid_file" 2>/dev/null | tr -d ' \t\n\r')
    
    # Validate PID
    if [[ "$pid" =~ ^[0-9]+$ ]]; then
        echo "$pid"
        return 0
    else
        atomic_log "WARN" "Invalid PID in file: $pid_file"
        return 1
    fi
}

# Remove PID file atomically
atomic_remove_pid() {
    local pid_file="$1"
    local expected_pid="${2:-$$}"
    
    if [[ -z "$pid_file" ]]; then
        atomic_log "ERROR" "atomic_remove_pid: pid_file is required"
        return 1
    fi
    
    # Ensure absolute path
    if [[ ! "$pid_file" =~ ^/ ]]; then
        pid_file="$WORKSPACE_DIR/$pid_file"
    fi
    
    if [[ ! -f "$pid_file" ]]; then
        atomic_log "DEBUG" "PID file does not exist: $pid_file"
        return 0
    fi
    
    # Read current PID
    local current_pid=$(atomic_read_pid "$pid_file")
    
    # Check if we own the PID file
    if [[ -n "$current_pid" ]] && [[ "$current_pid" != "$expected_pid" ]]; then
        atomic_log "WARN" "PID file $pid_file belongs to different process: $current_pid (expected: $expected_pid)"
        return 1
    fi
    
    # Remove PID file
    if rm -f "$pid_file" 2>/dev/null; then
        atomic_log "SUCCESS" "Removed PID file: $pid_file"
        return 0
    else
        atomic_log "ERROR" "Failed to remove PID file: $pid_file"
        return 1
    fi
}

# Cleanup temporary files
cleanup_temp_files() {
    local max_age_minutes="${1:-$MAX_TEMP_AGE_MINUTES}"
    local cleaned_count=0
    
    if [[ ! -d "$ATOMIC_TEMP_DIR" ]]; then
        return 0
    fi
    
    atomic_log "DEBUG" "Cleaning up temporary files older than $max_age_minutes minutes"
    
    # Find and remove old temp files
    while IFS= read -r -d '' temp_file; do
        if [[ -f "$temp_file" ]]; then
            rm -f "$temp_file" 2>/dev/null && ((cleaned_count++))
        fi
    done < <(find "$ATOMIC_TEMP_DIR" -name "*.tmp" -type f -mmin "+$max_age_minutes" -print0 2>/dev/null)
    
    if [[ $cleaned_count -gt 0 ]]; then
        atomic_log "INFO" "Cleaned up $cleaned_count temporary files"
    fi
    
    return 0
}

# Cleanup old backups
cleanup_old_backups() {
    local retention_days="${1:-$BACKUP_RETENTION_DAYS}"
    local cleaned_count=0
    
    if [[ ! -d "$ATOMIC_BACKUP_DIR" ]]; then
        return 0
    fi
    
    atomic_log "DEBUG" "Cleaning up backups older than $retention_days days"
    
    # Find and remove old backup files
    while IFS= read -r -d '' backup_file; do
        if [[ -f "$backup_file" ]]; then
            rm -f "$backup_file" 2>/dev/null && ((cleaned_count++))
        fi
    done < <(find "$ATOMIC_BACKUP_DIR" -name "*.backup" -type f -mtime "+$retention_days" -print0 2>/dev/null)
    
    if [[ $cleaned_count -gt 0 ]]; then
        atomic_log "INFO" "Cleaned up $cleaned_count old backup files"
    fi
    
    return 0
}

# Check file consistency
check_file_consistency() {
    local file_path="$1"
    
    if [[ -z "$file_path" ]]; then
        atomic_log "ERROR" "check_file_consistency: file_path is required"
        return 1
    fi
    
    # Ensure absolute path
    if [[ ! "$file_path" =~ ^/ ]]; then
        file_path="$WORKSPACE_DIR/$file_path"
    fi
    
    if [[ ! -f "$file_path" ]]; then
        atomic_log "DEBUG" "File does not exist: $file_path"
        return 1
    fi
    
    # Check if file is readable
    if [[ ! -r "$file_path" ]]; then
        atomic_log "ERROR" "File is not readable: $file_path"
        return 1
    fi
    
    # For JSON files, validate JSON syntax
    if [[ "$file_path" =~ \.json$ ]]; then
        if command -v python3 >/dev/null 2>&1; then
            if ! python3 -c "import json; json.load(open('$file_path'))" 2>/dev/null; then
                atomic_log "ERROR" "Invalid JSON in file: $file_path"
                return 1
            fi
        elif command -v jq >/dev/null 2>&1; then
            if ! jq empty "$file_path" >/dev/null 2>&1; then
                atomic_log "ERROR" "Invalid JSON in file: $file_path"
                return 1
            fi
        fi
    fi
    
    # For PID files, validate PID
    if [[ "$file_path" =~ \.pid$ ]]; then
        local pid=$(atomic_read_pid "$file_path")
        if [[ -z "$pid" ]]; then
            atomic_log "ERROR" "Invalid PID file: $file_path"
            return 1
        fi
    fi
    
    atomic_log "DEBUG" "File consistency check passed: $file_path"
    return 0
}

# Recovery mechanism for corrupted files
recover_corrupted_file() {
    local file_path="$1"
    local force_recovery="${2:-false}"
    
    if [[ -z "$file_path" ]]; then
        atomic_log "ERROR" "recover_corrupted_file: file_path is required"
        return 1
    fi
    
    # Ensure absolute path
    if [[ ! "$file_path" =~ ^/ ]]; then
        file_path="$WORKSPACE_DIR/$file_path"
    fi
    
    atomic_log "INFO" "Attempting to recover corrupted file: $file_path"
    
    # Look for recent backup
    local basename=$(basename "$file_path")
    local dirname=$(dirname "$file_path")
    local relative_dir="${dirname#$WORKSPACE_DIR/}"
    local backup_dir="$ATOMIC_BACKUP_DIR/${relative_dir}"
    
    if [[ -d "$backup_dir" ]]; then
        # Find most recent backup
        local latest_backup=$(find "$backup_dir" -name "${basename}.*.backup" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)
        
        if [[ -n "$latest_backup" ]] && [[ -f "$latest_backup" ]]; then
            # Check if backup is valid
            if check_file_consistency "$latest_backup"; then
                if [[ "$force_recovery" == "true" ]] || [[ ! -f "$file_path" ]] || ! check_file_consistency "$file_path"; then
                    if cp "$latest_backup" "$file_path" 2>/dev/null; then
                        atomic_log "SUCCESS" "Recovered file from backup: $latest_backup -> $file_path"
                        return 0
                    else
                        atomic_log "ERROR" "Failed to copy backup: $latest_backup -> $file_path"
                    fi
                else
                    atomic_log "INFO" "File is already consistent, no recovery needed: $file_path"
                    return 0
                fi
            else
                atomic_log "ERROR" "Backup file is also corrupted: $latest_backup"
            fi
        else
            atomic_log "WARN" "No backup found for corrupted file: $file_path"
        fi
    else
        atomic_log "WARN" "No backup directory found: $backup_dir"
    fi
    
    # If no backup available, try to create default content for known file types
    if [[ ! -f "$file_path" ]] || [[ "$force_recovery" == "true" ]]; then
        case "$file_path" in
            *.json)
                atomic_log "WARN" "Creating empty JSON object for: $file_path"
                atomic_write_text "$file_path" "{}" false
                return $?
                ;;
            *.pid)
                atomic_log "ERROR" "Cannot create default PID file: $file_path"
                return 1
                ;;
        esac
    fi
    
    atomic_log "ERROR" "Failed to recover corrupted file: $file_path"
    return 1
}

# Show atomic operations status
show_atomic_status() {
    echo -e "${BLUE}Atomic File Operations Status${NC}"
    echo
    
    # Temporary files
    local temp_count=0
    if [[ -d "$ATOMIC_TEMP_DIR" ]]; then
        temp_count=$(find "$ATOMIC_TEMP_DIR" -name "*.tmp" -type f 2>/dev/null | wc -l)
    fi
    echo "Temporary files: $temp_count"
    
    # Backup files
    local backup_count=0
    if [[ -d "$ATOMIC_BACKUP_DIR" ]]; then
        backup_count=$(find "$ATOMIC_BACKUP_DIR" -name "*.backup" -type f 2>/dev/null | wc -l)
    fi
    echo "Backup files: $backup_count"
    
    # Recent operations
    if [[ -f "$ATOMIC_LOG" ]]; then
        echo
        echo "Recent operations:"
        tail -5 "$ATOMIC_LOG" | while read -r line; do
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

# Test atomic operations
test_atomic_operations() {
    echo -e "${BLUE}Testing Atomic File Operations...${NC}"
    
    local test_dir="$WORKSPACE_DIR/.claude/test-atomic"
    local test_file="$test_dir/test-file.txt"
    local test_pid_file="$test_dir/test.pid"
    local test_json_file="$test_dir/test.json"
    
    mkdir -p "$test_dir"
    
    # Test text write
    echo "Testing atomic_write_text..."
    if atomic_write_text "$test_file" "test content\nline 2\n"; then
        echo -e "${GREEN}✓ Text write test passed${NC}"
    else
        echo -e "${RED}✗ Text write test failed${NC}"
        return 1
    fi
    
    # Test PID operations
    echo "Testing PID operations..."
    if atomic_write_pid "$test_pid_file" $$ "test-process"; then
        local read_pid=$(atomic_read_pid "$test_pid_file")
        if [[ "$read_pid" == "$$" ]]; then
            echo -e "${GREEN}✓ PID operations test passed${NC}"
        else
            echo -e "${RED}✗ PID read test failed: expected $$, got $read_pid${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ PID write test failed${NC}"
        return 1
    fi
    
    # Test JSON consistency
    echo "Testing JSON consistency..."
    echo '{"test": true, "number": 42}' > "$test_json_file"
    if check_file_consistency "$test_json_file"; then
        echo -e "${GREEN}✓ JSON consistency test passed${NC}"
    else
        echo -e "${RED}✗ JSON consistency test failed${NC}"
        return 1
    fi
    
    # Test recovery
    echo "Testing recovery mechanism..."
    # Corrupt the JSON file
    echo 'invalid json' > "$test_json_file"
    if recover_corrupted_file "$test_json_file" true; then
        echo -e "${GREEN}✓ Recovery test passed${NC}"
    else
        echo -e "${RED}✗ Recovery test failed${NC}"
        return 1
    fi
    
    # Cleanup
    atomic_remove_pid "$test_pid_file" $$
    rm -rf "$test_dir"
    
    echo -e "${GREEN}All atomic operations tests passed!${NC}"
    return 0
}

# Command-line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "test")
            test_atomic_operations
            ;;
        "status")
            show_atomic_status
            ;;
        "cleanup")
            cleanup_temp_files
            cleanup_old_backups
            ;;
        "cleanup-temp")
            cleanup_temp_files "${2:-$MAX_TEMP_AGE_MINUTES}"
            ;;
        "cleanup-backups")
            cleanup_old_backups "${2:-$BACKUP_RETENTION_DAYS}"
            ;;
        "check")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 check <file_path>"
                exit 1
            fi
            check_file_consistency "$2"
            ;;
        "recover")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 recover <file_path> [force]"
                exit 1
            fi
            recover_corrupted_file "$2" "${3:-false}"
            ;;
        "write-text")
            if [[ -z "$2" ]] || [[ -z "$3" ]]; then
                echo "Usage: $0 write-text <file_path> <content> [backup] [mode]"
                exit 1
            fi
            atomic_write_text "$2" "$3" "${4:-true}" "${5:-644}"
            ;;
        "write-pid")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 write-pid <pid_file> [pid] [process_name]"
                exit 1
            fi
            atomic_write_pid "$2" "${3:-$$}" "${4:-$(basename "$0")}"
            ;;
        "read-pid")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 read-pid <pid_file>"
                exit 1
            fi
            atomic_read_pid "$2"
            ;;
        "remove-pid")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 remove-pid <pid_file> [expected_pid]"
                exit 1
            fi
            atomic_remove_pid "$2" "${3:-$$}"
            ;;
        "help"|"--help"|"-h")
            echo "Atomic File Operations - Prevents file corruption during crashes"
            echo
            echo "Usage: $0 [command] [options]"
            echo
            echo "Commands:"
            echo "  test                                - Run tests"
            echo "  status                              - Show status"
            echo "  cleanup                             - Clean up temp files and old backups"
            echo "  cleanup-temp [max_age_minutes]      - Clean up temporary files"
            echo "  cleanup-backups [retention_days]    - Clean up old backup files"
            echo "  check <file>                        - Check file consistency"
            echo "  recover <file> [force]              - Recover corrupted file from backup"
            echo "  write-text <file> <content> [backup] [mode] - Write text atomically"
            echo "  write-pid <file> [pid] [name]       - Write PID file atomically"
            echo "  read-pid <file>                     - Read PID from file"
            echo "  remove-pid <file> [expected_pid]    - Remove PID file atomically"
            echo
            echo "Shell functions available:"
            echo "  atomic_write_text <file> <content> [backup] [mode]"
            echo "  atomic_write_file <source> <target> [backup] [mode]"
            echo "  atomic_write_pid <file> [pid] [name]"
            echo "  atomic_read_pid <file>"
            echo "  atomic_remove_pid <file> [expected_pid]"
            echo "  check_file_consistency <file>"
            echo "  recover_corrupted_file <file> [force]"
            ;;
        "")
            echo "Source this script to use atomic file operation functions"
            echo "Run '$0 help' for usage information"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
fi