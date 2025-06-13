#!/bin/bash
# JSON Safe Wrapper - Automatic safe JSON operations for existing scripts
# This script can be sourced to automatically make JSON operations safe

# Only load if not already loaded
if [[ -z "$JSON_SAFE_WRAPPER_LOADED" ]]; then
    export JSON_SAFE_WRAPPER_LOADED=1
    
    WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
    
    # Source the main safe operations
    if [[ -f "$WORKSPACE_DIR/scripts/json-safe-operations.sh" ]]; then
        source "$WORKSPACE_DIR/scripts/json-safe-operations.sh"
    else
        echo "Warning: json-safe-operations.sh not found, falling back to unsafe operations" >&2
        export JSON_SAFE_AVAILABLE=false
    fi
    
    # Wrapper functions that override common JSON operations
    
    # Safe jq wrapper
    safe_jq() {
        local file="$1"
        shift
        local jq_args="$@"
        
        if [[ -n "$JSON_SAFE_AVAILABLE" ]] && [[ "$JSON_SAFE_AVAILABLE" != "false" ]]; then
            # Use safe operations
            local data=$(safe_json_read "$file" "{}")
            if [[ $? -eq 0 ]]; then
                echo "$data" | jq "$jq_args"
            else
                return 1
            fi
        else
            # Fall back to regular jq
            jq "$jq_args" "$file"
        fi
    }
    
    # Safe JSON file updates
    safe_json_file_update() {
        local file="$1"
        local jq_filter="$2"
        
        if [[ -n "$JSON_SAFE_AVAILABLE" ]] && [[ "$JSON_SAFE_AVAILABLE" != "false" ]]; then
            local data=$(safe_json_read "$file" "{}")
            if [[ $? -eq 0 ]]; then
                local updated_data=$(echo "$data" | jq "$jq_filter")
                if [[ $? -eq 0 ]]; then
                    safe_json_write "$file" "$updated_data"
                else
                    return 1
                fi
            else
                return 1
            fi
        else
            # Fall back to regular jq in-place update
            local temp_file=$(mktemp)
            if jq "$jq_filter" "$file" > "$temp_file" && mv "$temp_file" "$file"; then
                return 0
            else
                rm -f "$temp_file"
                return 1
            fi
        fi
    }
    
    # Python JSON safe operations for inline usage
    python_safe_json() {
        local operation="$1"
        local file="$2"
        shift 2
        
        case "$operation" in
            "load"|"read")
                if [[ -n "$JSON_SAFE_AVAILABLE" ]] && [[ "$JSON_SAFE_AVAILABLE" != "false" ]]; then
                    safe_json_read "$file" "${1:-{}}"
                else
                    python3 -c "
import json
try:
    with open('$file', 'r') as f:
        data = json.load(f)
    print(json.dumps(data, indent=2))
except:
    print('${1:-{}}')
"
                fi
                ;;
            "dump"|"write")
                local data="$1"
                if [[ -n "$JSON_SAFE_AVAILABLE" ]] && [[ "$JSON_SAFE_AVAILABLE" != "false" ]]; then
                    safe_json_write "$file" "$data"
                else
                    echo "$data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
with open('$file', 'w') as f:
    json.dump(data, f, indent=2)
"
                fi
                ;;
            *)
                echo "Unknown operation: $operation" >&2
                return 1
                ;;
        esac
    }
    
    # Auto-upgrade function for existing scripts
    auto_upgrade_json_ops() {
        local script_file="$1"
        
        if [[ ! -f "$script_file" ]]; then
            echo "Script file not found: $script_file" >&2
            return 1
        fi
        
        echo "Auto-upgrading JSON operations in $script_file..."
        
        # Create backup
        cp "$script_file" "${script_file}.backup"
        
        # Replace common patterns
        sed -i.tmp \
            -e 's/jq \([^|]*\) \([^ ]*\.json\)/safe_jq \2 \1/g' \
            -e 's/python3.*json\.load.*open.*\([^)]*\.json\)[^)]*)/python_safe_json read \1/g' \
            -e 's/python3.*json\.dump.*open.*\([^)]*\.json\)[^)]*/python_safe_json write \1/g' \
            "$script_file"
        
        rm -f "${script_file}.tmp"
        
        echo "JSON operations upgraded. Backup saved as ${script_file}.backup"
    }
    
    # Status check
    json_safe_status() {
        if [[ -n "$JSON_SAFE_AVAILABLE" ]] && [[ "$JSON_SAFE_AVAILABLE" != "false" ]]; then
            echo "JSON Safe Operations: ✅ Available"
            
            # Show active locks
            local locks_dir="$WORKSPACE_DIR/.claude/locks"
            if [[ -d "$locks_dir" ]]; then
                local lock_count=$(find "$locks_dir" -name "*.lock" -type f | wc -l)
                echo "Active locks: $lock_count"
            fi
            
            return 0
        else
            echo "JSON Safe Operations: ❌ Not available"
            return 1
        fi
    }
    
    # Export wrapper functions
    export -f safe_jq
    export -f safe_json_file_update
    export -f python_safe_json
    export -f auto_upgrade_json_ops
    export -f json_safe_status
    
    # Auto-cleanup on exit
    cleanup_json_locks_on_exit() {
        if [[ -n "$JSON_SAFE_AVAILABLE" ]] && [[ "$JSON_SAFE_AVAILABLE" != "false" ]]; then
            cleanup_orphaned_locks 1800  # Clean locks older than 30 minutes
        fi
    }
    
    # Register cleanup trap
    trap cleanup_json_locks_on_exit EXIT
    
    echo "JSON Safe Wrapper loaded successfully"
fi

# Command line interface for the wrapper
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-status}" in
        "status")
            json_safe_status
            ;;
        "upgrade")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 upgrade <script_file>"
                exit 1
            fi
            auto_upgrade_json_ops "$2"
            ;;
        "test")
            echo "Testing JSON safe wrapper..."
            json_safe_status
            
            # Test safe_jq
            echo "Testing safe_jq..."
            if safe_jq memory/enhanced-context.json '.timestamp' >/dev/null 2>&1; then
                echo "✅ safe_jq works"
            else
                echo "❌ safe_jq failed"
            fi
            ;;
        "help")
            echo "JSON Safe Wrapper"
            echo
            echo "Usage: $0 [command]"
            echo
            echo "Commands:"
            echo "  status           - Show status of JSON safe operations"
            echo "  upgrade <script> - Auto-upgrade script to use safe operations"
            echo "  test            - Test wrapper functionality"
            echo
            echo "Functions available when sourced:"
            echo "  safe_jq <file> <filter>      - Safe jq operations"
            echo "  safe_json_file_update <file> <filter> - Safe in-place updates"
            echo "  python_safe_json <op> <file> [data] - Python JSON operations"
            echo "  json_safe_status             - Check status"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
fi