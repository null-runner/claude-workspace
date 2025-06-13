#!/bin/bash
# Claude Backup Cleaner - Sistema di cleanup automatico per backup e file temporanei
# Sistema conservativo che mantiene backup importanti e pulisce solo file obsoleti

WORKSPACE_DIR="$HOME/claude-workspace"
CLAUDE_DIR="$WORKSPACE_DIR/.claude"
BACKUP_CONFIG="$CLAUDE_DIR/backup/cleanup-config.json"
BACKUP_LOG="$CLAUDE_DIR/backup/cleanup.log"

# Colori per output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup directories
mkdir -p "$CLAUDE_DIR/backup"

# Logging function
log_cleanup() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$BACKUP_LOG"
    
    if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo -e "${RED}[BACKUP-CLEANER]${NC} $message" >&2
    elif [[ "$level" == "INFO" ]]; then
        echo -e "${CYAN}[BACKUP-CLEANER]${NC} $message"
    fi
}

# Crea configurazione di default se non esiste
create_default_config() {
    if [[ ! -f "$BACKUP_CONFIG" ]]; then
        cat > "$BACKUP_CONFIG" << 'EOF'
{
  "retention_policies": {
    "daily_backups": {
      "keep_days": 7,
      "patterns": ["*.backup", "*-backup-*"]
    },
    "weekly_backups": {
      "keep_weeks": 4,
      "patterns": ["*weekly*", "*-week-*"]
    },
    "monthly_backups": {
      "keep_months": 6,
      "patterns": ["*monthly*", "*-month-*"]
    },
    "log_files": {
      "keep_days": 30,
      "max_size_mb": 100,
      "patterns": ["*.log", "*.log.*"]
    },
    "temp_files": {
      "keep_hours": 24,
      "patterns": ["*.tmp", "*.temp", "*~", ".#*"]
    }
  },
  "size_limits": {
    "max_backup_size_mb": 500,
    "emergency_cleanup_threshold_mb": 1000,
    "warning_threshold_mb": 250
  },
  "safety_settings": {
    "min_free_space_mb": 100,
    "verify_before_delete": true,
    "dry_run_mode": false,
    "preserve_critical_files": true
  },
  "critical_patterns": [
    "unified-context.json*",
    "session-history.json*",
    "intelligence-cache.json*",
    "config.json*",
    "service-status.json*"
  ]
}
EOF
        log_cleanup "INFO" "Created default backup cleanup configuration"
    fi
}

# Legge configurazione
load_config() {
    if [[ ! -f "$BACKUP_CONFIG" ]]; then
        create_default_config
    fi
    
    # Verifica JSON valido
    if ! python3 -c "import json; json.load(open('$BACKUP_CONFIG'))" 2>/dev/null; then
        log_cleanup "ERROR" "Invalid JSON in config file, recreating defaults"
        rm -f "$BACKUP_CONFIG"
        create_default_config
    fi
}

# Calcola spazio utilizzato dai backup
calculate_backup_size() {
    local total_size=0
    
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            local size=$(stat -c%s "$file" 2>/dev/null || echo 0)
            total_size=$((total_size + size))
        fi
    done < <(find "$CLAUDE_DIR" -name "*.backup" -o -name "*.bak" -o -name "*.log" -print0 2>/dev/null)
    
    echo $((total_size / 1024 / 1024)) # MB
}

# Verifica se un file è critico (non deve essere cancellato)
is_critical_file() {
    local file="$1"
    local basename=$(basename "$file")
    
    # Legge pattern critici dalla config
    local critical_patterns=$(python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
patterns = config.get('critical_patterns', [])
import fnmatch
filename = '$basename'
for pattern in patterns:
    if fnmatch.fnmatch(filename, pattern):
        print('CRITICAL')
        break
" 2>/dev/null)
    
    [[ "$critical_patterns" == "CRITICAL" ]]
}

# Safe delete con verifica
safe_delete() {
    local file="$1"
    local reason="$2"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    # Verifica se è un file critico
    if is_critical_file "$file"; then
        log_cleanup "WARN" "Skipping critical file: $file"
        return 1
    fi
    
    # Verifica integrità prima della cancellazione (per JSON)
    if [[ "$file" == *.json* ]]; then
        if ! python3 -c "import json; json.load(open('$file'))" 2>/dev/null; then
            log_cleanup "WARN" "File $file appears corrupted, safe to delete"
        fi
    fi
    
    # Dry run check
    local dry_run=$(python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
print(config.get('safety_settings', {}).get('dry_run_mode', False))
" 2>/dev/null)
    
    if [[ "$dry_run" == "True" ]]; then
        log_cleanup "INFO" "[DRY RUN] Would delete: $file ($reason)"
        return 0
    fi
    
    # Backup del file prima della cancellazione (per file importanti)
    if [[ "$file" == *context* ]] || [[ "$file" == *session* ]]; then
        local backup_name="${file}.pre-cleanup-$(date +%Y%m%d-%H%M%S)"
        if cp "$file" "$backup_name" 2>/dev/null; then
            log_cleanup "INFO" "Created safety backup: $backup_name"
        fi
    fi
    
    # Cancellazione effettiva
    if rm -f "$file" 2>/dev/null; then
        log_cleanup "INFO" "Deleted: $file ($reason)"
        return 0
    else
        log_cleanup "ERROR" "Failed to delete: $file"
        return 1
    fi
}

# Cleanup basato su età
cleanup_by_age() {
    local pattern="$1"
    local max_age_days="$2"
    local reason="$3"
    local deleted_count=0
    
    log_cleanup "INFO" "Cleaning files older than $max_age_days days: $pattern"
    
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            local file_age_days=$(( ($(date +%s) - $(stat -c %Y "$file")) / 86400 ))
            
            if [[ $file_age_days -gt $max_age_days ]]; then
                if safe_delete "$file" "$reason (${file_age_days}d old)"; then
                    ((deleted_count++))
                fi
            fi
        fi
    done < <(find "$CLAUDE_DIR" -name "$pattern" -print0 2>/dev/null)
    
    log_cleanup "INFO" "Cleaned $deleted_count files matching $pattern"
}

# Cleanup basato su dimensione
cleanup_by_size() {
    local max_size_mb="$1"
    local current_size_mb=$(calculate_backup_size)
    
    if [[ $current_size_mb -le $max_size_mb ]]; then
        log_cleanup "INFO" "Backup size OK: ${current_size_mb}MB (limit: ${max_size_mb}MB)"
        return 0
    fi
    
    log_cleanup "WARN" "Backup size exceeded: ${current_size_mb}MB > ${max_size_mb}MB"
    
    # Rimuovi prima i file temporanei
    cleanup_by_age "*.tmp" 0 "size cleanup - temp files"
    cleanup_by_age "*.temp" 0 "size cleanup - temp files"
    
    # Poi i log più vecchi
    cleanup_by_age "*.log" 7 "size cleanup - old logs"
    
    # Infine backup più vecchi (ma conservativi)
    cleanup_by_age "*.backup" 3 "size cleanup - old backups"
    
    local new_size_mb=$(calculate_backup_size)
    log_cleanup "INFO" "Size cleanup completed: ${current_size_mb}MB -> ${new_size_mb}MB"
}

# Cleanup routine completa
run_cleanup() {
    local cleanup_type="${1:-regular}"
    
    log_cleanup "INFO" "Starting $cleanup_type cleanup"
    load_config
    
    local current_size=$(calculate_backup_size)
    log_cleanup "INFO" "Current backup size: ${current_size}MB"
    
    # Lettura configurazione
    local keep_days=$(python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
print(config['retention_policies']['daily_backups']['keep_days'])
" 2>/dev/null || echo 7)
    
    local keep_log_days=$(python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
print(config['retention_policies']['log_files']['keep_days'])
" 2>/dev/null || echo 30)
    
    local max_size=$(python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
print(config['size_limits']['max_backup_size_mb'])
" 2>/dev/null || echo 500)
    
    # Cleanup regolare basato su età
    cleanup_by_age "*.backup" "$keep_days" "age policy"
    cleanup_by_age "*.bak" "$keep_days" "age policy"
    cleanup_by_age "*.tmp" 1 "temp files"
    cleanup_by_age "*.temp" 1 "temp files"
    cleanup_by_age "*~" 1 "editor temp files"
    
    # Cleanup log files (più conservativo)
    cleanup_by_age "*.log" "$keep_log_days" "log rotation"
    
    # Cleanup basato su dimensione se necessario
    if [[ "$cleanup_type" == "size" ]] || [[ $current_size -gt $max_size ]]; then
        cleanup_by_size "$max_size"
    fi
    
    # Statistiche finali
    local final_size=$(calculate_backup_size)
    local saved_mb=$((current_size - final_size))
    
    log_cleanup "INFO" "Cleanup completed: ${current_size}MB -> ${final_size}MB (saved: ${saved_mb}MB)"
    
    # Aggiorna timestamp ultima pulizia
    echo "{\"last_cleanup\": \"$(date -Iseconds)\", \"saved_mb\": $saved_mb}" > "$CLAUDE_DIR/backup/last-cleanup.json"
}

# Status e statistiche
show_status() {
    echo -e "${CYAN}=== Backup Cleanup Status ===${NC}"
    
    local current_size=$(calculate_backup_size)
    echo -e "Current backup size: ${YELLOW}${current_size}MB${NC}"
    
    local backup_count=$(find "$CLAUDE_DIR" -name "*.backup" | wc -l)
    local log_count=$(find "$CLAUDE_DIR" -name "*.log" | wc -l)
    
    echo -e "Backup files: ${YELLOW}$backup_count${NC}"
    echo -e "Log files: ${YELLOW}$log_count${NC}"
    
    if [[ -f "$CLAUDE_DIR/backup/last-cleanup.json" ]]; then
        local last_cleanup=$(python3 -c "
import json
data = json.load(open('$CLAUDE_DIR/backup/last-cleanup.json'))
print(data.get('last_cleanup', 'Never'))
" 2>/dev/null || echo "Never")
        echo -e "Last cleanup: ${GREEN}$last_cleanup${NC}"
    else
        echo -e "Last cleanup: ${RED}Never${NC}"
    fi
    
    # Spazio disco disponibile
    local free_space=$(df -BM "$WORKSPACE_DIR" | awk 'NR==2 {print $4}' | sed 's/M//')
    echo -e "Free space: ${GREEN}${free_space}MB${NC}"
    
    # Configurazione
    if [[ -f "$BACKUP_CONFIG" ]]; then
        echo -e "\n${CYAN}=== Configuration ===${NC}"
        local keep_days=$(python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
print('Daily backups:', config['retention_policies']['daily_backups']['keep_days'], 'days')
print('Log files:', config['retention_policies']['log_files']['keep_days'], 'days')
print('Max size:', config['size_limits']['max_backup_size_mb'], 'MB')
print('Dry run:', config['safety_settings']['dry_run_mode'])
" 2>/dev/null)
        echo "$keep_days"
    fi
}

# Main
case "${1:-status}" in
    "cleanup"|"clean")
        run_cleanup "regular"
        ;;
    "size-cleanup")
        run_cleanup "size"
        ;;
    "emergency")
        log_cleanup "WARN" "Emergency cleanup requested"
        run_cleanup "emergency"
        ;;
    "status"|"info")
        show_status
        ;;
    "config")
        if [[ -n "$2" ]]; then
            case "$2" in
                "edit")
                    ${EDITOR:-nano} "$BACKUP_CONFIG"
                    ;;
                "reset")
                    rm -f "$BACKUP_CONFIG"
                    create_default_config
                    echo "Configuration reset to defaults"
                    ;;
                "show")
                    cat "$BACKUP_CONFIG"
                    ;;
            esac
        else
            echo "Usage: $0 config [edit|reset|show]"
        fi
        ;;
    "dry-run")
        # Abilita dry run temporaneamente
        local temp_config=$(mktemp)
        python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
config['safety_settings']['dry_run_mode'] = True
json.dump(config, open('$temp_config', 'w'), indent=2)
" 2>/dev/null
        cp "$temp_config" "$BACKUP_CONFIG"
        run_cleanup "regular"
        # Ripristina configurazione
        python3 -c "
import json
config = json.load(open('$BACKUP_CONFIG'))
config['safety_settings']['dry_run_mode'] = False
json.dump(config, open('$BACKUP_CONFIG', 'w'), indent=2)
" 2>/dev/null
        rm -f "$temp_config"
        ;;
    "help"|"-h"|"--help")
        echo "Claude Backup Cleaner - Automated backup cleanup system"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  cleanup, clean    Run regular cleanup based on age policies"
        echo "  size-cleanup      Run size-based cleanup when space is low"
        echo "  emergency         Run aggressive cleanup (emergency mode)"
        echo "  status, info      Show backup status and statistics"
        echo "  dry-run           Show what would be deleted without actually deleting"
        echo "  config edit       Edit cleanup configuration"
        echo "  config reset      Reset configuration to defaults"
        echo "  config show       Show current configuration"
        echo "  help              Show this help message"
        echo ""
        echo "The system is conservative and preserves critical files."
        echo "Log file: $BACKUP_LOG"
        echo "Config file: $BACKUP_CONFIG"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac