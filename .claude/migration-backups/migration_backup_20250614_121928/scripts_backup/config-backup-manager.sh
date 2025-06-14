#!/bin/bash
# Config Backup Manager - Automatic backup strategy for configuration files
# Ensures critical configuration files are backed up regularly and can be restored

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
BACKUP_ROOT="$WORKSPACE_DIR/.claude/config-backups"
CONFIG_BACKUP_CONFIG="$BACKUP_ROOT/backup-config.json"
BACKUP_LOG="$BACKUP_ROOT/backup.log"

# Configuration
BACKUP_RETENTION_DAYS=30
MAX_BACKUPS_PER_FILE=20
BACKUP_INTERVAL_HOURS=6
COMPRESSION_ENABLED=true

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration file patterns to backup
declare -A CONFIG_FILES=(
    # Core workspace configuration
    ["CLAUDE.md"]="critical"
    ["README.md"]="normal"
    [".gitignore"]="normal"
    [".gitattributes"]="normal"
    
    # Claude system configuration
    [".claude/settings.local.json"]="critical"
    [".claude/sync/config.json"]="critical"
    [".claude/sync/sync-config.json"]="critical"
    [".claude/projects/project-config.json"]="critical"
    [".claude/autonomous/service-status.json"]="important"
    [".claude/memory-coordination/operation-queue.json"]="important"
    [".claude/sync-coordination/coordinator-state.json"]="important"
    [".claude/intelligence/auto-learnings.json"]="important"
    [".claude/intelligence/auto-decisions.json"]="important"
    [".claude/activity/activity.json"]="normal"
    [".claude/decisions/decisions.json"]="normal"
    [".claude/metrics/productivity.json"]="normal"
    [".claude/learning/learnings.json"]="normal"
    [".claude/contexts/index.json"]="normal"
    [".claude/tools/weekly-digest.json"]="normal"
    
    # Profile and user configuration
    [".claude/profile/user-profile.json"]="critical"
    [".claude/profile/preferences.json"]="critical"
    
    # Script configurations
    ["scripts/config/*.conf"]="important"
    ["scripts/config/*.json"]="important"
)

# Source dependencies
source "$WORKSPACE_DIR/scripts/atomic-file-operations.sh" 2>/dev/null || {
    echo "Warning: atomic-file-operations.sh not available" >&2
}

source "$WORKSPACE_DIR/scripts/json-safe-operations.sh" 2>/dev/null || {
    echo "Warning: json-safe-operations.sh not available" >&2
}

# Setup directories
mkdir -p "$BACKUP_ROOT" "$(dirname "$BACKUP_LOG")"

# Logging function
backup_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    echo "[$timestamp] [$level] [$caller] $message" >> "$BACKUP_LOG"
    
    case "$level" in
        "ERROR") echo -e "${RED}[BACKUP-ERROR]${NC} $message" >&2 ;;
        "WARN") echo -e "${YELLOW}[BACKUP-WARN]${NC} $message" >&2 ;;
        "INFO") echo -e "${BLUE}[BACKUP-INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[BACKUP-OK]${NC} $message" ;;
        "DEBUG") [[ "${DEBUG:-}" == "1" ]] && echo -e "${CYAN}[BACKUP-DEBUG]${NC} $message" ;;
    esac
}

# Initialize backup configuration
init_backup_config() {
    if [[ ! -f "$CONFIG_BACKUP_CONFIG" ]]; then
        local initial_config='{
    "version": "1.0",
    "created": "'$(date -Iseconds)'",
    "settings": {
        "retention_days": '$BACKUP_RETENTION_DAYS',
        "max_backups_per_file": '$MAX_BACKUPS_PER_FILE',
        "interval_hours": '$BACKUP_INTERVAL_HOURS',
        "compression_enabled": '$([[ "$COMPRESSION_ENABLED" == "true" ]] && echo "true" || echo "false")'
    },
    "files": {},
    "last_backup": null,
    "stats": {
        "files_backed_up": 0,
        "backups_created": 0,
        "backups_cleaned": 0,
        "files_restored": 0
    }
}'
        if command -v safe_json_write >/dev/null 2>&1; then
            safe_json_write "$CONFIG_BACKUP_CONFIG" "$initial_config"
        else
            atomic_write_text "$CONFIG_BACKUP_CONFIG" "$initial_config"
        fi
        backup_log "INFO" "Initialized backup configuration"
    fi
}

# Get backup directory for a file
get_backup_dir() {
    local file_path="$1"
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    local safe_path=$(echo "$relative_path" | sed 's/[^a-zA-Z0-9._/-]/_/g')
    echo "$BACKUP_ROOT/files/$(dirname "$safe_path")"
}

# Get backup filename with timestamp
get_backup_filename() {
    local file_path="$1"
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    local basename=$(basename "$file_path")
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local random=$(openssl rand -hex 4 2>/dev/null || echo "$RANDOM")
    
    local extension=""
    if [[ "$COMPRESSION_ENABLED" == "true" ]]; then
        extension=".gz"
    fi
    
    echo "${basename}.${timestamp}.${random}.backup${extension}"
}

# Create backup of a file
create_backup() {
    local file_path="$1"
    local priority="${2:-normal}"
    local force="${3:-false}"
    
    # Ensure absolute path
    if [[ ! "$file_path" =~ ^/ ]]; then
        file_path="$WORKSPACE_DIR/$file_path"
    fi
    
    if [[ ! -f "$file_path" ]]; then
        backup_log "DEBUG" "File does not exist, skipping backup: $file_path"
        return 1
    fi
    
    # Check if file should be backed up
    local should_backup=false
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    
    for pattern in "${!CONFIG_FILES[@]}"; do
        if [[ "$relative_path" == $pattern ]] || [[ "$relative_path" == *"$pattern"* ]]; then
            should_backup=true
            break
        fi
    done
    
    if [[ "$should_backup" != "true" ]] && [[ "$force" != "true" ]]; then
        backup_log "DEBUG" "File not in backup list: $file_path"
        return 0
    fi
    
    init_backup_config
    
    # Get backup directory and create it
    local backup_dir=$(get_backup_dir "$file_path")
    mkdir -p "$backup_dir" || {
        backup_log "ERROR" "Failed to create backup directory: $backup_dir"
        return 1
    }
    
    # Generate backup filename
    local backup_filename=$(get_backup_filename "$file_path")
    local backup_path="$backup_dir/$backup_filename"
    
    # Create backup
    backup_log "DEBUG" "Creating backup: $file_path -> $backup_path"
    
    if [[ "$COMPRESSION_ENABLED" == "true" ]] && command -v gzip >/dev/null 2>&1; then
        # Compressed backup
        if gzip -c "$file_path" > "$backup_path" 2>/dev/null; then
            backup_log "SUCCESS" "Created compressed backup: $backup_path"
        else
            backup_log "ERROR" "Failed to create compressed backup: $file_path"
            return 1
        fi
    else
        # Uncompressed backup
        if atomic_write_file "$file_path" "$backup_path" false 644; then
            backup_log "SUCCESS" "Created backup: $backup_path"
        else
            backup_log "ERROR" "Failed to create backup: $file_path"
            return 1
        fi
    fi
    
    # Update configuration
    local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
    local checksum=$(sha256sum "$file_path" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
    local timestamp=$(date -Iseconds)
    
    # Update backup stats
    if command -v safe_json_update >/dev/null 2>&1; then
        local update_script="
files = data.get('files', {})
files['$relative_path'] = files.get('$relative_path', {})
files['$relative_path']['last_backup'] = '$timestamp'
files['$relative_path']['priority'] = '$priority'
files['$relative_path']['size'] = $file_size
files['$relative_path']['checksum'] = '$checksum'
files['$relative_path']['backup_count'] = files.get('$relative_path', {}).get('backup_count', 0) + 1
data['files'] = files
data['last_backup'] = '$timestamp'
data['stats']['backups_created'] = data.get('stats', {}).get('backups_created', 0) + 1
"
        safe_json_update "$CONFIG_BACKUP_CONFIG" "$update_script" >/dev/null 2>&1
    fi
    
    # Cleanup old backups for this file
    cleanup_old_backups_for_file "$file_path"
    
    return 0
}

# Cleanup old backups for a specific file
cleanup_old_backups_for_file() {
    local file_path="$1"
    local backup_dir=$(get_backup_dir "$file_path")
    local basename=$(basename "$file_path")
    
    if [[ ! -d "$backup_dir" ]]; then
        return 0
    fi
    
    # Find all backup files for this file, sorted by modification time (newest first)
    local backup_files=($(find "$backup_dir" -name "${basename}.*.backup*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | cut -d' ' -f2-))
    local total_backups=${#backup_files[@]}
    
    # Remove excess backups
    if [[ $total_backups -gt $MAX_BACKUPS_PER_FILE ]]; then
        local files_to_remove=$((total_backups - MAX_BACKUPS_PER_FILE))
        for ((i=MAX_BACKUPS_PER_FILE; i<total_backups; i++)); do
            if [[ -f "${backup_files[i]}" ]]; then
                rm -f "${backup_files[i]}" 2>/dev/null
                backup_log "DEBUG" "Removed old backup: ${backup_files[i]}"
                
                # Update stats
                if command -v safe_json_update >/dev/null 2>&1; then
                    local update_script="data['stats']['backups_cleaned'] = data.get('stats', {}).get('backups_cleaned', 0) + 1"
                    safe_json_update "$CONFIG_BACKUP_CONFIG" "$update_script" >/dev/null 2>&1
                fi
            fi
        done
        backup_log "INFO" "Cleaned up $files_to_remove old backups for: $file_path"
    fi
    
    # Remove backups older than retention period
    local retention_seconds=$((BACKUP_RETENTION_DAYS * 24 * 3600))
    local current_time=$(date +%s)
    
    for backup_file in "${backup_files[@]}"; do
        if [[ -f "$backup_file" ]]; then
            local file_time=$(stat -c %Y "$backup_file" 2>/dev/null || echo "0")
            local age_seconds=$((current_time - file_time))
            
            if [[ $age_seconds -gt $retention_seconds ]]; then
                rm -f "$backup_file" 2>/dev/null
                backup_log "DEBUG" "Removed expired backup: $backup_file"
                
                # Update stats
                if command -v safe_json_update >/dev/null 2>&1; then
                    local update_script="data['stats']['backups_cleaned'] = data.get('stats', {}).get('backups_cleaned', 0) + 1"
                    safe_json_update "$CONFIG_BACKUP_CONFIG" "$update_script" >/dev/null 2>&1
                fi
            fi
        fi
    done
}

# Restore file from backup
restore_file() {
    local file_path="$1"
    local backup_timestamp="${2:-latest}"
    local force="${3:-false}"
    
    # Ensure absolute path
    if [[ ! "$file_path" =~ ^/ ]]; then
        file_path="$WORKSPACE_DIR/$file_path"
    fi
    
    local backup_dir=$(get_backup_dir "$file_path")
    local basename=$(basename "$file_path")
    
    if [[ ! -d "$backup_dir" ]]; then
        backup_log "ERROR" "No backup directory found for: $file_path"
        return 1
    fi
    
    # Find backup file
    local backup_file=""
    
    if [[ "$backup_timestamp" == "latest" ]]; then
        # Get latest backup
        backup_file=$(find "$backup_dir" -name "${basename}.*.backup*" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)
    else
        # Find backup with specific timestamp
        backup_file=$(find "$backup_dir" -name "${basename}.${backup_timestamp}.*.backup*" -type f 2>/dev/null | head -n1)
    fi
    
    if [[ -z "$backup_file" ]] || [[ ! -f "$backup_file" ]]; then
        backup_log "ERROR" "No backup found for: $file_path (timestamp: $backup_timestamp)"
        return 1
    fi
    
    # Check if target file exists and we're not forcing
    if [[ -f "$file_path" ]] && [[ "$force" != "true" ]]; then
        backup_log "WARN" "Target file exists and force not specified: $file_path"
        return 1
    fi
    
    backup_log "INFO" "Restoring file from backup: $backup_file -> $file_path"
    
    # Create backup of current file before restore
    if [[ -f "$file_path" ]]; then
        local pre_restore_backup="${file_path}.pre-restore.$(date +%Y%m%d_%H%M%S)"
        cp "$file_path" "$pre_restore_backup" 2>/dev/null || {
            backup_log "WARN" "Failed to create pre-restore backup"
        }
    fi
    
    # Restore file
    local restore_success=false
    
    if [[ "$backup_file" =~ \.gz$ ]] && command -v gunzip >/dev/null 2>&1; then
        # Decompress and restore
        if gunzip -c "$backup_file" > "$file_path" 2>/dev/null; then
            restore_success=true
        fi
    else
        # Direct copy
        if atomic_write_file "$backup_file" "$file_path" false 644; then
            restore_success=true
        fi
    fi
    
    if [[ "$restore_success" == "true" ]]; then
        backup_log "SUCCESS" "File restored successfully: $file_path"
        
        # Update stats
        if command -v safe_json_update >/dev/null 2>&1; then
            local update_script="data['stats']['files_restored'] = data.get('stats', {}).get('files_restored', 0) + 1"
            safe_json_update "$CONFIG_BACKUP_CONFIG" "$update_script" >/dev/null 2>&1
        fi
        
        return 0
    else
        backup_log "ERROR" "Failed to restore file: $file_path"
        return 1
    fi
}

# Backup all configuration files
backup_all_configs() {
    local force="${1:-false}"
    local backed_up_count=0
    local failed_count=0
    
    backup_log "INFO" "Starting backup of all configuration files"
    
    # Backup files by pattern
    for pattern in "${!CONFIG_FILES[@]}"; do
        local priority="${CONFIG_FILES[$pattern]}"
        
        # Handle glob patterns
        if [[ "$pattern" == *"*"* ]]; then
            while IFS= read -r -d '' file_path; do
                if create_backup "$file_path" "$priority" "$force"; then
                    ((backed_up_count++))
                else
                    ((failed_count++))
                fi
            done < <(find "$WORKSPACE_DIR" -path "*/$pattern" -type f -print0 2>/dev/null)
        else
            # Handle direct file paths
            local file_path="$WORKSPACE_DIR/$pattern"
            if [[ -f "$file_path" ]]; then
                if create_backup "$file_path" "$priority" "$force"; then
                    ((backed_up_count++))
                else
                    ((failed_count++))
                fi
            fi
        fi
    done
    
    backup_log "INFO" "Backup completed: $backed_up_count files backed up, $failed_count failed"
    
    # Update overall stats
    if command -v safe_json_update >/dev/null 2>&1; then
        local update_script="data['stats']['files_backed_up'] = data.get('stats', {}).get('files_backed_up', 0) + $backed_up_count"
        safe_json_update "$CONFIG_BACKUP_CONFIG" "$update_script" >/dev/null 2>&1
    fi
    
    if [[ $failed_count -eq 0 ]]; then
        return 0
    else
        return 1
    fi
}

# Cleanup all old backups
cleanup_all_backups() {
    local force="${1:-false}"
    backup_log "INFO" "Starting cleanup of old backups"
    
    for pattern in "${!CONFIG_FILES[@]}"; do
        # Handle glob patterns
        if [[ "$pattern" == *"*"* ]]; then
            while IFS= read -r -d '' file_path; do
                cleanup_old_backups_for_file "$file_path"
            done < <(find "$WORKSPACE_DIR" -path "*/$pattern" -type f -print0 2>/dev/null)
        else
            # Handle direct file paths
            local file_path="$WORKSPACE_DIR/$pattern"
            if [[ -f "$file_path" ]] || [[ "$force" == "true" ]]; then
                cleanup_old_backups_for_file "$file_path"
            fi
        fi
    done
    
    backup_log "INFO" "Backup cleanup completed"
}

# Show backup status
show_backup_status() {
    echo -e "${BLUE}Configuration Backup Manager Status${NC}"
    echo
    
    if [[ -f "$CONFIG_BACKUP_CONFIG" ]]; then
        local config_data
        if command -v safe_json_read >/dev/null 2>&1; then
            config_data=$(safe_json_read "$CONFIG_BACKUP_CONFIG" "{}")
        else
            config_data=$(cat "$CONFIG_BACKUP_CONFIG" 2>/dev/null || echo "{}")
        fi
        
        echo "Configuration version: $(echo "$config_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version', 'unknown'))" 2>/dev/null)"
        echo "Files backed up: $(echo "$config_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('files_backed_up', 0))" 2>/dev/null)"
        echo "Backups created: $(echo "$config_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('backups_created', 0))" 2>/dev/null)"
        echo "Backups cleaned: $(echo "$config_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('backups_cleaned', 0))" 2>/dev/null)"
        echo "Files restored: $(echo "$config_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('files_restored', 0))" 2>/dev/null)"
        echo "Last backup: $(echo "$config_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('last_backup', 'never'))" 2>/dev/null)"
    else
        echo "Configuration not initialized"
    fi
    
    echo
    echo "Storage usage:"
    if [[ -d "$BACKUP_ROOT/files" ]]; then
        local backup_size=$(du -sh "$BACKUP_ROOT/files" 2>/dev/null | cut -f1)
        local backup_count=$(find "$BACKUP_ROOT/files" -type f 2>/dev/null | wc -l)
        echo "  Backup files: $backup_count files, $backup_size"
    fi
    
    echo
    echo "Configuration files tracked:"
    for pattern in "${!CONFIG_FILES[@]}"; do
        local priority="${CONFIG_FILES[$pattern]}"
        local status="❌"
        
        if [[ "$pattern" == *"*"* ]]; then
            local file_count=$(find "$WORKSPACE_DIR" -path "*/$pattern" -type f 2>/dev/null | wc -l)
            if [[ $file_count -gt 0 ]]; then
                status="✅ ($file_count files)"
            fi
        else
            if [[ -f "$WORKSPACE_DIR/$pattern" ]]; then
                status="✅"
            fi
        fi
        
        echo "  $pattern [$priority]: $status"
    done
    
    # Recent activity
    if [[ -f "$BACKUP_LOG" ]]; then
        echo
        echo "Recent activity:"
        tail -5 "$BACKUP_LOG" | while read -r line; do
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

