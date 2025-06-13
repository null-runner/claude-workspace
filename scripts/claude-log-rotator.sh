#!/bin/bash
# Claude Log Rotator - Automatic log rotation for workspace
# Keeps logs manageable and prevents unbounded growth

WORKSPACE_DIR="$HOME/claude-workspace"

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
MAX_LOG_LINES=5000       # Maximum lines before rotation
KEEP_LINES=1000          # Lines to keep after rotation
MAX_BACKUPS=3            # Number of backup files to keep

# Find all log files
LOG_DIRS=(
    "$WORKSPACE_DIR/.claude/logs"
    "$WORKSPACE_DIR/logs"
)

# Log function
log_rotation() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" >> "$WORKSPACE_DIR/.claude/logs/log-rotation.log"
    
    case "$level" in
        "INFO") echo -e "${BLUE}[LOG-ROTATE]${NC} $message" ;;
        "WARN") echo -e "${YELLOW}[LOG-ROTATE]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[LOG-ROTATE]${NC} $message" ;;
    esac
}

# Rotate a single log file
rotate_log() {
    local log_file="$1"
    local lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
    
    if [[ $lines -le $MAX_LOG_LINES ]]; then
        return 0  # No rotation needed
    fi
    
    log_rotation "INFO" "Rotating $log_file ($lines lines)"
    
    # Create backup directory if needed
    local backup_dir="$(dirname "$log_file")/.backups"
    mkdir -p "$backup_dir"
    
    # Rotate existing backups
    for ((i=$MAX_BACKUPS; i>=1; i--)); do
        local current_backup="$backup_dir/$(basename "$log_file").$i"
        local next_backup="$backup_dir/$(basename "$log_file").$((i+1))"
        
        if [[ -f "$current_backup" ]]; then
            if [[ $i -eq $MAX_BACKUPS ]]; then
                rm -f "$current_backup"
            else
                mv "$current_backup" "$next_backup"
            fi
        fi
    done
    
    # Create new backup from current log
    local first_backup="$backup_dir/$(basename "$log_file").1"
    cp "$log_file" "$first_backup"
    
    # Keep only recent lines in main log
    tail -n $KEEP_LINES "$log_file" > "$log_file.tmp"
    mv "$log_file.tmp" "$log_file"
    
    log_rotation "SUCCESS" "Rotated $log_file: kept $KEEP_LINES lines, backed up to $first_backup"
}

# Main rotation function
perform_rotation() {
    log_rotation "INFO" "Starting log rotation check"
    
    local rotated_count=0
    
    # Find all .log files in log directories
    for log_dir in "${LOG_DIRS[@]}"; do
        if [[ ! -d "$log_dir" ]]; then
            continue
        fi
        
        while IFS= read -r -d '' log_file; do
            # Skip our own rotation log to avoid recursion
            if [[ "$(basename "$log_file")" == "log-rotation.log" ]]; then
                continue
            fi
            
            # Skip backup directories
            if [[ "$log_file" == *"/.backups/"* ]]; then
                continue
            fi
            
            # Check if file needs rotation
            local lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            if [[ $lines -gt $MAX_LOG_LINES ]]; then
                rotate_log "$log_file"
                ((rotated_count++))
            fi
            
        done < <(find "$log_dir" -name "*.log" -type f -print0 2>/dev/null)
    done
    
    if [[ $rotated_count -eq 0 ]]; then
        log_rotation "INFO" "No logs needed rotation"
    else
        log_rotation "SUCCESS" "Rotated $rotated_count log files"
    fi
}

# Cleanup old backups (beyond MAX_BACKUPS)
cleanup_old_backups() {
    for log_dir in "${LOG_DIRS[@]}"; do
        local backup_dir="$log_dir/.backups"
        if [[ ! -d "$backup_dir" ]]; then
            continue
        fi
        
        # Find backup files numbered higher than MAX_BACKUPS
        while IFS= read -r -d '' backup_file; do
            local basename_file="$(basename "$backup_file")"
            if [[ "$basename_file" =~ \.([0-9]+)$ ]]; then
                local backup_num="${BASH_REMATCH[1]}"
                if [[ $backup_num -gt $MAX_BACKUPS ]]; then
                    rm -f "$backup_file"
                    log_rotation "INFO" "Cleaned up old backup: $backup_file"
                fi
            fi
        done < <(find "$backup_dir" -name "*.log.*" -type f -print0 2>/dev/null)
    done
}

# Status report
show_status() {
    echo -e "${BLUE}📊 Log Rotation Status${NC}"
    echo ""
    
    for log_dir in "${LOG_DIRS[@]}"; do
        if [[ ! -d "$log_dir" ]]; then
            continue
        fi
        
        echo -e "${YELLOW}Directory: $log_dir${NC}"
        
        while IFS= read -r -d '' log_file; do
            if [[ "$log_file" == *"/.backups/"* ]]; then
                continue
            fi
            
            local lines=$(wc -l < "$log_file" 2>/dev/null || echo "0")
            local size=$(du -h "$log_file" 2>/dev/null | cut -f1)
            local status="✅ OK"
            
            if [[ $lines -gt $MAX_LOG_LINES ]]; then
                status="⚠️  NEEDS ROTATION"
            fi
            
            echo "  $(basename "$log_file"): $lines lines ($size) $status"
            
        done < <(find "$log_dir" -name "*.log" -type f -print0 2>/dev/null)
        
        echo ""
    done
}

# Add rotation to sync scripts
integrate_with_sync() {
    local integration_added=false
    
    # Add rotation call to robust-sync if not present
    local robust_sync="$WORKSPACE_DIR/scripts/claude-robust-sync.sh"
    if [[ -f "$robust_sync" ]] && ! grep -q "claude-log-rotator" "$robust_sync"; then
        echo "    # Rotate logs periodically" >> "$robust_sync.tmp"
        echo "    if [[ \$((RANDOM % 10)) -eq 0 ]]; then" >> "$robust_sync.tmp"
        echo "        \"\$WORKSPACE_DIR/scripts/claude-log-rotator.sh\" rotate >/dev/null 2>&1 &" >> "$robust_sync.tmp"
        echo "    fi" >> "$robust_sync.tmp"
        echo "" >> "$robust_sync.tmp"
        
        # Insert before the end of the perform_robust_sync function
        awk '/^perform_robust_sync\(\)/{flag=1} flag && /^}$/{system("cat '$robust_sync.tmp'"); flag=0} {print}' "$robust_sync" > "$robust_sync.new"
        mv "$robust_sync.new" "$robust_sync"
        rm -f "$robust_sync.tmp"
        chmod +x "$robust_sync"
        
        integration_added=true
    fi
    
    if [[ "$integration_added" == true ]]; then
        log_rotation "SUCCESS" "Integrated log rotation with sync scripts"
    else
        log_rotation "INFO" "Log rotation already integrated"
    fi
}

# Command handling
case "${1:-}" in
    "rotate"|"")
        perform_rotation
        cleanup_old_backups
        ;;
    "status")
        show_status
        ;;
    "integrate")
        integrate_with_sync
        ;;
    "clean")
        cleanup_old_backups
        log_rotation "SUCCESS" "Cleaned up old backup files"
        ;;
    "help"|"--help"|"-h")
        echo "Claude Log Rotator - Automatic log rotation"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  rotate     Rotate logs that exceed $MAX_LOG_LINES lines (default)"
        echo "  status     Show current log status"
        echo "  integrate  Add rotation to sync scripts"
        echo "  clean      Clean up old backup files"
        echo "  help       Show this help"
        echo ""
        echo "Configuration:"
        echo "  Max lines: $MAX_LOG_LINES"
        echo "  Keep lines: $KEEP_LINES"
        echo "  Max backups: $MAX_BACKUPS"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac