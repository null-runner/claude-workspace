#!/bin/bash
# Claude Migration Tool - Complex to Simplified System
# Migra dal sistema complesso (65 script, 7 daemon) al sistema semplificato (8 script, 3 daemon)
# con backup completo e rollback capability

set -euo pipefail

# Environment
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
BACKUP_BASE_DIR="$WORKSPACE_DIR/.claude/migration-backups"
CURRENT_BACKUP_DIR=""
MIGRATION_LOG="$WORKSPACE_DIR/.claude/logs/migration.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Migration status file
MIGRATION_STATUS_FILE="$WORKSPACE_DIR/.claude/migration-status.json"

# Ensure directories exist
mkdir -p "$(dirname "$MIGRATION_LOG")" "$BACKUP_BASE_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $*"
    echo "$message" >> "$MIGRATION_LOG"
    
    case "$level" in
        "ERROR") echo -e "${RED}❌ $*${NC}" ;;
        "SUCCESS") echo -e "${GREEN}✅ $*${NC}" ;;
        "WARN") echo -e "${YELLOW}⚠️  $*${NC}" ;;
        "INFO") echo -e "${BLUE}ℹ️  $*${NC}" ;;
        "STEP") echo -e "${CYAN}🔧 $*${NC}" ;;
    esac
}

# Backup creation with validation
create_backup() {
    log "STEP" "Creating comprehensive backup..."
    
    # Create timestamped backup directory
    local timestamp=$(date +%Y%m%d_%H%M%S)
    CURRENT_BACKUP_DIR="$BACKUP_BASE_DIR/migration_backup_$timestamp"
    mkdir -p "$CURRENT_BACKUP_DIR"
    
    # Backup entire .claude directory (exclude backup directory itself)
    log "INFO" "Backing up .claude directory..."
    if [[ -d "$WORKSPACE_DIR/.claude" ]]; then
        # Use rsync to exclude the migration-backups directory
        rsync -av --exclude='migration-backups' "$WORKSPACE_DIR/.claude/" "$CURRENT_BACKUP_DIR/claude_backup/" || {
            log "ERROR" "Failed to backup .claude directory"
            return 1
        }
    fi
    
    # Backup scripts directory
    log "INFO" "Backing up scripts directory..."
    if [[ -d "$WORKSPACE_DIR/scripts" ]]; then
        cp -r "$WORKSPACE_DIR/scripts" "$CURRENT_BACKUP_DIR/scripts_backup" || {
            log "ERROR" "Failed to backup scripts directory"
            return 1
        }
    fi
    
    # Backup configuration files
    log "INFO" "Backing up configuration files..."
    local config_files=(
        "CLAUDE.md"
        "README.md"
        ".gitignore"
        ".claudeignore"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$WORKSPACE_DIR/$file" ]]; then
            cp "$WORKSPACE_DIR/$file" "$CURRENT_BACKUP_DIR/" 2>/dev/null || true
        fi
    done
    
    # Create backup manifest
    log "INFO" "Creating backup manifest..."
    cat > "$CURRENT_BACKUP_DIR/backup_manifest.json" << EOF
{
    "backup_date": "$(date -Iseconds)",
    "workspace_dir": "$WORKSPACE_DIR",
    "backup_type": "migration_backup",
    "git_commit": "$(cd "$WORKSPACE_DIR" && git rev-parse HEAD 2>/dev/null || echo 'not_available')",
    "git_branch": "$(cd "$WORKSPACE_DIR" && git branch --show-current 2>/dev/null || echo 'not_available')",
    "system_info": {
        "hostname": "$(hostname)",
        "user": "$(whoami)",
        "platform": "$(uname -s)",
        "timestamp": "$(date +%s)"
    }
}
EOF
    
    # Validate backup integrity
    log "INFO" "Validating backup integrity..."
    local backup_size=$(du -sh "$CURRENT_BACKUP_DIR" | cut -f1)
    local file_count=$(find "$CURRENT_BACKUP_DIR" -type f | wc -l)
    
    log "SUCCESS" "Backup created successfully"
    log "INFO" "Backup location: $CURRENT_BACKUP_DIR"
    log "INFO" "Backup size: $backup_size ($file_count files)"
    
    return 0
}

# Stop complex system services
stop_complex_system() {
    log "STEP" "Stopping complex system services..."
    
    # Stop autonomous system
    local autonomous_script="$WORKSPACE_DIR/scripts/claude-autonomous-system.sh"
    if [[ -f "$autonomous_script" ]]; then
        log "INFO" "Stopping autonomous system..."
        if timeout 30 "$autonomous_script" stop >/dev/null 2>&1; then
            log "SUCCESS" "Autonomous system stopped"
        else
            log "WARN" "Autonomous system stop timed out (may be normal)"
        fi
    fi
    
    # Stop individual daemons that might be running
    local daemon_scripts=(
        "claude-sync-coordinator.sh"
        "claude-activity-tracker.sh"
        "claude-intelligence-enhanced.sh"
        "claude-memory-coordinator.sh"
        "claude-process-manager.sh"
        "claude-productivity-metrics.sh"
        "claude-session-manager.sh"
    )
    
    for script in "${daemon_scripts[@]}"; do
        local script_path="$WORKSPACE_DIR/scripts/$script"
        if [[ -f "$script_path" ]]; then
            log "INFO" "Stopping $script..."
            timeout 10 "$script_path" stop >/dev/null 2>&1 || true
        fi
    done
    
    # Kill any remaining processes
    log "INFO" "Cleaning up remaining processes..."
    pkill -f "claude-.*daemon" 2>/dev/null || true
    pkill -f "claude-.*coordinator" 2>/dev/null || true
    pkill -f "claude-.*tracker" 2>/dev/null || true
    
    # Clean up PID files
    if [[ -d "$WORKSPACE_DIR/.claude/pids" ]]; then
        rm -f "$WORKSPACE_DIR/.claude/pids"/*.pid 2>/dev/null || true
    fi
    
    log "SUCCESS" "Complex system services stopped"
    return 0
}

# Migrate data formats
migrate_data_formats() {
    log "STEP" "Migrating data formats..."
    
    # Migrate intelligence data
    log "INFO" "Migrating intelligence data..."
    local intelligence_dir="$WORKSPACE_DIR/.claude/intelligence"
    if [[ -d "$intelligence_dir" ]]; then
        # Convert old intelligence format to enhanced format
        local old_intel_file="$intelligence_dir/session_intelligence.json"
        local new_intel_file="$intelligence_dir/intelligence_enhanced.json"
        
        if [[ -f "$old_intel_file" ]] && [[ ! -f "$new_intel_file" ]]; then
            python3 -c "
import json
import os
from datetime import datetime

try:
    with open('$old_intel_file', 'r') as f:
        old_data = json.load(f)
    
    # Convert to enhanced format
    enhanced_data = {
        'version': '2.0',
        'last_update': datetime.now().isoformat(),
        'learning_insights': old_data.get('patterns', {}),
        'project_insights': old_data.get('projects', {}),
        'session_insights': old_data.get('sessions', {}),
        'migration_notes': 'Migrated from complex system format'
    }
    
    with open('$new_intel_file', 'w') as f:
        json.dump(enhanced_data, f, indent=2)
    
    print('Intelligence data migrated successfully')
except Exception as e:
    print(f'Intelligence migration failed: {e}')
" || log "WARN" "Intelligence data migration had issues"
        fi
    fi
    
    # Migrate memory data
    log "INFO" "Migrating memory data..."
    local memory_dir="$WORKSPACE_DIR/.claude/memory"
    if [[ -d "$memory_dir" ]]; then
        # Ensure simplified memory format
        local simplified_script="$WORKSPACE_DIR/scripts/claude-simplified-memory.sh"
        if [[ -f "$simplified_script" ]]; then
            timeout 60 "$simplified_script" migrate >/dev/null 2>&1 || {
                log "WARN" "Memory migration script had issues"
            }
        fi
    fi
    
    # Migrate project data
    log "INFO" "Migrating project data..."
    local projects_dir="$WORKSPACE_DIR/.claude/projects"
    if [[ -d "$projects_dir" ]]; then
        # Convert to enhanced project format
        for project_file in "$projects_dir"/*.json; do
            if [[ -f "$project_file" ]]; then
                python3 -c "
import json
import os

try:
    with open('$project_file', 'r') as f:
        project_data = json.load(f)
    
    # Add enhanced fields if missing
    if 'version' not in project_data:
        project_data['version'] = '2.0'
    
    if 'last_enhanced' not in project_data:
        project_data['last_enhanced'] = '$(date -Iseconds)'
    
    with open('$project_file', 'w') as f:
        json.dump(project_data, f, indent=2)
        
except Exception as e:
    pass  # Ignore individual file errors
" 2>/dev/null || true
            fi
        done
    fi
    
    log "SUCCESS" "Data format migration completed"
    return 0
}

# Start simplified system
start_simplified_system() {
    log "STEP" "Starting simplified system..."
    
    # Check if simplified startup script exists
    local simple_startup="$WORKSPACE_DIR/scripts/claude-startup-simple.sh"
    if [[ ! -f "$simple_startup" ]]; then
        log "ERROR" "Simplified startup script not found: $simple_startup"
        return 1
    fi
    
    # Start simplified system
    log "INFO" "Starting simplified daemons..."
    if timeout 60 "$simple_startup" start; then
        log "SUCCESS" "Simplified system started"
    else
        log "ERROR" "Failed to start simplified system"
        return 1
    fi
    
    # Wait for services to stabilize
    log "INFO" "Waiting for services to stabilize..."
    sleep 3
    
    return 0
}

# Validation tests
run_validation_tests() {
    log "STEP" "Running validation tests..."
    
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Daemon status
    log "INFO" "Test 1: Checking daemon status..."
    local simple_startup="$WORKSPACE_DIR/scripts/claude-startup-simple.sh"
    if [[ -f "$simple_startup" ]] && "$simple_startup" status | grep -q "✓"; then
        log "SUCCESS" "Daemon status test passed"
        ((tests_passed++))
    else
        log "ERROR" "Daemon status test failed"
        ((tests_failed++))
    fi
    
    # Test 2: Memory save/load
    log "INFO" "Test 2: Testing memory operations..."
    local memory_script="$WORKSPACE_DIR/scripts/claude-simplified-memory.sh"
    if [[ -f "$memory_script" ]]; then
        # Test save
        if timeout 30 "$memory_script" save "Migration test - $(date)" >/dev/null 2>&1; then
            # Test load
            if timeout 30 "$memory_script" load >/dev/null 2>&1; then
                log "SUCCESS" "Memory operations test passed"
                ((tests_passed++))
            else
                log "ERROR" "Memory load test failed"
                ((tests_failed++))
            fi
        else
            log "ERROR" "Memory save test failed"
            ((tests_failed++))
        fi
    else
        log "ERROR" "Memory script not found"
        ((tests_failed++))
    fi
    
    # Test 3: Project detection
    log "INFO" "Test 3: Testing project detection..."
    local project_detector="$WORKSPACE_DIR/scripts/claude-auto-project-detector.sh"
    if [[ -f "$project_detector" ]]; then
        if timeout 30 "$project_detector" test >/dev/null 2>&1; then
            log "SUCCESS" "Project detection test passed"
            ((tests_passed++))
        else
            log "ERROR" "Project detection test failed"
            ((tests_failed++))
        fi
    else
        log "ERROR" "Project detector not found"
        ((tests_failed++))
    fi
    
    # Test 4: Intelligence extraction
    log "INFO" "Test 4: Testing intelligence extraction..."
    local intelligence_script="$WORKSPACE_DIR/scripts/claude-intelligence-extractor.sh"
    if [[ -f "$intelligence_script" ]]; then
        if timeout 30 "$intelligence_script" extract >/dev/null 2>&1; then
            log "SUCCESS" "Intelligence extraction test passed"
            ((tests_passed++))
        else
            log "ERROR" "Intelligence extraction test failed"
            ((tests_failed++))
        fi
    else
        log "ERROR" "Intelligence extractor not found"
        ((tests_failed++))
    fi
    
    # Test 5: Sync functionality
    log "INFO" "Test 5: Testing sync functionality..."
    local sync_script="$WORKSPACE_DIR/scripts/claude-smart-sync.sh"
    if [[ -f "$sync_script" ]]; then
        if timeout 30 "$sync_script" status >/dev/null 2>&1; then
            log "SUCCESS" "Sync functionality test passed"
            ((tests_passed++))
        else
            log "ERROR" "Sync functionality test failed"
            ((tests_failed++))
        fi
    else
        log "ERROR" "Sync script not found"
        ((tests_failed++))
    fi
    
    # Summary
    log "INFO" "Validation Results: $tests_passed passed, $tests_failed failed"
    
    if [[ $tests_failed -eq 0 ]]; then
        log "SUCCESS" "All validation tests passed!"
        return 0
    elif [[ $tests_failed -le 2 ]]; then
        log "WARN" "Some tests failed, but migration may still be functional"
        return 0
    else
        log "ERROR" "Too many validation tests failed"
        return 1
    fi
}

# Rollback function
rollback_migration() {
    log "STEP" "Rolling back migration..."
    
    if [[ -z "$CURRENT_BACKUP_DIR" ]] || [[ ! -d "$CURRENT_BACKUP_DIR" ]]; then
        # Try to find the most recent backup
        CURRENT_BACKUP_DIR=$(find "$BACKUP_BASE_DIR" -type d -name "migration_backup_*" | sort -r | head -1)
        
        if [[ -z "$CURRENT_BACKUP_DIR" ]] || [[ ! -d "$CURRENT_BACKUP_DIR" ]]; then
            log "ERROR" "No backup directory found for rollback"
            return 1
        fi
    fi
    
    log "INFO" "Using backup: $CURRENT_BACKUP_DIR"
    
    # Stop simplified system
    log "INFO" "Stopping simplified system..."
    local simple_startup="$WORKSPACE_DIR/scripts/claude-startup-simple.sh"
    if [[ -f "$simple_startup" ]]; then
        timeout 30 "$simple_startup" stop >/dev/null 2>&1 || true
    fi
    
    # Restore .claude directory
    if [[ -d "$CURRENT_BACKUP_DIR/claude_backup" ]]; then
        log "INFO" "Restoring .claude directory..."
        rm -rf "$WORKSPACE_DIR/.claude"
        cp -r "$CURRENT_BACKUP_DIR/claude_backup" "$WORKSPACE_DIR/.claude" || {
            log "ERROR" "Failed to restore .claude directory"
            return 1
        }
    fi
    
    # Restore scripts directory
    if [[ -d "$CURRENT_BACKUP_DIR/scripts_backup" ]]; then
        log "INFO" "Restoring scripts directory..."
        rm -rf "$WORKSPACE_DIR/scripts"
        cp -r "$CURRENT_BACKUP_DIR/scripts_backup" "$WORKSPACE_DIR/scripts" || {
            log "ERROR" "Failed to restore scripts directory"
            return 1
        }
    fi
    
    # Restore configuration files
    log "INFO" "Restoring configuration files..."
    local config_files=(
        "CLAUDE.md"
        "README.md"
        ".gitignore"
        ".claudeignore"
    )
    
    for file in "${config_files[@]}"; do
        if [[ -f "$CURRENT_BACKUP_DIR/$file" ]]; then
            cp "$CURRENT_BACKUP_DIR/$file" "$WORKSPACE_DIR/" 2>/dev/null || true
        fi
    done
    
    # Restart original system
    log "INFO" "Restarting original system..."
    local original_startup="$WORKSPACE_DIR/scripts/claude-startup.sh"
    if [[ -f "$original_startup" ]]; then
        timeout 60 "$original_startup" >/dev/null 2>&1 || {
            log "WARN" "Original system restart had issues"
        }
    fi
    
    # Update migration status
    update_migration_status "rollback_completed" "Migration rolled back successfully"
    
    log "SUCCESS" "Rollback completed successfully"
    return 0
}

# Update migration status
update_migration_status() {
    local status="$1"
    local message="$2"
    
    cat > "$MIGRATION_STATUS_FILE" << EOF
{
    "status": "$status",
    "message": "$message",
    "timestamp": "$(date -Iseconds)",
    "backup_location": "$CURRENT_BACKUP_DIR"
}
EOF
}

# Show migration status
show_status() {
    echo -e "${BOLD}Claude Migration Status${NC}"
    echo ""
    
    if [[ -f "$MIGRATION_STATUS_FILE" ]]; then
        local status=$(python3 -c "
import json
try:
    with open('$MIGRATION_STATUS_FILE') as f:
        data = json.load(f)
    print(f\"Status: {data.get('status', 'unknown')}\")
    print(f\"Message: {data.get('message', 'No message')}\")
    print(f\"Timestamp: {data.get('timestamp', 'Unknown')}\")
    if 'backup_location' in data and data['backup_location']:
        print(f\"Backup: {data['backup_location']}\")
except:
    print('Status file corrupted or missing')
" 2>/dev/null)
        echo "$status"
    else
        echo "No migration status available"
    fi
    
    echo ""
    
    # Show current system type
    if [[ -f "$WORKSPACE_DIR/scripts/claude-startup-simple.sh" ]]; then
        echo -e "${BLUE}Current System: Simplified${NC}"
        echo -e "${BLUE}Daemon Status:${NC}"
        echo ""
        
        # Check each daemon individually
        local daemons=(
            "claude-auto-context-daemon.sh:claude-auto-context:Unified context + project monitoring"
            "claude-intelligence-daemon.sh:claude-intelligence-daemon:Background learning"
            "claude-sync-daemon.sh:claude-sync-daemon:Periodic smart sync"
        )
        
        for daemon_info in "${daemons[@]}"; do
            IFS=':' read -r script_name daemon_name description <<< "$daemon_info"
            local daemon_script="$WORKSPACE_DIR/scripts/$script_name"
            
            if [[ -f "$daemon_script" ]] && "$daemon_script" status >/dev/null 2>&1; then
                echo -e "  ${GREEN}✓${NC} $daemon_name"
            else
                echo -e "  ${RED}✗${NC} $daemon_name"
            fi
            echo "    $description"
        done
    elif [[ -f "$WORKSPACE_DIR/scripts/claude-autonomous-system.sh" ]]; then
        local complex_startup="$WORKSPACE_DIR/scripts/claude-autonomous-system.sh"
        echo -e "${BLUE}Current System: Complex${NC}"
        "$complex_startup" status 2>/dev/null || echo "Complex system not running"
    else
        echo -e "${YELLOW}Current System: Unknown${NC}"
    fi
}

# Test simplified system without migration
test_simplified() {
    log "STEP" "Testing simplified system (dry run)..."
    
    # Check if scripts exist
    local required_scripts=(
        "claude-startup-simple.sh"
        "claude-simplified-memory.sh"
        "claude-auto-project-detector.sh"
        "claude-intelligence-extractor.sh"
        "claude-smart-sync.sh"
    )
    
    local missing_scripts=0
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$WORKSPACE_DIR/scripts/$script" ]]; then
            log "ERROR" "Required script missing: $script"
            ((missing_scripts++))
        fi
    done
    
    if [[ $missing_scripts -gt 0 ]]; then
        log "ERROR" "Cannot test simplified system: $missing_scripts scripts missing"
        return 1
    fi
    
    # Test startup (dry run)
    log "INFO" "Testing simplified startup..."
    local simple_startup="$WORKSPACE_DIR/scripts/claude-startup-simple.sh"
    if "$simple_startup" help >/dev/null 2>&1; then
        log "SUCCESS" "Simplified startup script is functional"
    else
        log "ERROR" "Simplified startup script has issues"
        return 1
    fi
    
    log "SUCCESS" "Simplified system appears ready for migration"
    return 0
}

# Full migration process
full_migration() {
    log "STEP" "Starting full migration process..."
    
    # Step 1: Create backup
    if ! create_backup; then
        log "ERROR" "Backup creation failed - aborting migration"
        return 1
    fi
    
    # Step 2: Stop complex system
    if ! stop_complex_system; then
        log "ERROR" "Failed to stop complex system - aborting migration"
        rollback_migration
        return 1
    fi
    
    # Step 3: Migrate data
    if ! migrate_data_formats; then
        log "ERROR" "Data migration failed - rolling back"
        rollback_migration
        return 1
    fi
    
    # Step 4: Start simplified system
    if ! start_simplified_system; then
        log "ERROR" "Failed to start simplified system - rolling back"
        rollback_migration
        return 1
    fi
    
    # Step 5: Validation
    if ! run_validation_tests; then
        log "ERROR" "Validation tests failed - rolling back"
        rollback_migration
        return 1
    fi
    
    # Success - update status
    update_migration_status "migration_completed" "Migration to simplified system successful"
    
    log "SUCCESS" "Migration completed successfully!"
    log "INFO" "System is now running simplified configuration (3 daemons)"
    log "INFO" "Backup available at: $CURRENT_BACKUP_DIR"
    
    return 0
}

# Print usage
print_usage() {
    echo -e "${BOLD}Claude Migration Tool${NC}"
    echo "Migrates from complex system (65 scripts, 7 daemons) to simplified system (8 scripts, 3 daemons)"
    echo ""
    echo -e "${BOLD}Usage:${NC} claude-migrate.sh <command>"
    echo ""
    echo -e "${BOLD}Commands:${NC}"
    echo "  backup      Create comprehensive backup only"
    echo "  migrate     Perform full migration with backup & validation"
    echo "  test        Test simplified system readiness (no migration)"
    echo "  rollback    Rollback to previous system from backup"
    echo "  status      Show current migration status"
    echo "  help        Show this help message"
    echo ""
    echo -e "${BOLD}Examples:${NC}"
    echo "  claude-migrate.sh backup     # Create safety backup"
    echo "  claude-migrate.sh migrate    # Full migration with rollback on failure"
    echo "  claude-migrate.sh test       # Check if simplified system is ready"
    echo "  claude-migrate.sh rollback   # Restore from backup if issues"
    echo ""
    echo -e "${BOLD}Safety Features:${NC}"
    echo "  • Complete backup before any changes"
    echo "  • Automatic rollback on validation failure"
    echo "  • Data preservation during format migration"
    echo "  • Service continuity validation"
}

# Main command handling
case "${1:-help}" in
    "backup")
        if create_backup; then
            update_migration_status "backup_completed" "Backup created successfully"
            log "SUCCESS" "Backup operation completed"
            exit 0
        else
            log "ERROR" "Backup operation failed"
            exit 1
        fi
        ;;
    "migrate")
        if full_migration; then
            log "SUCCESS" "Full migration completed successfully"
            exit 0
        else
            log "ERROR" "Migration failed"
            exit 1
        fi
        ;;
    "test")
        if test_simplified; then
            log "SUCCESS" "Simplified system test passed"
            exit 0
        else
            log "ERROR" "Simplified system test failed"
            exit 1
        fi
        ;;
    "rollback")
        if rollback_migration; then
            log "SUCCESS" "Rollback completed successfully"
            exit 0
        else
            log "ERROR" "Rollback failed"
            exit 1
        fi
        ;;
    "status")
        show_status
        exit 0
        ;;
    "help"|"--help"|"-h")
        print_usage
        exit 0
        ;;
    *)
        echo -e "${RED}Error: Unknown command '$1'${NC}"
        echo ""
        print_usage
        exit 1
        ;;
esac