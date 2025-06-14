#!/bin/bash
# Error Handling Library - Common error handling functions for all scripts
# Version: 1.0
# Used by: All workspace scripts

# Exit codes standardization
readonly EXIT_SUCCESS=0
readonly EXIT_GENERAL_ERROR=1
readonly EXIT_INVALID_USAGE=2
readonly EXIT_MISSING_DEPENDENCY=3
readonly EXIT_PERMISSION_ERROR=4
readonly EXIT_TIMEOUT_ERROR=5
readonly EXIT_LOCK_ERROR=6
readonly EXIT_VALIDATION_ERROR=7

# Colors for error messages
readonly ERROR_RED='\033[0;31m'
readonly WARNING_YELLOW='\033[1;33m'
readonly INFO_BLUE='\033[0;34m'
readonly SUCCESS_GREEN='\033[0;32m'
readonly NC='\033[0m' # No Color

# Error logging function
error_log() {
    local level="$1"
    local message="$2"
    local script_name="${3:-${BASH_SOURCE[1]##*/}}"
    local line_number="${4:-${BASH_LINENO[0]}}"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Log to stderr with color
    case "$level" in
        "ERROR")
            echo -e "${ERROR_RED}[ERROR]${NC} [$script_name:$line_number] $message" >&2
            ;;
        "WARN")
            echo -e "${WARNING_YELLOW}[WARN]${NC} [$script_name:$line_number] $message" >&2
            ;;
        "INFO")
            echo -e "${INFO_BLUE}[INFO]${NC} [$script_name:$line_number] $message" >&2
            ;;
        "SUCCESS")
            echo -e "${SUCCESS_GREEN}[SUCCESS]${NC} [$script_name:$line_number] $message" >&2
            ;;
        *)
            echo "[$script_name:$line_number] $message" >&2
            ;;
    esac
    
    # Also log to workspace error log if available
    local workspace_error_log="${WORKSPACE_DIR:-$HOME/claude-workspace}/.claude/logs/error.log"
    if [[ -d "$(dirname "$workspace_error_log")" ]]; then
        echo "[$timestamp] [$level] [$script_name:$line_number] $message" >> "$workspace_error_log"
    fi
}

# Validate required parameters
validate_params() {
    local required_count="$1"
    local actual_count="$2"
    local usage_message="$3"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ $actual_count -lt $required_count ]]; then
        error_log "ERROR" "Insufficient parameters provided. Required: $required_count, Got: $actual_count" "$script_name"
        echo "Usage: $usage_message" >&2
        return $EXIT_INVALID_USAGE
    fi
    return $EXIT_SUCCESS
}

# Validate directory exists and is accessible
validate_directory() {
    local dir_path="$1"
    local purpose="$2"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ -z "$dir_path" ]]; then
        error_log "ERROR" "Directory path is empty for $purpose" "$script_name"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -d "$dir_path" ]]; then
        error_log "ERROR" "Directory does not exist: $dir_path ($purpose)" "$script_name"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -r "$dir_path" ]]; then
        error_log "ERROR" "Directory not readable: $dir_path ($purpose)" "$script_name"
        return $EXIT_PERMISSION_ERROR
    fi
    
    if [[ ! -w "$dir_path" ]]; then
        error_log "ERROR" "Directory not writable: $dir_path ($purpose)" "$script_name"
        return $EXIT_PERMISSION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Validate file exists and is accessible
validate_file() {
    local file_path="$1"
    local purpose="$2"
    local required="${3:-true}"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ -z "$file_path" ]]; then
        error_log "ERROR" "File path is empty for $purpose" "$script_name"
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -f "$file_path" ]]; then
        if [[ "$required" == "true" ]]; then
            error_log "ERROR" "Required file does not exist: $file_path ($purpose)" "$script_name"
            return $EXIT_VALIDATION_ERROR
        else
            error_log "WARN" "Optional file does not exist: $file_path ($purpose)" "$script_name"
            return $EXIT_SUCCESS
        fi
    fi
    
    if [[ ! -r "$file_path" ]]; then
        error_log "ERROR" "File not readable: $file_path ($purpose)" "$script_name"
        return $EXIT_PERMISSION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Check if required dependencies are available
check_dependencies() {
    local dependencies=("$@")
    local missing_deps=()
    local script_name="${BASH_SOURCE[1]##*/}"
    
    for dep in "${dependencies[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            missing_deps+=("$dep")
        fi
    done
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error_log "ERROR" "Missing required dependencies: ${missing_deps[*]}" "$script_name"
        echo "Please install the missing dependencies and try again." >&2
        return $EXIT_MISSING_DEPENDENCY
    fi
    
    return $EXIT_SUCCESS
}

# Execute command with timeout and proper error handling
execute_with_timeout() {
    local timeout_seconds="$1"
    local command_description="$2"
    shift 2
    local command=("$@")
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ -z "$timeout_seconds" || -z "$command_description" || ${#command[@]} -eq 0 ]]; then
        error_log "ERROR" "Invalid parameters for execute_with_timeout" "$script_name"
        return $EXIT_INVALID_USAGE
    fi
    
    error_log "INFO" "Executing: $command_description" "$script_name"
    
    # Use timeout command if available
    if command -v timeout &> /dev/null; then
        if timeout "$timeout_seconds" "${command[@]}"; then
            error_log "SUCCESS" "$command_description completed successfully" "$script_name"
            return $EXIT_SUCCESS
        else
            local exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                error_log "ERROR" "$command_description timed out after ${timeout_seconds}s" "$script_name"
                return $EXIT_TIMEOUT_ERROR
            else
                error_log "ERROR" "$command_description failed with exit code $exit_code" "$script_name"
                return $exit_code
            fi
        fi
    else
        # Fallback without timeout
        if "${command[@]}"; then
            error_log "SUCCESS" "$command_description completed successfully" "$script_name"
            return $EXIT_SUCCESS
        else
            local exit_code=$?
            error_log "ERROR" "$command_description failed with exit code $exit_code" "$script_name"
            return $exit_code
        fi
    fi
}

# Validate JSON file
validate_json_file() {
    local json_file="$1"
    local purpose="$2"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if ! validate_file "$json_file" "$purpose" false; then
        return $?
    fi
    
    if [[ -f "$json_file" ]]; then
        if ! python3 -c "import json; json.load(open('$json_file'))" 2>/dev/null; then
            error_log "ERROR" "Invalid JSON in file: $json_file ($purpose)" "$script_name"
            return $EXIT_VALIDATION_ERROR
        fi
    fi
    
    return $EXIT_SUCCESS
}

# Safe process termination with ownership check
safe_kill_process() {
    local pid="$1"
    local process_name="$2"
    local timeout_seconds="${3:-10}"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ -z "$pid" || -z "$process_name" ]]; then
        error_log "ERROR" "Invalid parameters for safe_kill_process" "$script_name"
        return $EXIT_INVALID_USAGE
    fi
    
    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        error_log "INFO" "Process $process_name (PID: $pid) is not running" "$script_name"
        return $EXIT_SUCCESS
    fi
    
    # Check ownership
    local current_uid=$(id -u)
    local process_uid=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')
    
    if [[ "$process_uid" != "$current_uid" ]]; then
        error_log "ERROR" "Cannot kill process $process_name (PID: $pid) - not owned by current user" "$script_name"
        return $EXIT_PERMISSION_ERROR
    fi
    
    # Send SIGTERM
    error_log "INFO" "Sending SIGTERM to $process_name (PID: $pid)" "$script_name"
    if ! kill -TERM "$pid" 2>/dev/null; then
        error_log "ERROR" "Failed to send SIGTERM to $process_name (PID: $pid)" "$script_name"
        return $EXIT_GENERAL_ERROR
    fi
    
    # Wait for graceful shutdown
    local count=0
    while [[ $count -lt $timeout_seconds ]] && kill -0 "$pid" 2>/dev/null; do
        sleep 1
        ((count++))
    done
    
    # Force kill if still running
    if kill -0 "$pid" 2>/dev/null; then
        error_log "WARN" "Process $process_name (PID: $pid) did not terminate gracefully, forcing" "$script_name"
        if kill -KILL "$pid" 2>/dev/null; then
            error_log "SUCCESS" "Process $process_name (PID: $pid) terminated" "$script_name"
            return $EXIT_SUCCESS
        else
            error_log "ERROR" "Failed to force kill $process_name (PID: $pid)" "$script_name"
            return $EXIT_GENERAL_ERROR
        fi
    else
        error_log "SUCCESS" "Process $process_name (PID: $pid) terminated gracefully" "$script_name"
        return $EXIT_SUCCESS
    fi
}

# Cleanup function to be called on script exit
setup_cleanup_trap() {
    local cleanup_function="$1"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ -n "$cleanup_function" ]] && declare -F "$cleanup_function" >/dev/null; then
        trap "$cleanup_function" EXIT INT TERM
        error_log "INFO" "Cleanup trap set for function: $cleanup_function" "$script_name"
    else
        error_log "WARN" "Cleanup function not found or not provided: $cleanup_function" "$script_name"
    fi
}

# Atomic file operations wrapper
atomic_write_with_validation() {
    local file_path="$1"
    local content="$2"
    local validation_type="${3:-none}"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ -z "$file_path" ]]; then
        error_log "ERROR" "File path is empty for atomic write" "$script_name"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Validate parent directory
    local parent_dir=$(dirname "$file_path")
    if ! validate_directory "$parent_dir" "atomic write target"; then
        return $?
    fi
    
    # Create temporary file
    local temp_file="${file_path}.tmp.$$"
    
    # Write content to temporary file
    if ! echo "$content" > "$temp_file"; then
        error_log "ERROR" "Failed to write to temporary file: $temp_file" "$script_name"
        rm -f "$temp_file" 2>/dev/null
        return $EXIT_GENERAL_ERROR
    fi
    
    # Validate content if requested
    if [[ "$validation_type" == "json" ]]; then
        if ! python3 -c "import json; json.load(open('$temp_file'))" 2>/dev/null; then
            error_log "ERROR" "JSON validation failed for atomic write" "$script_name"
            rm -f "$temp_file" 2>/dev/null
            return $EXIT_VALIDATION_ERROR
        fi
    fi
    
    # Atomic move
    if mv "$temp_file" "$file_path"; then
        error_log "SUCCESS" "Atomic write completed: $file_path" "$script_name"
        return $EXIT_SUCCESS
    else
        error_log "ERROR" "Atomic move failed for file: $file_path" "$script_name"
        rm -f "$temp_file" 2>/dev/null
        return $EXIT_GENERAL_ERROR
    fi
}

# Network/remote operation with retry
execute_with_retry() {
    local max_attempts="$1"
    local retry_delay="$2"
    local command_description="$3"
    shift 3
    local command=("$@")
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if [[ -z "$max_attempts" || -z "$retry_delay" || -z "$command_description" ]]; then
        error_log "ERROR" "Invalid parameters for execute_with_retry" "$script_name"
        return $EXIT_INVALID_USAGE
    fi
    
    local attempt=1
    while [[ $attempt -le $max_attempts ]]; do
        error_log "INFO" "Attempt $attempt/$max_attempts: $command_description" "$script_name"
        
        if "${command[@]}"; then
            error_log "SUCCESS" "$command_description succeeded on attempt $attempt" "$script_name"
            return $EXIT_SUCCESS
        else
            local exit_code=$?
            error_log "WARN" "$command_description failed on attempt $attempt (exit: $exit_code)" "$script_name"
            
            if [[ $attempt -lt $max_attempts ]]; then
                error_log "INFO" "Retrying in ${retry_delay}s..." "$script_name"
                sleep "$retry_delay"
            fi
        fi
        
        ((attempt++))
    done
    
    error_log "ERROR" "$command_description failed after $max_attempts attempts" "$script_name"
    return $EXIT_GENERAL_ERROR
}

# Environment validation
validate_environment() {
    local required_vars=("$@")
    local missing_vars=()
    local script_name="${BASH_SOURCE[1]##*/}"
    
    for var in "${required_vars[@]}"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done
    
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        error_log "ERROR" "Missing required environment variables: ${missing_vars[*]}" "$script_name"
        return $EXIT_VALIDATION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Git validation
validate_git_repository() {
    local repo_path="${1:-$(pwd)}"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    if ! validate_directory "$repo_path" "git repository"; then
        return $?
    fi
    
    cd "$repo_path" || {
        error_log "ERROR" "Cannot access directory: $repo_path" "$script_name"
        return $EXIT_PERMISSION_ERROR
    }
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        error_log "ERROR" "Not a git repository: $repo_path" "$script_name"
        return $EXIT_VALIDATION_ERROR
    fi
    
    # Check if git is in a clean state (no ongoing operations)
    if [[ -f .git/MERGE_HEAD || -f .git/CHERRY_PICK_HEAD || -f .git/REVERT_HEAD ]]; then
        error_log "ERROR" "Git repository is in the middle of an operation" "$script_name"
        return $EXIT_VALIDATION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# Print usage information with proper formatting
print_usage() {
    local script_name="$1"
    local description="$2"
    local usage_line="$3"
    shift 3
    local commands=("$@")
    
    echo "Claude Workspace - $description"
    echo ""
    echo "Usage: $script_name $usage_line"
    echo ""
    
    if [[ ${#commands[@]} -gt 0 ]]; then
        echo "Commands:"
        for cmd in "${commands[@]}"; do
            echo "  $cmd"
        done
        echo ""
    fi
    
    echo "Exit Codes:"
    echo "  0  - Success"
    echo "  1  - General error"
    echo "  2  - Invalid usage"
    echo "  3  - Missing dependency"
    echo "  4  - Permission error"
    echo "  5  - Timeout error"
    echo "  6  - Lock error"
    echo "  7  - Validation error"
}

# Test all error handling functions
test_error_handling() {
    echo "Testing Error Handling Library..."
    
    # Test dependency checking
    if check_dependencies "bash" "python3" "git"; then
        echo "✅ Dependency check passed"
    else
        echo "❌ Dependency check failed"
    fi
    
    # Test directory validation
    if validate_directory "/tmp" "test directory"; then
        echo "✅ Directory validation passed"
    else
        echo "❌ Directory validation failed"
    fi
    
    # Test file validation
    if validate_file "/etc/passwd" "test file" true; then
        echo "✅ File validation passed"
    else
        echo "❌ File validation failed"
    fi
    
    # Test JSON validation
    echo '{"test": true}' > /tmp/test.json
    if validate_json_file "/tmp/test.json" "test JSON"; then
        echo "✅ JSON validation passed"
    else
        echo "❌ JSON validation failed"
    fi
    rm -f /tmp/test.json
    
    # Test atomic write
    if atomic_write_with_validation "/tmp/test_atomic.txt" "test content"; then
        echo "✅ Atomic write passed"
        rm -f /tmp/test_atomic.txt
    else
        echo "❌ Atomic write failed"
    fi
    
    echo "Error handling library test completed"
}

# If script is run directly, run tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_error_handling
fi