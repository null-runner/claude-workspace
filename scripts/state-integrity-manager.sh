#!/bin/bash
# State Integrity Manager - Versioning and Consistency Checks for Critical Files
# Ensures system state integrity with versioning, validation, and recovery

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
INTEGRITY_DIR="$WORKSPACE_DIR/.claude/integrity"
VERSIONS_DIR="$INTEGRITY_DIR/versions"
CHECKSUMS_DIR="$INTEGRITY_DIR/checksums"
MANIFEST_FILE="$INTEGRITY_DIR/manifest.json"
INTEGRITY_LOG="$INTEGRITY_DIR/integrity.log"

# Configuration
MAX_VERSIONS_PER_FILE=10
INTEGRITY_CHECK_INTERVAL=300  # 5 minutes
CRITICAL_FILE_PATTERNS=(
    "*.pid"
    "*.lock"
    "*.state"
    "*.json"
    "**/autonomous-system.pid"
    "**/smart-sync.pid"
    "**/service-status.json"
    "**/coordinator-state.json"
    "**/unified-context.json"
    "**/memory-coordination/*.json"
    "**/sync/*.json"
    "**/autonomous/*.json"
    "**/intelligence/*.json"
    "**/activity/*.json"
    "**/projects/*.json"
    "**/settings.local.json"
    "**/exit_type"
)

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Source dependencies
source "$WORKSPACE_DIR/scripts/atomic-file-operations.sh" 2>/dev/null || {
    echo "Warning: atomic-file-operations.sh not available" >&2
}

source "$WORKSPACE_DIR/scripts/json-safe-operations.sh" 2>/dev/null || {
    echo "Warning: json-safe-operations.sh not available" >&2
}

# Setup directories
mkdir -p "$INTEGRITY_DIR" "$VERSIONS_DIR" "$CHECKSUMS_DIR" "$(dirname "$INTEGRITY_LOG")"

# Logging function
integrity_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local caller="${BASH_SOURCE[2]##*/}:${BASH_LINENO[1]}"
    
    echo "[$timestamp] [$level] [$caller] $message" >> "$INTEGRITY_LOG"
    
    case "$level" in
        "ERROR") echo -e "${RED}[INTEGRITY-ERROR]${NC} $message" >&2 ;;
        "WARN") echo -e "${YELLOW}[INTEGRITY-WARN]${NC} $message" >&2 ;;
        "INFO") echo -e "${BLUE}[INTEGRITY-INFO]${NC} $message" ;;
        "SUCCESS") echo -e "${GREEN}[INTEGRITY-OK]${NC} $message" ;;
        "DEBUG") [[ "${DEBUG:-}" == "1" ]] && echo -e "${CYAN}[INTEGRITY-DEBUG]${NC} $message" ;;
    esac
}

# Initialize manifest
init_manifest() {
    if [[ ! -f "$MANIFEST_FILE" ]]; then
        local initial_manifest='{
    "version": "1.0",
    "created": "'$(date -Iseconds)'",
    "files": {},
    "last_check": null,
    "stats": {
        "files_tracked": 0,
        "versions_created": 0,
        "recoveries_performed": 0,
        "consistency_checks": 0
    }
}'
        if command -v safe_json_write >/dev/null 2>&1; then
            safe_json_write "$MANIFEST_FILE" "$initial_manifest"
        else
            atomic_write_text "$MANIFEST_FILE" "$initial_manifest"
        fi
        integrity_log "INFO" "Initialized integrity manifest"
    fi
}

# Check if file is critical and should be tracked
is_critical_file() {
    local file_path="$1"
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    
    # Check against patterns
    for pattern in "${CRITICAL_FILE_PATTERNS[@]}"; do
        if [[ "$relative_path" == $pattern ]]; then
            return 0
        fi
    done
    
    # Check if it's in .claude directory
    if [[ "$file_path" =~ \.claude/.*\.(json|pid|lock|state)$ ]]; then
        return 0
    fi
    
    return 1
}

# Generate file version path
get_version_path() {
    local file_path="$1"
    local version_id="$2"
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    local safe_path=$(echo "$relative_path" | sed 's/[^a-zA-Z0-9._-]/_/g')
    echo "$VERSIONS_DIR/${safe_path}.v${version_id}"
}

# Generate checksum path
get_checksum_path() {
    local file_path="$1"
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    local safe_path=$(echo "$relative_path" | sed 's/[^a-zA-Z0-9._-]/_/g')
    echo "$CHECKSUMS_DIR/${safe_path}.sha256"
}

# Calculate file checksum
calculate_checksum() {
    local file_path="$1"
    
    if [[ ! -f "$file_path" ]]; then
        return 1
    fi
    
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file_path" | cut -d' ' -f1
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file_path" | cut -d' ' -f1
    else
        # Fallback using openssl
        openssl dgst -sha256 "$file_path" | cut -d' ' -f2
    fi
}

# Create file version
create_version() {
    local file_path="$1"
    local force="${2:-false}"
    
    if [[ ! -f "$file_path" ]]; then
        integrity_log "ERROR" "Cannot create version: file does not exist: $file_path"
        return 1
    fi
    
    if ! is_critical_file "$file_path"; then
        integrity_log "DEBUG" "File not critical, skipping versioning: $file_path"
        return 0
    fi
    
    init_manifest
    
    # Calculate current checksum
    local current_checksum=$(calculate_checksum "$file_path")
    if [[ -z "$current_checksum" ]]; then
        integrity_log "ERROR" "Failed to calculate checksum for: $file_path"
        return 1
    fi
    
    # Get stored checksum
    local checksum_file=$(get_checksum_path "$file_path")
    local stored_checksum=""
    if [[ -f "$checksum_file" ]]; then
        stored_checksum=$(cat "$checksum_file" 2>/dev/null)
    fi
    
    # Skip if checksum hasn't changed and not forced
    if [[ "$force" != "true" ]] && [[ "$current_checksum" == "$stored_checksum" ]]; then
        integrity_log "DEBUG" "File unchanged, skipping version: $file_path"
        return 0
    fi
    
    # Get next version number
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    local version_number=1
    
    # Read current version from manifest
    if command -v safe_json_read >/dev/null 2>&1; then
        local manifest_data=$(safe_json_read "$MANIFEST_FILE" "{}")
        version_number=$(echo "$manifest_data" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    files = data.get('files', {})
    file_info = files.get('$relative_path', {})
    print(file_info.get('version', 0) + 1)
except:
    print(1)
" 2>/dev/null)
    fi
    
    # Create version file
    local version_path=$(get_version_path "$file_path" "$version_number")
    mkdir -p "$(dirname "$version_path")"
    
    if atomic_write_file "$file_path" "$version_path" false 644; then
        # Update checksum
        echo "$current_checksum" > "$checksum_file"
        
        # Update manifest
        local timestamp=$(date -Iseconds)
        local file_size=$(stat -c%s "$file_path" 2>/dev/null || echo "0")
        
        local update_script="
files = data.get('files', {})
files['$relative_path'] = {
    'version': $version_number,
    'last_modified': '$timestamp',
    'checksum': '$current_checksum',
    'size': $file_size,
    'versions': files.get('$relative_path', {}).get('versions', [])
}
# Add version info
version_info = {
    'version': $version_number,
    'created': '$timestamp',
    'checksum': '$current_checksum',
    'size': $file_size
}
files['$relative_path']['versions'].append(version_info)
# Keep only last MAX_VERSIONS versions
files['$relative_path']['versions'] = files['$relative_path']['versions'][-$MAX_VERSIONS_PER_FILE:]
data['files'] = files
data['stats']['versions_created'] = data.get('stats', {}).get('versions_created', 0) + 1
"
        
        if command -v safe_json_update >/dev/null 2>&1; then
            safe_json_update "$MANIFEST_FILE" "$update_script"
        fi
        
        # Cleanup old versions
        cleanup_old_versions "$file_path"
        
        integrity_log "SUCCESS" "Created version $version_number for: $file_path"
        return 0
    else
        integrity_log "ERROR" "Failed to create version for: $file_path"
        return 1
    fi
}

# Cleanup old versions
cleanup_old_versions() {
    local file_path="$1"
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    
    # Find all version files for this file
    local safe_path=$(echo "$relative_path" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local version_pattern="$VERSIONS_DIR/${safe_path}.v*"
    
    # Get list of version files sorted by version number
    local version_files=($(ls $version_pattern 2>/dev/null | sort -V))
    local total_versions=${#version_files[@]}
    
    # Remove excess versions
    if [[ $total_versions -gt $MAX_VERSIONS_PER_FILE ]]; then
        local files_to_remove=$((total_versions - MAX_VERSIONS_PER_FILE))
        for ((i=0; i<files_to_remove; i++)); do
            rm -f "${version_files[i]}" 2>/dev/null
            integrity_log "DEBUG" "Removed old version: ${version_files[i]}"
        done
    fi
}

# Validate file integrity
validate_file() {
    local file_path="$1"
    local fix_if_corrupted="${2:-false}"
    
    if [[ ! -f "$file_path" ]]; then
        integrity_log "WARN" "File does not exist: $file_path"
        return 1
    fi
    
    if ! is_critical_file "$file_path"; then
        return 0
    fi
    
    # Check basic file consistency
    if ! check_file_consistency "$file_path" 2>/dev/null; then
        integrity_log "ERROR" "File failed consistency check: $file_path"
        
        if [[ "$fix_if_corrupted" == "true" ]]; then
            if recover_file "$file_path"; then
                integrity_log "SUCCESS" "File recovered successfully: $file_path"
                return 0
            else
                integrity_log "ERROR" "File recovery failed: $file_path"
                return 1
            fi
        fi
        return 1
    fi
    
    # Check checksum if available
    local checksum_file=$(get_checksum_path "$file_path")
    if [[ -f "$checksum_file" ]]; then
        local stored_checksum=$(cat "$checksum_file" 2>/dev/null)
        local current_checksum=$(calculate_checksum "$file_path")
        
        if [[ "$stored_checksum" != "$current_checksum" ]]; then
            integrity_log "WARN" "Checksum mismatch for: $file_path (expected: $stored_checksum, got: $current_checksum)"
            
            if [[ "$fix_if_corrupted" == "true" ]]; then
                if recover_file "$file_path"; then
                    integrity_log "SUCCESS" "File recovered from checksum mismatch: $file_path"
                    return 0
                fi
            fi
            return 1
        fi
    fi
    
    integrity_log "DEBUG" "File validation passed: $file_path"
    return 0
}

# Recover corrupted file
recover_file() {
    local file_path="$1"
    local force="${2:-false}"
    
    if ! is_critical_file "$file_path"; then
        integrity_log "DEBUG" "File not critical, skipping recovery: $file_path"
        return 0
    fi
    
    integrity_log "INFO" "Attempting to recover file: $file_path"
    
    # Try to recover using atomic operations recovery
    if command -v recover_corrupted_file >/dev/null 2>&1; then
        if recover_corrupted_file "$file_path" "$force"; then
            # Update stats
            if command -v safe_json_update >/dev/null 2>&1; then
                local update_script="data['stats']['recoveries_performed'] = data.get('stats', {}).get('recoveries_performed', 0) + 1"
                safe_json_update "$MANIFEST_FILE" "$update_script" 2>/dev/null
            fi
            return 0
        fi
    fi
    
    # Try to recover from our versions
    local relative_path="${file_path#$WORKSPACE_DIR/}"
    local safe_path=$(echo "$relative_path" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local version_pattern="$VERSIONS_DIR/${safe_path}.v*"
    
    # Get most recent version
    local latest_version=$(ls $version_pattern 2>/dev/null | sort -V | tail -n1)
    
    if [[ -n "$latest_version" ]] && [[ -f "$latest_version" ]]; then
        # Validate the version file
        if check_file_consistency "$latest_version" 2>/dev/null; then
            if atomic_write_file "$latest_version" "$file_path" true 644; then
                integrity_log "SUCCESS" "Recovered file from version: $file_path <- $latest_version"
                
                # Update checksum
                local new_checksum=$(calculate_checksum "$file_path")
                local checksum_file=$(get_checksum_path "$file_path")
                echo "$new_checksum" > "$checksum_file"
                
                # Update stats
                if command -v safe_json_update >/dev/null 2>&1; then
                    local update_script="data['stats']['recoveries_performed'] = data.get('stats', {}).get('recoveries_performed', 0) + 1"
                    safe_json_update "$MANIFEST_FILE" "$update_script" 2>/dev/null
                fi
                
                return 0
            fi
        else
            integrity_log "WARN" "Version file is also corrupted: $latest_version"
        fi
    fi
    
    integrity_log "ERROR" "Failed to recover file: $file_path"
    return 1
}

# Run consistency check on all tracked files
run_consistency_check() {
    local fix_corrupted="${1:-false}"
    local total_files=0
    local failed_files=0
    local recovered_files=0
    
    integrity_log "INFO" "Starting consistency check (fix_corrupted=$fix_corrupted)"
    
    init_manifest
    
    # Check all files in .claude directory
    while IFS= read -r -d '' file_path; do
        if is_critical_file "$file_path"; then
            ((total_files++))
            
            if ! validate_file "$file_path" "$fix_corrupted"; then
                ((failed_files++))
                
                if [[ "$fix_corrupted" == "true" ]]; then
                    if validate_file "$file_path" false; then
                        ((recovered_files++))
                        ((failed_files--))
                    fi
                fi
            fi
        fi
    done < <(find "$WORKSPACE_DIR/.claude" -type f -print0 2>/dev/null)
    
    # Update stats
    if command -v safe_json_update >/dev/null 2>&1; then
        local timestamp=$(date -Iseconds)
        local update_script="
data['last_check'] = '$timestamp'
data['stats']['consistency_checks'] = data.get('stats', {}).get('consistency_checks', 0) + 1
data['stats']['files_tracked'] = $total_files
"
        safe_json_update "$MANIFEST_FILE" "$update_script" 2>/dev/null
    fi
    
    if [[ $failed_files -eq 0 ]]; then
        integrity_log "SUCCESS" "Consistency check passed: $total_files files checked"
        return 0
    else
        integrity_log "ERROR" "Consistency check failed: $failed_files/$total_files files corrupted"
        if [[ $recovered_files -gt 0 ]]; then
            integrity_log "INFO" "Recovered $recovered_files corrupted files"
        fi
        return 1
    fi
}

# Monitor critical files for changes
monitor_files() {
    local interval="${1:-$INTEGRITY_CHECK_INTERVAL}"
    
    integrity_log "INFO" "Starting file monitoring (interval: ${interval}s)"
    
    # Create initial versions
    while IFS= read -r -d '' file_path; do
        if is_critical_file "$file_path"; then
            create_version "$file_path" false
        fi
    done < <(find "$WORKSPACE_DIR/.claude" -type f -print0 2>/dev/null)
    
    # Monitor loop
    while true; do
        # Check for file changes and create versions
        while IFS= read -r -d '' file_path; do
            if is_critical_file "$file_path"; then
                create_version "$file_path" false
            fi
        done < <(find "$WORKSPACE_DIR/.claude" -type f -print0 2>/dev/null)
        
        # Run periodic consistency check
        run_consistency_check false
        
        sleep "$interval"
    done
}

# Show integrity status
show_integrity_status() {
    echo -e "${BLUE}State Integrity Manager Status${NC}"
    echo
    
    if [[ -f "$MANIFEST_FILE" ]]; then
        local manifest_data
        if command -v safe_json_read >/dev/null 2>&1; then
            manifest_data=$(safe_json_read "$MANIFEST_FILE" "{}")
        else
            manifest_data=$(cat "$MANIFEST_FILE" 2>/dev/null || echo "{}")
        fi
        
        echo "Manifest version: $(echo "$manifest_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('version', 'unknown'))" 2>/dev/null)"
        echo "Files tracked: $(echo "$manifest_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('files_tracked', 0))" 2>/dev/null)"
        echo "Versions created: $(echo "$manifest_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('versions_created', 0))" 2>/dev/null)"
        echo "Recoveries performed: $(echo "$manifest_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('recoveries_performed', 0))" 2>/dev/null)"
        echo "Consistency checks: $(echo "$manifest_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('stats', {}).get('consistency_checks', 0))" 2>/dev/null)"
        echo "Last check: $(echo "$manifest_data" | python3 -c "import json,sys; print(json.load(sys.stdin).get('last_check', 'never'))" 2>/dev/null)"
    else
        echo "Manifest not initialized"
    fi
    
    echo
    echo "Storage usage:"
    if [[ -d "$VERSIONS_DIR" ]]; then
        local versions_size=$(du -sh "$VERSIONS_DIR" 2>/dev/null | cut -f1)
        local versions_count=$(find "$VERSIONS_DIR" -type f 2>/dev/null | wc -l)
        echo "  Versions: $versions_count files, $versions_size"
    fi
    
    if [[ -d "$CHECKSUMS_DIR" ]]; then
        local checksums_count=$(find "$CHECKSUMS_DIR" -type f 2>/dev/null | wc -l)
        echo "  Checksums: $checksums_count files"
    fi
    
    # Recent activity
    if [[ -f "$INTEGRITY_LOG" ]]; then
        echo
        echo "Recent activity:"
        tail -5 "$INTEGRITY_LOG" | while read -r line; do
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

