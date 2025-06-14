#!/bin/bash
# Error Handling Template - Template per aggiungere error handling robusto
# Usage: source questo template all'inizio di ogni script

# ================================
# TEMPLATE HEADER - Add to start of every script
# ================================

set -euo pipefail  # Strict error handling

# Environment validation
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"

# Source error handling library
if [[ -f "$WORKSPACE_DIR/scripts/error-handling-library.sh" ]]; then
    source "$WORKSPACE_DIR/scripts/error-handling-library.sh"
else
    echo "ERROR: error-handling-library.sh not found" >&2
    exit 3
fi

# Validate basic environment
validate_environment "HOME" "WORKSPACE_DIR" || exit $?
validate_directory "$WORKSPACE_DIR" "workspace directory" || exit $?

# Setup cleanup trap
cleanup_script() {
    local script_name="${BASH_SOURCE[1]##*/}"
    error_log "INFO" "Cleanup called for $script_name"
    # Add script-specific cleanup here
}
setup_cleanup_trap cleanup_script

# ================================
# COMMON VALIDATION FUNCTIONS
# ================================

# Validate script dependencies
validate_script_dependencies() {
    local script_name="${BASH_SOURCE[1]##*/}"
    error_log "INFO" "Validating dependencies for $script_name"
    
    # Common dependencies
    check_dependencies "bash" "git" || return $?
    
    # Python scripts also need python3
    if grep -q "python3" "${BASH_SOURCE[1]}" 2>/dev/null; then
        check_dependencies "python3" || return $?
    fi
    
    return $EXIT_SUCCESS
}

# Validate git repository
validate_git_workspace() {
    validate_git_repository "$WORKSPACE_DIR" || return $?
    return $EXIT_SUCCESS
}

# Safe script execution
safe_execute_script() {
    local script_path="$1"
    local description="$2"
    local timeout="${3:-30}"
    shift 3
    local args=("$@")
    
    # Validate script exists and is executable
    if ! validate_file "$script_path" "$description script" true; then
        return $EXIT_VALIDATION_ERROR
    fi
    
    if [[ ! -x "$script_path" ]]; then
        error_log "ERROR" "$description script is not executable: $script_path"
        return $EXIT_PERMISSION_ERROR
    fi
    
    # Execute with timeout
    execute_with_timeout "$timeout" "$description" "$script_path" "${args[@]}"
}

# Safe directory change
safe_cd() {
    local target_dir="$1"
    local purpose="$2"
    
    if ! validate_directory "$target_dir" "$purpose"; then
        return $?
    fi
    
    if ! cd "$target_dir"; then
        error_log "ERROR" "Failed to change to directory: $target_dir ($purpose)"
        return $EXIT_PERMISSION_ERROR
    fi
    
    return $EXIT_SUCCESS
}

# ================================
# PARAMETER VALIDATION TEMPLATES
# ================================

# Template for command with subcommands
validate_command_parameters() {
    local script_name="$1"
    local command="$2"
    local min_params="$3"
    local actual_params="$4"
    shift 4
    local valid_commands=("$@")
    
    # Validate command
    local valid_command=false
    for valid_cmd in "${valid_commands[@]}"; do
        if [[ "$command" == "$valid_cmd" ]]; then
            valid_command=true
            break
        fi
    done
    
    if [[ "$valid_command" == false ]]; then
        error_log "ERROR" "Invalid command: $command"
        echo "Valid commands: ${valid_commands[*]}" >&2
        return $EXIT_INVALID_USAGE
    fi
    
    # Validate parameter count
    if [[ $actual_params -lt $min_params ]]; then
        error_log "ERROR" "Insufficient parameters for command: $command"
        return $EXIT_INVALID_USAGE
    fi
    
    return $EXIT_SUCCESS
}

# ================================
# COMMON EXIT HANDLING
# ================================

# Template for main function with error tracking
execute_main_function() {
    local function_name="$1"
    local script_name="${BASH_SOURCE[1]##*/}"
    
    error_log "INFO" "Starting $function_name in $script_name"
    
    if "$function_name"; then
        error_log "SUCCESS" "$function_name completed successfully"
        return $EXIT_SUCCESS
    else
        local exit_code=$?
        error_log "ERROR" "$function_name failed with exit code $exit_code"
        return $exit_code
    fi
}

# Template for command handling
handle_command() {
    local script_name="$1"
    local command="$2"
    shift 2
    local params=("$@")
    
    case "$command" in
        "help"|"--help"|"-h")
            show_help "$script_name"
            exit $EXIT_SUCCESS
            ;;
        "test")
            run_tests
            exit $?
            ;;
        *)
            error_log "ERROR" "Unknown command: $command"
            echo "Use '$script_name help' for usage information" >&2
            exit $EXIT_INVALID_USAGE
            ;;
    esac
}

# ================================
# EXAMPLE USAGE IN SCRIPT
# ================================

example_main_function() {
    # 1. Validate dependencies
    validate_script_dependencies || return $?
    
    # 2. Validate specific requirements
    validate_git_workspace || return $?
    
    # 3. Execute work with proper error handling
    safe_cd "$WORKSPACE_DIR" "workspace directory" || return $?
    
    # 4. Safe execution of external scripts
    safe_execute_script "$WORKSPACE_DIR/scripts/other-script.sh" "helper script" 30 || return $?
    
    # 5. Return success
    return $EXIT_SUCCESS
}

example_command_handling() {
    local script_name="${BASH_SOURCE[0]##*/}"
    local command="${1:-help}"
    
    # Validate command and parameters
    validate_command_parameters "$script_name" "$command" 0 $# \
        "start" "stop" "status" "help" "test" || exit $?
    
    case "$command" in
        "start")
            execute_main_function "start_service"
            exit $?
            ;;
        "stop")
            execute_main_function "stop_service"
            exit $?
            ;;
        "status")
            execute_main_function "show_status"
            exit $?
            ;;
        *)
            handle_command "$script_name" "$command" "${@:2}"
            ;;
    esac
}

# ================================
# HELP TEMPLATE
# ================================

show_help() {
    local script_name="$1"
    print_usage "$script_name" "Script description" "[command] [options]" \
        "start                Start the service" \
        "stop                 Stop the service" \
        "status               Show service status" \
        "test                 Run tests" \
        "help                 Show this help"
}

run_tests() {
    error_log "INFO" "Running tests for ${BASH_SOURCE[1]##*/}"
    
    # Test dependencies
    validate_script_dependencies || return $?
    
    # Test workspace
    validate_git_workspace || return $?
    
    error_log "SUCCESS" "All tests passed"
    return $EXIT_SUCCESS
}

# ================================
# TEMPLATE END
# ================================

# If this template is run directly, show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error Handling Template - Source this file in your scripts"
    echo ""
    echo "Usage in your script:"
    echo "  source \"\$WORKSPACE_DIR/scripts/error-handling-template.sh\""
    echo ""
    echo "Features provided:"
    echo "  - Strict error handling (set -euo pipefail)"
    echo "  - Error handling library integration"
    echo "  - Common validation functions"
    echo "  - Safe execution wrappers"
    echo "  - Parameter validation templates"
    echo "  - Standardized exit codes"
    echo "  - Cleanup trap setup"
    exit 1
fi