# Test backup system
test_backup_system() {
    echo -e "${BLUE}Testing Configuration Backup System...${NC}"
    
    local test_dir="$WORKSPACE_DIR/.claude/test-backup"
    local test_file="$test_dir/test-config.json"
    
    mkdir -p "$test_dir"
    echo '{"test": true, "backup_test": true}' > "$test_file"
    
    # Test backup creation
    echo "Testing backup creation..."
    if create_backup "$test_file" "test" true; then
        echo -e "${GREEN}✓ Backup creation test passed${NC}"
    else
        echo -e "${RED}✗ Backup creation test failed${NC}"
        return 1
    fi
    
    # Test file restoration
    echo "Testing file restoration..."
    echo '{"test": true, "modified": true}' > "$test_file"
    
    if restore_file "$test_file" "latest" true; then
        local content=$(cat "$test_file" 2>/dev/null)
        if [[ "$content" == *"backup_test"* ]]; then
            echo -e "${GREEN}✓ File restoration test passed${NC}"
        else
            echo -e "${RED}✗ File restoration test failed: content not restored correctly${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ File restoration test failed${NC}"
        return 1
    fi
    
    # Test backup cleanup
    echo "Testing backup cleanup..."
    if cleanup_old_backups_for_file "$test_file"; then
        echo -e "${GREEN}✓ Backup cleanup test passed${NC}"
    else
        echo -e "${RED}✗ Backup cleanup test failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo -e "${GREEN}All backup system tests passed!${NC}"
    return 0
}

# Command-line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "test")
            test_backup_system
            ;;
        "status")
            show_backup_status
            ;;
        "init")
            init_backup_config
            echo "Backup system initialized"
            ;;
        "backup-all")
            backup_all_configs "${2:-false}"
            ;;
        "backup")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 backup <file_path> [priority] [force]"
                exit 1
            fi
            create_backup "$2" "${3:-normal}" "${4:-false}"
            ;;
        "restore")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 restore <file_path> [timestamp] [force]"
                exit 1
            fi
            restore_file "$2" "${3:-latest}" "${4:-false}"
            ;;
        "cleanup")
            cleanup_all_backups "${2:-false}"
            ;;
        "help"|"--help"|"-h")
            echo "Configuration Backup Manager - Automatic backup strategy for config files"
            echo
            echo "Usage: $0 [command] [options]"
            echo
            echo "Commands:"
            echo "  test                              - Run tests"
            echo "  status                            - Show status"
            echo "  init                              - Initialize backup system"
            echo "  backup-all [force]                - Backup all configuration files"
            echo "  backup <file> [priority] [force]  - Backup specific file"
            echo "  restore <file> [timestamp] [force] - Restore file from backup"
            echo "  cleanup [force]                   - Clean up old backups"
            echo
            echo "Shell functions available:"
            echo "  create_backup <file> [priority] [force]"
            echo "  restore_file <file> [timestamp] [force]"
            echo "  backup_all_configs [force]"
            echo "  cleanup_all_backups [force]"
            ;;
        "")
            echo "Source this script to use configuration backup functions"
            echo "Run '$0 help' for usage information"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
fi