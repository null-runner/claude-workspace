#!/bin/bash
# Claude Log Rotator - Sistema di rotazione automatica per file di log
# Gestisce log rotation con compressione, archivio, e cleanup intelligente

WORKSPACE_DIR="$HOME/claude-workspace"
CLAUDE_DIR="$WORKSPACE_DIR/.claude"
LOG_CONFIG="$CLAUDE_DIR/logs/rotation-config.json"
ROTATION_LOG="$CLAUDE_DIR/logs/log-rotation.log"
ARCHIVE_DIR="$CLAUDE_DIR/logs/archive"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup directories
mkdir -p "$CLAUDE_DIR/logs" "$ARCHIVE_DIR"

# Logging function
log_rotation() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$ROTATION_LOG"
    
    if [[ "$level" == "ERROR" || "$level" == "WARN" ]]; then
        echo -e "${RED}[LOG-ROTATOR]${NC} $message" >&2
    elif [[ "$level" == "INFO" ]]; then
        echo -e "${CYAN}[LOG-ROTATOR]${NC} $message"
    fi
}

# Crea configurazione di default
create_default_config() {
    if [[ ! -f "$LOG_CONFIG" ]]; then
        cat > "$LOG_CONFIG" << 'EOF'
{
  "rotation_policies": {
    "daily_logs": {
      "max_size_mb": 10,
      "keep_files": 7,
      "compress_after_days": 1,
      "patterns": [
        "*.log",
        "*-output.log",
        "*-error.log"
      ]
    },
    "system_logs": {
      "max_size_mb": 50,
      "keep_files": 30,
      "compress_after_days": 3,
      "patterns": [
        "autonomous-system.log",
        "coordinator.log",
        "smart-sync*.log"
      ]
    },
    "debug_logs": {
      "max_size_mb": 5,
      "keep_files": 3,
      "compress_after_days": 0,
      "patterns": [
        "*debug*.log",
        "*trace*.log",
        "*test*.log"
      ]
    }
  },
  "compression": {
    "enabled": true,
    "method": "gzip",
    "level": 6,
    "delete_original": true
  },
  "archive": {
    "enabled": true,
    "max_archive_size_mb": 100,
    "cleanup_older_than_days": 90
  },
  "safety": {
    "min_free_space_mb": 50,
    "verify_before_delete": true,
    "backup_before_rotation": false
  }
}
EOF
        log_rotation "INFO" "Created default log rotation configuration"
    fi
}

# Carica configurazione
load_config() {
    if [[ ! -f "$LOG_CONFIG" ]]; then
        create_default_config
    fi
    
    # Verifica JSON valido
    if ! python3 -c "import json; json.load(open('$LOG_CONFIG'))" 2>/dev/null; then
        log_rotation "ERROR" "Invalid JSON in config file, recreating defaults"
        rm -f "$LOG_CONFIG"
        create_default_config
    fi
}

# Ottieni dimensione file in MB
get_file_size_mb() {
    local file="$1"
    if [[ -f "$file" ]]; then
        local size_bytes=$(stat -c%s "$file" 2>/dev/null || echo 0)
        echo $((size_bytes / 1024 / 1024))
    else
        echo 0
    fi
}

# Comprimi file di log
compress_log() {
    local file="$1"
    local compressed_file="${file}.gz"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    # Verifica se già compresso
    if [[ -f "$compressed_file" ]]; then
        log_rotation "WARN" "Compressed file already exists: $compressed_file"
        return 1
    fi
    
    # Comprimi
    if gzip -c "$file" > "$compressed_file" 2>/dev/null; then
        log_rotation "INFO" "Compressed: $file -> $compressed_file"
        
        # Rimuovi originale se richiesto
        local delete_original=$(python3 -c "
import json
config = json.load(open('$LOG_CONFIG'))
print(config.get('compression', {}).get('delete_original', True))
" 2>/dev/null)
        
        if [[ "$delete_original" == "True" ]]; then
            rm -f "$file"
            log_rotation "INFO" "Deleted original: $file"
        fi
        
        return 0
    else
        log_rotation "ERROR" "Failed to compress: $file"
        rm -f "$compressed_file" 2>/dev/null
        return 1
    fi
}

# Ruota un singolo log file
rotate_log_file() {
    local file="$1"
    local max_size_mb="$2"
    local keep_files="$3"
    local compress_after_days="$4"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    local file_size_mb=$(get_file_size_mb "$file")
    local file_age_days=$(( ($(date +%s) - $(stat -c %Y "$file")) / 86400 ))
    local basename=$(basename "$file")
    local dirname=$(dirname "$file")
    
    # Controlla se il file necessita rotazione
    local needs_rotation=false
    
    if [[ $file_size_mb -gt $max_size_mb ]]; then
        log_rotation "INFO" "File $file exceeds size limit: ${file_size_mb}MB > ${max_size_mb}MB"
        needs_rotation=true
    fi
    
    # Rotazione basata su dimensione
    if [[ "$needs_rotation" == "true" ]]; then
        # Trova il prossimo numero di rotazione
        local rotation_num=1
        while [[ -f "${file}.${rotation_num}" ]] || [[ -f "${file}.${rotation_num}.gz" ]]; do
            ((rotation_num++))
        done
        
        # Sposta file corrente
        local rotated_file="${file}.${rotation_num}"
        if mv "$file" "$rotated_file" 2>/dev/null; then
            log_rotation "INFO" "Rotated: $file -> $rotated_file"
            
            # Comprimi file ruotato se necessario
            if [[ $compress_after_days -eq 0 ]] || [[ $file_age_days -ge $compress_after_days ]]; then
                compress_log "$rotated_file"
            fi
            
            # Ricrea file di log vuoto con permessi corretti
            touch "$file"
            chmod 644 "$file"
        else
            log_rotation "ERROR" "Failed to rotate: $file"
            return 1
        fi
    fi
    
    # Comprimi file vecchi
    if [[ $compress_after_days -gt 0 ]]; then
        for old_file in "${file}".* "${dirname}/${basename}".*; do
            if [[ -f "$old_file" ]] && [[ "$old_file" != *.gz ]]; then
                local old_age_days=$(( ($(date +%s) - $(stat -c %Y "$old_file")) / 86400 ))
                if [[ $old_age_days -ge $compress_after_days ]]; then
                    compress_log "$old_file"
                fi
            fi
        done
    fi
    
    # Cleanup file vecchi
    cleanup_old_rotations "$file" "$keep_files"
}

# Cleanup rotazioni vecchie
cleanup_old_rotations() {
    local base_file="$1"
    local keep_files="$2"
    local basename=$(basename "$base_file")
    local dirname=$(dirname "$base_file")
    
    # Trova tutti i file ruotati (compressi e non)
    local rotated_files=()
    while IFS= read -r -d '' file; do
        rotated_files+=("$file")
    done < <(find "$dirname" -name "${basename}.*" -print0 2>/dev/null | sort -z)
    
    # Se abbiamo più file di quelli da mantenere
    if [[ ${#rotated_files[@]} -gt $keep_files ]]; then
        local files_to_delete=$((${#rotated_files[@]} - keep_files))
        log_rotation "INFO" "Cleaning up $files_to_delete old rotations of $basename"
        
        # Rimuovi i file più vecchi
        for ((i=0; i<files_to_delete; i++)); do
            local file_to_delete="${rotated_files[i]}"
            if rm -f "$file_to_delete" 2>/dev/null; then
                log_rotation "INFO" "Deleted old rotation: $file_to_delete"
            else
                log_rotation "ERROR" "Failed to delete: $file_to_delete"
            fi
        done
    fi
}

# Archivia log molto vecchi
archive_old_logs() {
    local archive_days=$(python3 -c "
import json
config = json.load(open('$LOG_CONFIG'))
print(config.get('archive', {}).get('cleanup_older_than_days', 90))
" 2>/dev/null || echo 90)
    
    log_rotation "INFO" "Archiving logs older than $archive_days days"
    
    # Trova log molto vecchi
    while IFS= read -r -d '' file; do
        if [[ -f "$file" ]]; then
            local file_age_days=$(( ($(date +%s) - $(stat -c %Y "$file")) / 86400 ))
            
            if [[ $file_age_days -gt $archive_days ]]; then
                local archive_name="archive-$(date +%Y%m)-$(basename "$file")"
                local archive_path="$ARCHIVE_DIR/$archive_name"
                
                # Sposta in archivio
                if mv "$file" "$archive_path" 2>/dev/null; then
                    log_rotation "INFO" "Archived: $file -> $archive_path"
                    
                    # Comprimi se non già compresso
                    if [[ "$archive_path" != *.gz ]]; then
                        compress_log "$archive_path"
                    fi
                else
                    log_rotation "ERROR" "Failed to archive: $file"
                fi
            fi
        fi
    done < <(find "$CLAUDE_DIR" -name "*.log*" -print0 2>/dev/null)
}

# Cleanup archivio se troppo grande
cleanup_archive() {
    local max_archive_mb=$(python3 -c "
import json
config = json.load(open('$LOG_CONFIG'))
print(config.get('archive', {}).get('max_archive_size_mb', 100))
" 2>/dev/null || echo 100)
    
    # Calcola dimensione archivio
    local archive_size_mb=0
    if [[ -d "$ARCHIVE_DIR" ]]; then
        archive_size_mb=$(du -sm "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
    fi
    
    if [[ $archive_size_mb -gt $max_archive_mb ]]; then
        log_rotation "WARN" "Archive size exceeded: ${archive_size_mb}MB > ${max_archive_mb}MB"
        
        # Rimuovi file più vecchi dall'archivio
        while IFS= read -r -d '' file; do
            if rm -f "$file" 2>/dev/null; then
                log_rotation "INFO" "Deleted from archive: $file"
                
                # Ricalcola dimensione
                archive_size_mb=$(du -sm "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
                if [[ $archive_size_mb -le $max_archive_mb ]]; then
                    break
                fi
            fi
        done < <(find "$ARCHIVE_DIR" -type f -printf '%T@ %p\0' 2>/dev/null | sort -z | cut -d' ' -f2- -z)
    fi
}

# Rotazione completa
run_rotation() {
    local rotation_type="${1:-regular}"
    
    log_rotation "INFO" "Starting $rotation_type log rotation"
    load_config
    
    # Statistiche iniziali
    local total_logs=$(find "$CLAUDE_DIR" -name "*.log" | wc -l)
    local total_size_mb=$(du -sm "$CLAUDE_DIR" 2>/dev/null | cut -f1)
    
    log_rotation "INFO" "Found $total_logs log files, total size: ${total_size_mb}MB"
    
    # Processa ogni categoria di log
    local categories=("daily_logs" "system_logs" "debug_logs")
    
    for category in "${categories[@]}"; do
        log_rotation "INFO" "Processing category: $category"
        
        # Leggi configurazione categoria
        local config_data=$(python3 -c "
import json
config = json.load(open('$LOG_CONFIG'))
cat_config = config['rotation_policies']['$category']
print(f\"{cat_config['max_size_mb']}|{cat_config['keep_files']}|{cat_config['compress_after_days']}\")
for pattern in cat_config['patterns']:
    print(pattern)
" 2>/dev/null)
        
        if [[ -z "$config_data" ]]; then
            continue
        fi
        
        local params=$(echo "$config_data" | head -n1)
        IFS='|' read -r max_size keep_files compress_days <<< "$params"
        
        # Processa ogni pattern
        while IFS= read -r pattern; do
            if [[ -n "$pattern" ]] && [[ "$pattern" != *"|"* ]]; then
                log_rotation "INFO" "Processing pattern: $pattern"
                
                # Trova file che corrispondono al pattern
                while IFS= read -r -d '' file; do
                    if [[ -f "$file" ]]; then
                        rotate_log_file "$file" "$max_size" "$keep_files" "$compress_days"
                    fi
                done < <(find "$CLAUDE_DIR" -name "$pattern" -print0 2>/dev/null)
            fi
        done <<< "$(echo "$config_data" | tail -n +2)"
    done
    
    # Archiviazione e cleanup
    if [[ "$rotation_type" != "quick" ]]; then
        archive_old_logs
        cleanup_archive
    fi
    
    # Statistiche finali
    local final_logs=$(find "$CLAUDE_DIR" -name "*.log" | wc -l)
    local final_size_mb=$(du -sm "$CLAUDE_DIR" 2>/dev/null | cut -f1)
    local saved_mb=$((total_size_mb - final_size_mb))
    
    log_rotation "INFO" "Rotation completed: $total_logs -> $final_logs logs, ${total_size_mb}MB -> ${final_size_mb}MB (saved: ${saved_mb}MB)"
    
    # Salva statistiche
    echo "{\"last_rotation\": \"$(date -Iseconds)\", \"logs_processed\": $total_logs, \"space_saved_mb\": $saved_mb}" > "$CLAUDE_DIR/logs/last-rotation.json"
}

# Status rotazione
show_status() {
    echo -e "${CYAN}=== Log Rotation Status ===${NC}"
    
    local total_logs=$(find "$CLAUDE_DIR" -name "*.log*" | wc -l)
    local total_size_mb=$(du -sm "$CLAUDE_DIR" 2>/dev/null | cut -f1)
    local compressed_logs=$(find "$CLAUDE_DIR" -name "*.log.gz" | wc -l)
    
    echo -e "Total log files: ${YELLOW}$total_logs${NC}"
    echo -e "Compressed logs: ${YELLOW}$compressed_logs${NC}"
    echo -e "Total size: ${YELLOW}${total_size_mb}MB${NC}"
    
    if [[ -d "$ARCHIVE_DIR" ]]; then
        local archive_size_mb=$(du -sm "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
        local archive_files=$(find "$ARCHIVE_DIR" -type f | wc -l)
        echo -e "Archive: ${YELLOW}$archive_files${NC} files, ${YELLOW}${archive_size_mb}MB${NC}"
    fi
    
    if [[ -f "$CLAUDE_DIR/logs/last-rotation.json" ]]; then
        local last_rotation=$(python3 -c "
import json
data = json.load(open('$CLAUDE_DIR/logs/last-rotation.json'))
print(data.get('last_rotation', 'Never'))
" 2>/dev/null || echo "Never")
        echo -e "Last rotation: ${GREEN}$last_rotation${NC}"
    else
        echo -e "Last rotation: ${RED}Never${NC}"
    fi
    
    # Top 5 log files più grandi
    echo -e "\n${CYAN}=== Largest Log Files ===${NC}"
    find "$CLAUDE_DIR" -name "*.log*" -exec ls -lh {} \; 2>/dev/null | sort -k5 -hr | head -5 | while read -r line; do
        local size=$(echo "$line" | awk '{print $5}')
        local file=$(echo "$line" | awk '{print $NF}')
        echo -e "${YELLOW}$size${NC} $(basename "$file")"
    done
}

# Main
case "${1:-status}" in
    "rotate"|"run")
        run_rotation "regular"
        ;;
    "quick")
        run_rotation "quick"
        ;;
    "force")
        log_rotation "WARN" "Force rotation requested"
        run_rotation "force"
        ;;
    "status"|"info")
        show_status
        ;;
    "config")
        if [[ -n "$2" ]]; then
            case "$2" in
                "edit")
                    ${EDITOR:-nano} "$LOG_CONFIG"
                    ;;
                "reset")
                    rm -f "$LOG_CONFIG"
                    create_default_config
                    echo "Log rotation configuration reset to defaults"
                    ;;
                "show")
                    cat "$LOG_CONFIG"
                    ;;
            esac
        else
            echo "Usage: $0 config [edit|reset|show]"
        fi
        ;;
    "archive")
        case "${2:-list}" in
            "list")
                echo -e "${CYAN}=== Archived Logs ===${NC}"
                if [[ -d "$ARCHIVE_DIR" ]]; then
                    ls -lh "$ARCHIVE_DIR" 2>/dev/null || echo "No archived logs"
                else
                    echo "Archive directory does not exist"
                fi
                ;;
            "clean")
                cleanup_archive
                echo "Archive cleanup completed"
                ;;
        esac
        ;;
    "help"|"-h"|"--help")
        echo "Claude Log Rotator - Automated log rotation system"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  rotate, run       Run regular log rotation"
        echo "  quick             Quick rotation (no archiving)"
        echo "  force             Force rotation of all logs"
        echo "  status, info      Show rotation status and statistics"
        echo "  config edit       Edit rotation configuration"
        echo "  config reset      Reset configuration to defaults"
        echo "  config show       Show current configuration"
        echo "  archive list      List archived logs"
        echo "  archive clean     Clean up archive directory"
        echo "  help              Show this help message"
        echo ""
        echo "Configuration: $LOG_CONFIG"
        echo "Rotation log: $ROTATION_LOG"
        echo "Archive directory: $ARCHIVE_DIR"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac