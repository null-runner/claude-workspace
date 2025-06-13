#!/bin/bash
# Claude Workspace - Backup Cleanup System
# Multi-level backup retention and cleanup with atomic operations

WORKSPACE_DIR="$HOME/claude-workspace"
BACKUP_BASE_DIR="$WORKSPACE_DIR/.claude/backups"
TEMP_DIR="/tmp/claude-backup-cleanup-$$"
ATOMIC_TEMP_PREFIX="$TEMP_DIR/atomic"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Setup
mkdir -p "$BACKUP_BASE_DIR" "$TEMP_DIR"

# Cleanup on exit
cleanup_temp() {
    [[ -d "$TEMP_DIR" ]] && rm -rf "$TEMP_DIR"
}
trap cleanup_temp EXIT

# Atomic file operations
atomic_write() {
    local target_file="$1"
    local content="$2"
    local temp_file="${ATOMIC_TEMP_PREFIX}_$(basename "$target_file")_$(date +%s)"
    
    # Write to temp file first
    echo "$content" > "$temp_file"
    
    # Atomic move
    if mv "$temp_file" "$target_file"; then
        return 0
    else
        rm -f "$temp_file" 2>/dev/null
        return 1
    fi
}

atomic_json_write() {
    local target_file="$1"
    local json_content="$2"
    local temp_file="${ATOMIC_TEMP_PREFIX}_$(basename "$target_file")_$(date +%s).json"
    
    # Validate JSON first
    if echo "$json_content" | python3 -c "import json, sys; json.load(sys.stdin)" 2>/dev/null; then
        echo "$json_content" > "$temp_file"
        if mv "$temp_file" "$target_file"; then
            return 0
        else
            rm -f "$temp_file" 2>/dev/null
            return 1
        fi
    else
        echo "Invalid JSON content" >&2
        return 1
    fi
}

# Backup retention policy configuration
get_retention_policy() {
    cat << 'EOF'
{
  "levels": {
    "hourly": {
      "keep_count": 24,
      "max_age_hours": 24,
      "pattern": "backup_*_hourly_*.tar.gz"
    },
    "daily": {
      "keep_count": 30,
      "max_age_days": 30,
      "pattern": "backup_*_daily_*.tar.gz"
    },
    "weekly": {
      "keep_count": 12,
      "max_age_weeks": 12,
      "pattern": "backup_*_weekly_*.tar.gz"
    },
    "monthly": {
      "keep_count": 12,
      "max_age_months": 12,
      "pattern": "backup_*_monthly_*.tar.gz"
    }
  },
  "global_settings": {
    "max_total_size_gb": 5,
    "emergency_cleanup_threshold_gb": 10
  }
}
EOF
}

# Load retention policy
load_retention_policy() {
    local policy_file="$BACKUP_BASE_DIR/retention-policy.json"
    
    if [[ ! -f "$policy_file" ]]; then
        get_retention_policy | atomic_json_write "$policy_file" "$(cat)"
        echo -e "${GREEN}✅ Created retention policy at $policy_file${NC}"
    fi
    
    # Export policy for use in other functions
    export RETENTION_POLICY_FILE="$policy_file"
}

# Calculate directory size in GB
calculate_size_gb() {
    local dir="$1"
    if [[ -d "$dir" ]]; then
        du -s "$dir" | awk '{print $1/1024/1024}'
    else
        echo "0"
    fi
}

# Get backup age in days
get_backup_age_days() {
    local backup_file="$1"
    local file_date=$(stat -c%Y "$backup_file" 2>/dev/null || echo "0")
    local current_date=$(date +%s)
    echo $(( (current_date - file_date) / 86400 ))
}

# Clean backups by level
clean_backup_level() {
    local level="$1"
    local backup_dir="$BACKUP_BASE_DIR"
    
    echo -e "${BLUE}🧹 Cleaning $level backups...${NC}"
    
    # Get retention config for this level
    local level_config=$(python3 << EOF
import json
with open('$RETENTION_POLICY_FILE', 'r') as f:
    policy = json.load(f)
level_policy = policy['levels']['$level']
print(f"{level_policy['keep_count']}:{level_policy['pattern']}")
EOF
)
    
    local keep_count=$(echo "$level_config" | cut -d: -f1)
    local pattern=$(echo "$level_config" | cut -d: -f2)
    
    # Find backup files for this level
    local backup_files=()
    if [[ -d "$backup_dir" ]]; then
        while IFS= read -r -d '' file; do
            backup_files+=("$file")
        done < <(find "$backup_dir" -name "$pattern" -type f -print0 2>/dev/null)
    fi
    
    local total_files=${#backup_files[@]}
    
    if [[ $total_files -eq 0 ]]; then
        echo "   No $level backups found"
        return 0
    fi
    
    echo "   Found $total_files $level backup(s)"
    
    # Sort by modification time (newest first)
    local sorted_files=()
    while IFS= read -r -d '' file; do
        sorted_files+=("$file")
    done < <(printf '%s\0' "${backup_files[@]}" | sort -z -t $'\0' -k1,1nr)
    
    # Keep only the newest N files
    local files_to_delete=()
    local files_kept=0
    local files_deleted=0
    local size_freed=0
    
    for file in "${sorted_files[@]}"; do
        if [[ $files_kept -lt $keep_count ]]; then
            ((files_kept++))
            echo "   ✅ Keep: $(basename "$file")"
        else
            files_to_delete+=("$file")
        fi
    done
    
    # Delete excess files
    for file in "${files_to_delete[@]}"; do
        local file_size=$(du -k "$file" 2>/dev/null | cut -f1)
        if rm "$file" 2>/dev/null; then
            ((files_deleted++))
            size_freed=$((size_freed + file_size))
            echo "   🗑️  Deleted: $(basename "$file") ($(( file_size / 1024 ))MB)"
        else
            echo "   ❌ Failed to delete: $(basename "$file")"
        fi
    done
    
    echo "   📊 Summary: kept $files_kept, deleted $files_deleted files"
    if [[ $size_freed -gt 0 ]]; then
        echo "   💾 Space freed: $(( size_freed / 1024 ))MB"
    fi
}

# Emergency cleanup when disk space is critical
emergency_cleanup() {
    local force="$1"
    
    echo -e "${RED}🚨 EMERGENCY BACKUP CLEANUP${NC}"
    
    local total_size=$(calculate_size_gb "$BACKUP_BASE_DIR")
    local threshold=$(python3 -c "
import json
with open('$RETENTION_POLICY_FILE', 'r') as f:
    policy = json.load(f)
print(policy['global_settings']['emergency_cleanup_threshold_gb'])
")
    
    echo "📊 Current backup size: ${total_size}GB"
    echo "🚨 Emergency threshold: ${threshold}GB"
    
    if [[ $(echo "$total_size > $threshold" | bc -l) -eq 1 ]] || [[ "$force" == "--force" ]]; then
        echo -e "${YELLOW}⚠️  Running emergency cleanup...${NC}"
        
        # More aggressive cleanup
        local emergency_policy=$(cat << 'EOF_POLICY'
{
  "levels": {
    "hourly": {
      "keep_count": 6,
      "pattern": "backup_*_hourly_*.tar.gz"
    },
    "daily": {
      "keep_count": 7,
      "pattern": "backup_*_daily_*.tar.gz"
    },
    "weekly": {
      "keep_count": 4,
      "pattern": "backup_*_weekly_*.tar.gz"
    },
    "monthly": {
      "keep_count": 3,
      "pattern": "backup_*_monthly_*.tar.gz"
    }
  }
}
EOF_POLICY
)
        
        # Temporarily update policy
        local temp_policy_file="${ATOMIC_TEMP_PREFIX}_emergency_policy.json"
        echo "$emergency_policy" > "$temp_policy_file"
        local original_policy="$RETENTION_POLICY_FILE"
        export RETENTION_POLICY_FILE="$temp_policy_file"
        
        # Run aggressive cleanup
        clean_backup_level "hourly"
        clean_backup_level "daily"
        clean_backup_level "weekly"
        clean_backup_level "monthly"
        
        # Restore original policy
        export RETENTION_POLICY_FILE="$original_policy"
        rm -f "$temp_policy_file"
        
        # Final size check
        local new_size=$(calculate_size_gb "$BACKUP_BASE_DIR")
        local freed=$(echo "$total_size - $new_size" | bc -l)
        echo -e "${GREEN}✅ Emergency cleanup completed${NC}"
        echo "📊 New size: ${new_size}GB (freed ${freed}GB)"
    else
        echo "✅ No emergency cleanup needed"
    fi
}

# Clean old temporary files
clean_temp_files() {
    echo -e "${BLUE}🧹 Cleaning temporary files...${NC}"
    
    local temp_patterns=(
        "/tmp/claude-*"
        "/tmp/backup-*"
        "$WORKSPACE_DIR/.claude/*/tmp/*"
        "$WORKSPACE_DIR/.claude/*/*_temp_*"
    )
    
    local files_deleted=0
    local size_freed=0
    
    for pattern in "${temp_patterns[@]}"; do
        for file in $pattern; do
            if [[ -f "$file" ]]; then
                # Delete files older than 1 hour
                if find "$file" -mmin +60 2>/dev/null | grep -q .; then
                    local file_size=$(du -k "$file" 2>/dev/null | cut -f1 || echo "0")
                    if rm "$file" 2>/dev/null; then
                        ((files_deleted++))
                        size_freed=$((size_freed + file_size))
                    fi
                fi
            elif [[ -d "$file" ]]; then
                # Delete empty directories older than 1 hour
                if find "$file" -maxdepth 0 -empty -mmin +60 2>/dev/null | grep -q .; then
                    rmdir "$file" 2>/dev/null && ((files_deleted++))
                fi
            fi
        done
    done
    
    echo "   📊 Cleaned $files_deleted temporary files"
    if [[ $size_freed -gt 0 ]]; then
        echo "   💾 Space freed: $(( size_freed / 1024 ))MB"
    fi
}

# Full cleanup process
full_cleanup() {
    local force="$1"
    
    echo -e "${PURPLE}🧹 COMPREHENSIVE BACKUP CLEANUP${NC}"
    echo "=================================="
    
    load_retention_policy
    
    # Pre-cleanup stats
    local initial_size=$(calculate_size_gb "$BACKUP_BASE_DIR")
    echo "📊 Initial backup size: ${initial_size}GB"
    
    # Check if emergency cleanup is needed
    emergency_cleanup "$force"
    
    # Regular cleanup by level
    echo ""
    echo "🔄 Running regular cleanup..."
    clean_backup_level "hourly"
    clean_backup_level "daily"
    clean_backup_level "weekly"
    clean_backup_level "monthly"
    
    # Clean temp files
    echo ""
    clean_temp_files
    
    # Final stats
    local final_size=$(calculate_size_gb "$BACKUP_BASE_DIR")
    local total_freed=$(echo "$initial_size - $final_size" | bc -l)
    
    echo ""
    echo -e "${GREEN}✅ CLEANUP COMPLETED${NC}"
    echo "📊 Final backup size: ${final_size}GB"
    if [[ $(echo "$total_freed > 0" | bc -l) -eq 1 ]]; then
        echo "💾 Total space freed: ${total_freed}GB"
    else
        echo "💾 No space freed (already optimized)"
    fi
    
    # Update cleanup metadata
    local cleanup_metadata=$(cat << EOF
{
  "last_cleanup": "$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)",
  "initial_size_gb": $initial_size,
  "final_size_gb": $final_size,
  "space_freed_gb": $total_freed,
  "cleanup_type": "${force:+emergency}"
}
EOF
)
    
    atomic_json_write "$BACKUP_BASE_DIR/last-cleanup.json" "$cleanup_metadata"
}

# Show backup statistics
show_stats() {
    echo -e "${BLUE}📊 BACKUP STORAGE STATISTICS${NC}"
    echo "============================="
    
    load_retention_policy
    
    # Overall stats
    local total_size=$(calculate_size_gb "$BACKUP_BASE_DIR")
    echo "💾 Total backup size: ${total_size}GB"
    
    # Count by level
    echo ""
    echo "📁 Backup counts by level:"
    
    for level in hourly daily weekly monthly; do
        local pattern=$(python3 -c "
import json
with open('$RETENTION_POLICY_FILE', 'r') as f:
    policy = json.load(f)
print(policy['levels']['$level']['pattern'])
")
        
        local count=0
        if [[ -d "$BACKUP_BASE_DIR" ]]; then
            count=$(find "$BACKUP_BASE_DIR" -name "$pattern" -type f 2>/dev/null | wc -l)
        fi
        
        local keep_limit=$(python3 -c "
import json
with open('$RETENTION_POLICY_FILE', 'r') as f:
    policy = json.load(f)
print(policy['levels']['$level']['keep_count'])
")
        
        local status="✅"
        if [[ $count -gt $keep_limit ]]; then
            status="⚠️"
        fi
        
        echo "   $status $level: $count/$keep_limit files"
    done
    
    # Last cleanup info
    echo ""
    if [[ -f "$BACKUP_BASE_DIR/last-cleanup.json" ]]; then
        echo "🧹 Last cleanup info:"
        python3 << EOF
import json
from datetime import datetime
try:
    with open('$BACKUP_BASE_DIR/last-cleanup.json', 'r') as f:
        data = json.load(f)
    
    last_cleanup = data.get('last_cleanup', 'Unknown')
    if last_cleanup != 'Unknown':
        dt = datetime.fromisoformat(last_cleanup.replace('Z', '+00:00'))
        print(f"   📅 Date: {dt.strftime('%Y-%m-%d %H:%M:%S')}")
    
    space_freed = data.get('space_freed_gb', 0)
    if space_freed > 0:
        print(f"   💾 Space freed: {space_freed:.2f}GB")
    
    cleanup_type = data.get('cleanup_type', 'regular')
    print(f"   🔧 Type: {cleanup_type}")
    
except Exception as e:
    print(f"   ❌ Error reading cleanup data: {e}")
EOF
    else
        echo "🧹 No cleanup history found"
    fi
    
    # Show retention policy
    echo ""
    echo "⚙️  Current retention policy:"
    python3 << EOF
import json
with open('$RETENTION_POLICY_FILE', 'r') as f:
    policy = json.load(f)

for level, config in policy['levels'].items():
    print(f"   {level}: keep {config['keep_count']} files")

global_settings = policy['global_settings']
print(f"   Max total size: {global_settings['max_total_size_gb']}GB")
print(f"   Emergency threshold: {global_settings['emergency_cleanup_threshold_gb']}GB")
EOF
}

# Test cleanup (dry run)
test_cleanup() {
    echo -e "${YELLOW}🧪 TEST CLEANUP (DRY RUN)${NC}"
    echo "=========================="
    
    load_retention_policy
    
    echo "This would perform the following actions:"
    echo ""
    
    # Simulate each level
    for level in hourly daily weekly monthly; do
        echo -e "${BLUE}📋 $level backups:${NC}"
        
        local level_config=$(python3 << EOF
import json
with open('$RETENTION_POLICY_FILE', 'r') as f:
    policy = json.load(f)
level_policy = policy['levels']['$level']
print(f"{level_policy['keep_count']}:{level_policy['pattern']}")
EOF
)
        
        local keep_count=$(echo "$level_config" | cut -d: -f1)
        local pattern=$(echo "$level_config" | cut -d: -f2)
        
        # Find files
        local files=()
        if [[ -d "$BACKUP_BASE_DIR" ]]; then
            while IFS= read -r -d '' file; do
                files+=("$file")
            done < <(find "$BACKUP_BASE_DIR" -name "$pattern" -type f -print0 2>/dev/null)
        fi
        
        local total_files=${#files[@]}
        
        if [[ $total_files -eq 0 ]]; then
            echo "   No files found"
        elif [[ $total_files -le $keep_count ]]; then
            echo "   Keep all $total_files files (within limit)"
        else
            local to_delete=$((total_files - keep_count))
            echo "   Keep $keep_count files, DELETE $to_delete files"
        fi
        echo ""
    done
    
    echo -e "${CYAN}Use 'full --force' to actually perform cleanup${NC}"
}

# Help
show_help() {
    echo "Claude Backup Cleaner - Multi-level backup retention system"
    echo ""
    echo "Usage: claude-backup-cleaner [command] [options]"
    echo ""
    echo "Commands:"
    echo "  full [--force]           Run full cleanup process"
    echo "  emergency [--force]      Run emergency cleanup only"
    echo "  stats                    Show backup statistics"
    echo "  test                     Show what cleanup would do (dry run)"
    echo "  temp                     Clean temporary files only"
    echo ""
    echo "Retention Policy:"
    echo "  • Hourly: 24 backups (1 day)"
    echo "  • Daily: 30 backups (1 month)" 
    echo "  • Weekly: 12 backups (3 months)"
    echo "  • Monthly: 12 backups (1 year)"
    echo ""
    echo "Features:"
    echo "  ✅ Atomic file operations"
    echo "  ✅ Multi-level retention"
    echo "  ✅ Emergency cleanup"
    echo "  ✅ Temp file cleanup"
    echo "  ✅ Comprehensive statistics"
    echo ""
    echo "Examples:"
    echo "  claude-backup-cleaner stats"
    echo "  claude-backup-cleaner test"
    echo "  claude-backup-cleaner full"
}

# Main logic
case "${1:-}" in
    "full")
        full_cleanup "$2"
        ;;
    "emergency")
        load_retention_policy
        emergency_cleanup "$2"
        ;;
    "stats")
        show_stats
        ;;
    "test")
        test_cleanup
        ;;
    "temp")
        clean_temp_files
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_stats
        echo ""
        echo "Use 'claude-backup-cleaner help' for more options"
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac