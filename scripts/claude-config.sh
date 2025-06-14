#!/bin/bash

# Claude Configuration Management
# Simple, unified configuration system

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_DIR="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$WORKSPACE_DIR/.claude/config.json"
TEMP_DIR="$WORKSPACE_DIR/.claude/temp"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[CONFIG]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

# Ensure config file exists
ensure_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        error "Config file not found: $CONFIG_FILE"
        error "Run: ./scripts/claude-config.sh init"
        exit 1
    fi
}

# Get configuration value using jq
get_config() {
    local key="$1"
    local default="${2:-}"
    
    ensure_config
    
    local value
    value=$(jq -r "$key // \"$default\"" "$CONFIG_FILE" 2>/dev/null || echo "$default")
    
    if [[ "$value" == "null" ]]; then
        echo "$default"
    else
        echo "$value"
    fi
}

# Set configuration value
set_config() {
    local key="$1"
    local value="$2"
    
    ensure_config
    mkdir -p "$TEMP_DIR"
    
    local temp_file="$TEMP_DIR/config.json.tmp"
    
    # Handle different value types
    if [[ "$value" =~ ^[0-9]+$ ]]; then
        # Number
        jq "$key = $value" "$CONFIG_FILE" > "$temp_file"
    elif [[ "$value" == "true" || "$value" == "false" ]]; then
        # Boolean
        jq "$key = $value" "$CONFIG_FILE" > "$temp_file"
    else
        # String
        jq "$key = \"$value\"" "$CONFIG_FILE" > "$temp_file"
    fi
    
    # Atomic move
    mv "$temp_file" "$CONFIG_FILE"
    log "Set $key = $value"
}

# Show current configuration
show_config() {
    ensure_config
    echo -e "${BLUE}Current Configuration:${NC}"
    jq . "$CONFIG_FILE" | sed 's/^/  /'
}

# Device detection
detect_device() {
    local device_type="desktop"
    
    # Simple heuristics for device detection
    if [[ -f /sys/class/power_supply/BAT0/status ]] || [[ -f /sys/class/power_supply/BAT1/status ]]; then
        device_type="laptop"
    fi
    
    # Check if running in WSL (often desktop-like usage)
    if grep -qi microsoft /proc/version 2>/dev/null; then
        device_type="desktop"
    fi
    
    echo "$device_type"
}

# Apply device profile
apply_device_profile() {
    local device_type="${1:-$(detect_device)}"
    
    log "Applying $device_type profile..."
    
    case "$device_type" in
        "laptop")
            set_config '.device.type' 'laptop'
            set_config '.sync.sync_interval_minutes' '60'
            set_config '.logging.categories.debug.enabled' 'false'
            ;;
        "desktop")
            set_config '.device.type' 'desktop'
            set_config '.sync.sync_interval_minutes' '30'
            set_config '.logging.categories.debug.enabled' 'false'
            ;;
        *)
            warn "Unknown device type: $device_type"
            ;;
    esac
    
    log "Device profile applied: $device_type"
}

# Initialize configuration from defaults
init_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        warn "Config file already exists: $CONFIG_FILE"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log "Keeping existing configuration"
            return 0
        fi
    fi
    
    mkdir -p "$(dirname "$CONFIG_FILE")"
    
    # Copy default config (this should be created by the consolidation script)
    if [[ -f "$SCRIPT_DIR/../.claude/config.json" ]]; then
        cp "$SCRIPT_DIR/../.claude/config.json" "$CONFIG_FILE"
    else
        error "Default config not found"
        exit 1
    fi
    
    # Apply device-specific settings
    apply_device_profile
    
    log "Configuration initialized: $CONFIG_FILE"
}

# Get commonly used configurations with sensible defaults
get_sync_enabled() { get_config '.sync.enabled' 'true'; }
get_sync_interval() { get_config '.sync.sync_interval_minutes' '60'; }
get_memory_enabled() { get_config '.memory.enabled' 'true'; }
get_logging_level() { get_config '.logging.level' 'info'; }
get_backup_enabled() { get_config '.backup.enabled' 'true'; }
get_autonomous_enabled() { get_config '.autonomous.enabled' 'true'; }

# Validate configuration
validate() {
    ensure_config
    
    local errors=0
    
    # Check required fields
    local required_fields=(
        '.version'
        '.device.type'
        '.sync.enabled'
        '.memory.enabled'
        '.logging.level'
    )
    
    for field in "${required_fields[@]}"; do
        local value
        value=$(get_config "$field")
        if [[ -z "$value" || "$value" == "null" ]]; then
            error "Missing required field: $field"
            ((errors++))
        fi
    done
    
    # Validate sync interval
    local sync_interval
    sync_interval=$(get_config '.sync.sync_interval_minutes' '0')
    if [[ ! "$sync_interval" =~ ^[0-9]+$ ]] || [[ "$sync_interval" -lt 1 ]]; then
        error "Invalid sync interval: $sync_interval (must be positive integer)"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log "Configuration is valid"
        return 0
    else
        error "Configuration has $errors error(s)"
        return 1
    fi
}

# Backup current configuration
backup() {
    ensure_config
    
    local backup_dir="$WORKSPACE_DIR/.claude/config-backups"
    mkdir -p "$backup_dir"
    
    local timestamp
    timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_file="$backup_dir/config-$timestamp.json"
    
    cp "$CONFIG_FILE" "$backup_file"
    log "Configuration backed up to: $backup_file"
}

# Restore from backup
restore() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        error "Backup file not found: $backup_file"
        exit 1
    fi
    
    backup  # Backup current before restore
    cp "$backup_file" "$CONFIG_FILE"
    log "Configuration restored from: $backup_file"
}

# List available backups
list_backups() {
    local backup_dir="$WORKSPACE_DIR/.claude/config-backups"
    
    if [[ ! -d "$backup_dir" ]]; then
        log "No backups found"
        return 0
    fi
    
    echo -e "${BLUE}Available backups:${NC}"
    ls -la "$backup_dir"/config-*.json 2>/dev/null | sed 's/^/  /' || log "No backups found"
}

# Main command handler
main() {
    case "${1:-help}" in
        "init")
            init_config
            ;;
        "show"|"display")
            show_config
            ;;
        "get")
            if [[ $# -lt 2 ]]; then
                error "Usage: $0 get <key> [default]"
                exit 1
            fi
            get_config "$2" "${3:-}"
            ;;
        "set")
            if [[ $# -lt 3 ]]; then
                error "Usage: $0 set <key> <value>"
                exit 1
            fi
            set_config "$2" "$3"
            ;;
        "device")
            case "${2:-detect}" in
                "detect")
                    detect_device
                    ;;
                "apply")
                    apply_device_profile "${3:-}"
                    ;;
                *)
                    error "Usage: $0 device {detect|apply [type]}"
                    exit 1
                    ;;
            esac
            ;;
        "validate")
            validate
            ;;
        "backup")
            backup
            ;;
        "restore")
            if [[ $# -lt 2 ]]; then
                error "Usage: $0 restore <backup_file>"
                exit 1
            fi
            restore "$2"
            ;;
        "list-backups")
            list_backups
            ;;
        "help"|"--help"|"-h")
            cat << EOF
Claude Configuration Management

Usage: $0 <command> [arguments]

Commands:
  init                    Initialize configuration with defaults
  show                    Display current configuration
  get <key> [default]     Get configuration value
  set <key> <value>      Set configuration value
  device detect          Detect device type (desktop/laptop)
  device apply [type]    Apply device profile
  validate               Validate configuration
  backup                 Backup current configuration
  restore <file>         Restore from backup
  list-backups          List available backups
  help                   Show this help

Examples:
  $0 init
  $0 get .sync.enabled
  $0 set .sync.enabled false
  $0 device apply laptop
  $0 validate

Configuration file: $CONFIG_FILE
EOF
            ;;
        *)
            error "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

main "$@"