# Test integrity system
test_integrity_system() {
    echo -e "${BLUE}Testing State Integrity System...${NC}"
    
    local test_dir="$WORKSPACE_DIR/.claude/test-integrity"
    local test_file="$test_dir/test.json"
    
    mkdir -p "$test_dir"
    
    # Create test file
    echo '{"test": true, "value": 42}' > "$test_file"
    
    # Test versioning
    echo "Testing versioning..."
    if create_version "$test_file" true; then
        echo -e "${GREEN}✓ Versioning test passed${NC}"
    else
        echo -e "${RED}✗ Versioning test failed${NC}"
        return 1
    fi
    
    # Test validation
    echo "Testing validation..."
    if validate_file "$test_file"; then
        echo -e "${GREEN}✓ Validation test passed${NC}"
    else
        echo -e "${RED}✗ Validation test failed${NC}"
        return 1
    fi
    
    # Test corruption detection and recovery
    echo "Testing corruption detection and recovery..."
    echo 'invalid json' > "$test_file"
    
    if ! validate_file "$test_file"; then
        echo "✓ Corruption detected"
        if recover_file "$test_file"; then
            echo -e "${GREEN}✓ Recovery test passed${NC}"
        else
            echo -e "${RED}✗ Recovery test failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}✗ Corruption detection failed${NC}"
        return 1
    fi
    
    # Test consistency check
    echo "Testing consistency check..."
    if run_consistency_check true; then
        echo -e "${GREEN}✓ Consistency check test passed${NC}"
    else
        echo -e "${RED}✗ Consistency check test failed${NC}"
        return 1
    fi
    
    # Cleanup
    rm -rf "$test_dir"
    
    echo -e "${GREEN}All integrity system tests passed!${NC}"
    return 0
}

# Command-line interface
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        "test")
            test_integrity_system
            ;;
        "status")
            show_integrity_status
            ;;
        "check")
            run_consistency_check "${2:-false}"
            ;;
        "monitor")
            monitor_files "${2:-$INTEGRITY_CHECK_INTERVAL}"
            ;;
        "version")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 version <file_path> [force]"
                exit 1
            fi
            create_version "$2" "${3:-false}"
            ;;
        "validate")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 validate <file_path> [fix]"
                exit 1
            fi
            validate_file "$2" "${3:-false}"
            ;;
        "recover")
            if [[ -z "$2" ]]; then
                echo "Usage: $0 recover <file_path> [force]"
                exit 1
            fi
            recover_file "$2" "${3:-false}"
            ;;
        "init")
            init_manifest
            echo "Integrity system initialized"
            ;;
        "help"|"--help"|"-h")
            echo "State Integrity Manager - Versioning and Consistency Checks"
            echo
            echo "Usage: $0 [command] [options]"
            echo
            echo "Commands:"
            echo "  test                              - Run tests"
            echo "  status                            - Show status"
            echo "  init                              - Initialize integrity system"
            echo "  check [fix]                       - Run consistency check"
            echo "  monitor [interval]                - Monitor files for changes"
            echo "  version <file> [force]            - Create file version"
            echo "  validate <file> [fix]             - Validate file integrity"
            echo "  recover <file> [force]            - Recover corrupted file"
            echo
            echo "Shell functions available:"
            echo "  create_version <file> [force]"
            echo "  validate_file <file> [fix]"
            echo "  recover_file <file> [force]"
            echo "  run_consistency_check [fix]"
            echo "  is_critical_file <file>"
            ;;
        "")
            echo "Source this script to use state integrity functions"
            echo "Run '$0 help' for usage information"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
fi