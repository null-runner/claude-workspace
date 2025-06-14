#!/bin/bash
# Claude Cleaner - Auto-cleanup for logs and cache with 1GB intelligence limit
# Conservative approach: compress old logs, clean temp cache, never touch user data

set -euo pipefail

# Environment
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
CLAUDE_DIR="$WORKSPACE_DIR/.claude"

# Time limits
LOG_COMPRESS_DAYS=7
BACKUP_CLEANUP_DAYS=30
CACHE_SIZE_LIMIT_MB=1024  # 1GB for intelligence cache

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Log function
log_cleanup() {
    echo -e "${BLUE}[CLEANUP]${NC} $*"
}

# Compress old logs
compress_old_logs() {
    log_cleanup "Compressing logs older than $LOG_COMPRESS_DAYS days..."
    
    local compressed=0
    while IFS= read -r -d '' file; do
        if [[ ! "$file" =~ \.gz$ ]]; then
            gzip "$file"
            ((compressed++))
        fi
    done < <(find "$CLAUDE_DIR/logs" -name "*.log" -type f -mtime +$LOG_COMPRESS_DAYS -print0 2>/dev/null)
    
    if [[ $compressed -gt 0 ]]; then
        log_cleanup "  Compressed $compressed log files"
    else
        log_cleanup "  No logs to compress"
    fi
}

# Clean old backup files (ONLY system backups, not user project backups)
clean_old_backups() {
    log_cleanup "Cleaning system backups older than $BACKUP_CLEANUP_DAYS days..."
    
    # Only clean specific system backup locations
    local cleaned=0
    
    # Clean old sync snapshots
    if [[ -d "$CLAUDE_DIR/sync/snapshots" ]]; then
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((cleaned++))
        done < <(find "$CLAUDE_DIR/sync/snapshots" -type f -mtime +$BACKUP_CLEANUP_DAYS -print0 2>/dev/null)
    fi
    
    # Clean old config backups
    if [[ -d "$CLAUDE_DIR/config-backups/files" ]]; then
        while IFS= read -r -d '' file; do
            rm -f "$file"
            ((cleaned++))
        done < <(find "$CLAUDE_DIR/config-backups/files" -name "*.backup.gz" -mtime +$BACKUP_CLEANUP_DAYS -print0 2>/dev/null)
    fi
    
    if [[ $cleaned -gt 0 ]]; then
        log_cleanup "  Removed $cleaned old backup files"
    else
        log_cleanup "  No old backups to clean"
    fi
}

# Optimize intelligence cache
optimize_intelligence_cache() {
    log_cleanup "Checking intelligence cache size..."
    
    local intel_dir="$CLAUDE_DIR/intelligence"
    if [[ ! -d "$intel_dir" ]]; then
        log_cleanup "  Intelligence directory not found"
        return
    fi
    
    # Get current size in MB
    local current_size_kb=$(du -sk "$intel_dir" 2>/dev/null | cut -f1)
    local current_size_mb=$((current_size_kb / 1024))
    
    log_cleanup "  Current size: ${current_size_mb}MB (limit: ${CACHE_SIZE_LIMIT_MB}MB)"
    
    if [[ $current_size_mb -gt $CACHE_SIZE_LIMIT_MB ]]; then
        log_cleanup "  ${YELLOW}Cache exceeds limit, optimizing...${NC}"
        
        # Remove old extraction logs
        find "$intel_dir" -name "extraction.log" -mtime +7 -delete 2>/dev/null || true
        
        # Compact large JSON files by removing old entries
        if command -v python3 >/dev/null 2>&1; then
            python3 -c "
import json
import os
from datetime import datetime, timedelta

intel_dir = '$intel_dir'
cutoff_date = (datetime.now() - timedelta(days=90)).isoformat()

# Process pattern files
for root, dirs, files in os.walk(intel_dir):
    for file in files:
        if file.endswith('.json') and os.path.getsize(os.path.join(root, file)) > 10*1024*1024:  # >10MB
            filepath = os.path.join(root, file)
            try:
                with open(filepath, 'r') as f:
                    data = json.load(f)
                
                # Keep only recent data
                if isinstance(data, list):
                    data = [item for item in data if item.get('timestamp', '9999') > cutoff_date]
                elif isinstance(data, dict) and 'entries' in data:
                    data['entries'] = [e for e in data['entries'] if e.get('timestamp', '9999') > cutoff_date]
                
                with open(filepath, 'w') as f:
                    json.dump(data, f, separators=(',', ':'))
                    
            except Exception:
                pass  # Skip problematic files
"
        fi
        
        # Check new size
        local new_size_kb=$(du -sk "$intel_dir" 2>/dev/null | cut -f1)
        local new_size_mb=$((new_size_kb / 1024))
        log_cleanup "  Optimized to ${new_size_mb}MB"
    fi
}

# Clean temporary files
clean_temp_files() {
    log_cleanup "Cleaning temporary files..."
    
    local cleaned=0
    
    # Clean empty log files
    find "$CLAUDE_DIR" -name "*.log" -empty -delete 2>/dev/null && ((cleaned++)) || true
    
    # Clean old pid files for dead processes
    if [[ -d "$CLAUDE_DIR/pids" ]]; then
        for pidfile in "$CLAUDE_DIR/pids"/*.pid; do
            if [[ -f "$pidfile" ]]; then
                local pid=$(cat "$pidfile" 2>/dev/null)
                if [[ -n "$pid" ]] && ! kill -0 "$pid" 2>/dev/null; then
                    rm -f "$pidfile"
                    ((cleaned++))
                fi
            fi
        done
    fi
    
    if [[ $cleaned -gt 0 ]]; then
        log_cleanup "  Cleaned $cleaned temporary files"
    else
        log_cleanup "  No temporary files to clean"
    fi
}

# Summary report
show_summary() {
    echo -e "\n${GREEN}Cleanup Summary:${NC}"
    
    # Show current sizes
    local log_size=$(du -sh "$CLAUDE_DIR/logs" 2>/dev/null | cut -f1 || echo "0")
    local intel_size=$(du -sh "$CLAUDE_DIR/intelligence" 2>/dev/null | cut -f1 || echo "0")
    local total_size=$(du -sh "$CLAUDE_DIR" 2>/dev/null | cut -f1 || echo "0")
    
    echo "  Logs: $log_size"
    echo "  Intelligence: $intel_size"
    echo "  Total .claude: $total_size"
}

# Main execution
main() {
    log_cleanup "Starting cleanup process..."
    
    compress_old_logs
    clean_old_backups
    optimize_intelligence_cache
    clean_temp_files
    
    show_summary
    
    log_cleanup "${GREEN}✓ Cleanup completed${NC}"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi