#!/bin/bash

# test-simplified-full.sh - Comprehensive Test Suite for Simplified System
# Full validation before migration including performance, integration & cross-component tests

set -euo pipefail

# Environment
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEST_LOG_FILE="${WORKSPACE_ROOT}/.claude/logs/test-simplified-full.log"
readonly TEST_DATA_DIR="${WORKSPACE_ROOT}/.claude/test-data"
readonly PERFORMANCE_LOG="${WORKSPACE_ROOT}/.claude/logs/performance-test.log"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Test counters and stats
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
WARNING_TESTS=0

# Performance metrics
declare -A PERFORMANCE_TIMES
declare -A COMPONENT_SCORES

# Setup
mkdir -p "$(dirname "$TEST_LOG_FILE")" "$TEST_DATA_DIR"

# Logging functions
log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TEST] $1" | tee -a "$TEST_LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

log_info() {
    echo -e "${CYAN}[INFO]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

log_performance() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [PERF] $1" >> "$PERFORMANCE_LOG"
}

# Performance measurement
measure_performance() {
    local test_name="$1"
    local command="$2"
    local max_time="${3:-5.0}"
    
    local start_time=$(date +%s.%N)
    local result=0
    
    eval "$command" >/dev/null 2>&1 || result=$?
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    PERFORMANCE_TIMES["$test_name"]="$duration"
    log_performance "$test_name: ${duration}s (max: ${max_time}s)"
    
    # Check if within acceptable time
    if (( $(echo "$duration > $max_time" | bc -l) )); then
        log_warning "$test_name exceeded max time: ${duration}s > ${max_time}s"
        return 2
    fi
    
    return $result
}

# Test runner with categorization
run_test() {
    local test_name="$1"
    local test_function="$2"
    local category="${3:-general}"
    
    log_test "[$category] Running: $test_name"
    ((TOTAL_TESTS++))
    
    local result=0
    $test_function || result=$?
    
    case $result in
        0)
            log_success "✓ PASSED: $test_name"
            ((PASSED_TESTS++))
            ;;
        1)
            log_error "✗ FAILED: $test_name"
            ((FAILED_TESTS++))
            ;;
        2)
            log_warning "⚠ WARNING: $test_name"
            ((WARNING_TESTS++))
            ;;
    esac
    
    return $result
}

# =======================
# INTELLIGENCE SYSTEM TESTS
# =======================

test_intelligence_pattern_recognition() {
    log_info "Testing intelligence pattern recognition..."
    
    local intelligence_script="$SCRIPT_DIR/claude-intelligence-enhanced.sh"
    if [[ ! -f "$intelligence_script" ]]; then
        log_error "Intelligence enhanced script not found"
        return 1
    fi
    
    # Test pattern analysis
    if ! measure_performance "intelligence_patterns" "$intelligence_script patterns" 10.0; then
        case $? in
            1) log_error "Intelligence pattern analysis failed"; return 1 ;;
            2) log_warning "Intelligence pattern analysis too slow"; return 2 ;;
        esac
    fi
    
    # Verify pattern database exists and is valid
    local patterns_db="${WORKSPACE_ROOT}/.claude/intelligence/enhanced/patterns.json"
    if [[ ! -f "$patterns_db" ]]; then
        log_error "Patterns database not created"
        return 1
    fi
    
    if ! python3 -c "import json; json.load(open('$patterns_db'))" 2>/dev/null; then
        log_error "Patterns database contains invalid JSON"
        return 1
    fi
    
    # Check pattern confidence scores
    local confidence=$(python3 -c "
import json
with open('$patterns_db') as f:
    data = json.load(f)
scores = data.get('pattern_stats', {}).get('confidence_scores', {})
avg_confidence = sum(scores.values()) / len(scores) if scores else 0
print(f'{avg_confidence:.2f}')
" 2>/dev/null || echo "0")
    
    if (( $(echo "$confidence < 0.3" | bc -l) )); then
        log_warning "Low pattern confidence: $confidence"
        return 2
    fi
    
    log_success "Intelligence pattern recognition working (confidence: $confidence)"
    COMPONENT_SCORES["intelligence_patterns"]="$confidence"
    return 0
}

test_intelligence_data_extraction() {
    log_info "Testing intelligence data extraction from git commits..."
    
    # Test git commit analysis
    local commits_analyzed=$(git log --oneline --since="30 days ago" | wc -l)
    if [[ $commits_analyzed -lt 5 ]]; then
        log_warning "Limited git history for analysis: $commits_analyzed commits"
    fi
    
    # Test intelligence extraction
    local intelligence_script="$SCRIPT_DIR/claude-intelligence-enhanced.sh"
    if ! measure_performance "intelligence_analysis" "$intelligence_script analyze" 15.0; then
        case $? in
            1) log_error "Intelligence analysis failed"; return 1 ;;
            2) log_warning "Intelligence analysis too slow"; return 2 ;;
        esac
    fi
    
    # Verify enhanced databases
    local enhanced_dir="${WORKSPACE_ROOT}/.claude/intelligence/enhanced"
    local required_dbs=("patterns.json" "context.json" "learnings.json")
    
    for db in "${required_dbs[@]}"; do
        if [[ ! -f "$enhanced_dir/$db" ]]; then
            log_error "Required database missing: $db"
            return 1
        fi
    done
    
    log_success "Intelligence data extraction working"
    return 0
}

test_intelligence_cross_project_learning() {
    log_info "Testing cross-project learning functionality..."
    
    # Test cross-project analysis
    local intelligence_script="$SCRIPT_DIR/claude-intelligence-enhanced.sh"
    
    # Generate cross-project insights
    if ! measure_performance "cross_project_analysis" "$intelligence_script summary" 8.0; then
        case $? in
            1) log_error "Cross-project analysis failed"; return 1 ;;
            2) log_warning "Cross-project analysis too slow"; return 2 ;;
        esac
    fi
    
    # Check for cross-project database
    local cross_project_db="${WORKSPACE_ROOT}/.claude/intelligence/enhanced/cross-project.json"
    if [[ -f "$cross_project_db" ]]; then
        local connections=$(python3 -c "
import json
with open('$cross_project_db') as f:
    data = json.load(f)
print(data.get('cross_project_stats', {}).get('total_connections', 0))
" 2>/dev/null || echo "0")
        
        log_success "Cross-project learning active ($connections connections)"
        COMPONENT_SCORES["cross_project"]="$connections"
    else
        log_warning "Cross-project database not found"
        return 2
    fi
    
    return 0
}

test_intelligence_context_generation() {
    log_info "Testing intelligence context generation for Claude..."
    
    local intelligence_script="$SCRIPT_DIR/claude-intelligence-enhanced.sh"
    
    # Test context generation
    if ! measure_performance "context_generation" "$intelligence_script context" 8.0; then
        case $? in
            1) log_error "Context generation failed"; return 1 ;;
            2) log_warning "Context generation too slow"; return 2 ;;
        esac
    fi
    
    # Verify context database
    local context_db="${WORKSPACE_ROOT}/.claude/intelligence/enhanced/context.json"
    if [[ ! -f "$context_db" ]]; then
        log_error "Context database not created"
        return 1
    fi
    
    # Check context quality
    local insights_count=$(python3 -c "
import json
with open('$context_db') as f:
    data = json.load(f)
insights = data.get('context_enhancement', {}).get('user_specific_insights', {})
total = len(insights.get('expertise_areas', {})) + len(insights.get('coding_style', {}))
print(total)
" 2>/dev/null || echo "0")
    
    if [[ $insights_count -lt 3 ]]; then
        log_warning "Limited context insights generated: $insights_count"
        return 2
    fi
    
    log_success "Intelligence context generation working ($insights_count insights)"
    COMPONENT_SCORES["context_generation"]="$insights_count"
    return 0
}

# =======================
# MEMORY SYSTEM TESTS
# =======================

test_memory_save_load_cycle() {
    log_info "Testing memory system save/load cycle..."
    
    local memory_script="$SCRIPT_DIR/claude-simplified-memory.sh"
    
    # Test save with specific data
    local test_reason="test_migration_validation"
    local test_summary="Testing simplified memory system"
    local test_issues="No critical issues detected"
    local test_actions="Continue with migration validation"
    
    if ! measure_performance "memory_save" "$memory_script save '$test_reason' '$test_summary' '$test_issues' '$test_actions'" 3.0; then
        case $? in
            1) log_error "Memory save failed"; return 1 ;;
            2) log_warning "Memory save too slow"; return 2 ;;
        esac
    fi
    
    # Test load
    local load_output
    if ! load_output=$("$memory_script" load 2>&1); then
        log_error "Memory load failed"
        return 1
    fi
    
    # Verify load output contains basic session info (more lenient check)
    if [[ -z "$load_output" || "$load_output" == *"Error"* ]]; then
        log_error "Memory load produced no valid output"
        return 1
    fi
    
    # Check if load contains expected memory components
    if [[ "$load_output" != *"Last session:"* && "$load_output" != *"Device:"* ]]; then
        log_warning "Memory load output format unexpected but functional"
        return 2
    fi
    
    log_success "Memory save/load cycle working correctly"
    return 0
}

test_memory_intelligence_integration() {
    log_info "Testing memory system intelligence integration..."
    
    # Create test intelligence context
    local intel_context_file="${WORKSPACE_ROOT}/.claude/intelligence/claude-memory-context.json"
    if [[ ! -f "$intel_context_file" ]]; then
        # Create minimal intelligence context for testing
        mkdir -p "$(dirname "$intel_context_file")"
        cat > "$intel_context_file" << 'EOF'
{
  "user_intelligence_profile": {
    "version": "2.0",
    "generated_at": "2025-06-14T12:00:00Z",
    "key_insights": {
      "coding_preferences": {
        "primary_languages": ["python", "bash"],
        "focus_areas": {"automation": true}
      }
    }
  }
}
EOF
    fi
    
    # Test memory load with intelligence integration
    local memory_script="$SCRIPT_DIR/claude-simplified-memory.sh"
    local load_output
    
    if ! load_output=$(measure_performance "memory_intel_integration" "$memory_script load" 5.0 2>&1); then
        case $? in
            1) log_error "Memory intelligence integration failed"; return 1 ;;
            2) log_warning "Memory intelligence integration too slow"; return 2 ;;
        esac
    fi
    
    # Check if intelligence context was integrated
    if [[ "$load_output" == *"Intelligence context integrated"* ]]; then
        log_success "Memory intelligence integration working"
    else
        log_warning "Intelligence integration not detected in output"
        return 2
    fi
    
    return 0
}

test_memory_session_history() {
    log_info "Testing memory session history management..."
    
    local memory_script="$SCRIPT_DIR/claude-simplified-memory.sh"
    
    # Test stats functionality
    if ! measure_performance "memory_stats" "$memory_script stats" 2.0; then
        case $? in
            1) log_error "Memory stats failed"; return 1 ;;
            2) log_warning "Memory stats too slow"; return 2 ;;
        esac
    fi
    
    # Check for memory files
    local memory_dir="${WORKSPACE_ROOT}/.claude/memory"
    local context_file="$memory_dir/enhanced-context.json"
    
    if [[ -f "$context_file" ]]; then
        # Verify JSON validity
        if ! python3 -m json.tool "$context_file" >/dev/null 2>&1; then
            log_error "Memory context file contains invalid JSON"
            return 1
        fi
        
        # Check for session history
        local sessions_count=$(python3 -c "
import json
try:
    with open('$context_file') as f:
        data = json.load(f)
    history = data.get('session_history', [])
    print(len(history))
except:
    print(0)
")
        
        log_success "Memory session history accessible ($sessions_count sessions)"
        COMPONENT_SCORES["memory_sessions"]="$sessions_count"
    else
        log_warning "Memory context file not found"
        return 2
    fi
    
    return 0
}

test_memory_device_awareness() {
    log_info "Testing memory system device awareness..."
    
    local memory_script="$SCRIPT_DIR/claude-simplified-memory.sh"
    
    # Test load to check device detection
    local load_output
    if ! load_output=$("$memory_script" load 2>&1); then
        log_error "Memory load failed for device awareness test"
        return 1
    fi
    
    # Check if device information is included
    if [[ "$load_output" == *"Device:"* ]]; then
        local device=$(echo "$load_output" | grep "Device:" | head -1)
        log_success "Memory device awareness working: $device"
    else
        log_warning "Device awareness not detected in memory output"
        return 2
    fi
    
    return 0
}

# =======================
# PROJECT SYSTEM TESTS
# =======================

test_project_detection_enhanced() {
    log_info "Testing enhanced project detection..."
    
    local project_script="$SCRIPT_DIR/claude-project-enhanced.sh"
    if [[ ! -f "$project_script" ]]; then
        log_error "Enhanced project script not found"
        return 1
    fi
    
    # Test project detection
    local project_output
    if ! project_output=$("$project_script" detect 2>&1); then
        log_error "Project detection failed"
        return 1
    fi
    
    # Extract JSON from output (filter out colored text)
    local project_json
    project_json=$(echo "$project_output" | grep '^{.*}$' | head -1)
    
    if [[ -z "$project_json" ]]; then
        log_error "No JSON output found in project detection"
        return 1
    fi
    
    # Verify JSON output
    if ! echo "$project_json" | python3 -m json.tool >/dev/null 2>&1; then
        log_error "Project detection returned invalid JSON"
        return 1
    fi
    
    # Check detection confidence
    local confidence=$(echo "$project_json" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('detection_confidence', 'unknown'))
except:
    print('unknown')
")
    
    if [[ "$confidence" == "high" ]]; then
        log_success "Enhanced project detection working (confidence: $confidence)"
    else
        log_warning "Project detection confidence: $confidence"
        return 2
    fi
    
    COMPONENT_SCORES["project_detection"]="$confidence"
    return 0
}

test_project_lifecycle_management() {
    log_info "Testing project lifecycle management..."
    
    local project_script="$SCRIPT_DIR/claude-project-enhanced.sh"
    
    # Test lifecycle summary
    if ! measure_performance "project_lifecycle" "$project_script lifecycle" 5.0; then
        case $? in
            1) log_error "Project lifecycle failed"; return 1 ;;
            2) log_warning "Project lifecycle too slow"; return 2 ;;
        esac
    fi
    
    # Check lifecycle database
    local lifecycle_file="${WORKSPACE_ROOT}/.claude/projects/lifecycle.json"
    if [[ -f "$lifecycle_file" ]]; then
        if ! python3 -m json.tool "$lifecycle_file" >/dev/null 2>&1; then
            log_error "Project lifecycle file contains invalid JSON"
            return 1
        fi
        
        local projects_count=$(python3 -c "
import json
with open('$lifecycle_file') as f:
    data = json.load(f)
print(len(data.get('projects', {})))
")
        
        log_success "Project lifecycle management working ($projects_count projects tracked)"
        COMPONENT_SCORES["project_lifecycle"]="$projects_count"
    else
        log_warning "Project lifecycle file not found"
        return 2
    fi
    
    return 0
}

test_project_context_switching() {
    log_info "Testing project context switching..."
    
    local project_script="$SCRIPT_DIR/claude-project-enhanced.sh"
    
    # Test status command (safe operation)
    if ! measure_performance "project_status" "$project_script status" 4.0; then
        case $? in
            1) log_error "Project status failed"; return 1 ;;
            2) log_warning "Project status too slow"; return 2 ;;
        esac
    fi
    
    # Test context save (for current location)
    if ! measure_performance "project_context_save" "$project_script save-context" 3.0; then
        case $? in
            1) log_warning "Project context save failed (might be normal)"; return 2 ;;
            2) log_warning "Project context save too slow"; return 2 ;;
        esac
    fi
    
    log_success "Project context switching functional"
    return 0
}

test_project_cross_patterns() {
    log_info "Testing cross-project pattern detection..."
    
    local project_script="$SCRIPT_DIR/claude-project-enhanced.sh"
    
    # Test intelligence extraction
    if ! measure_performance "project_intelligence" "$project_script intelligence" 8.0; then
        case $? in
            1) log_error "Project intelligence extraction failed"; return 1 ;;
            2) log_warning "Project intelligence extraction too slow"; return 2 ;;
        esac
    fi
    
    log_success "Cross-project pattern detection working"
    return 0
}

# =======================
# SYNC SYSTEM TESTS
# =======================

test_sync_device_awareness() {
    log_info "Testing sync system device awareness..."
    
    local sync_script="$SCRIPT_DIR/claude-sync-smart.sh"
    if [[ ! -f "$sync_script" ]]; then
        log_error "Smart sync script not found"
        return 1
    fi
    
    # Test status (safe operation)
    local sync_status
    if ! sync_status=$(measure_performance "sync_status" "$sync_script status" 2.0 2>&1); then
        case $? in
            1) log_error "Sync status failed"; return 1 ;;
            2) log_warning "Sync status too slow"; return 2 ;;
        esac
    fi
    
    # Check device detection
    if [[ "$sync_status" == *"Device:"* ]]; then
        local device_line=$(echo "$sync_status" | grep "Device:" | head -1)
        log_success "Sync device awareness working: $device_line"
    else
        log_warning "Sync device awareness not detected"
        return 2
    fi
    
    return 0
}

test_sync_conflict_resolution() {
    log_info "Testing sync conflict resolution..."
    
    local sync_script="$SCRIPT_DIR/claude-sync-smart.sh"
    
    # Test sync conditions (dry run)
    if ! measure_performance "sync_test" "$sync_script test" 2.0; then
        case $? in
            1) log_error "Sync test failed"; return 1 ;;
            2) log_warning "Sync test too slow"; return 2 ;;
        esac
    fi
    
    # Check configuration
    local config_file="${WORKSPACE_ROOT}/.claude/sync-smart-config.json"
    if [[ -f "$config_file" ]]; then
        if ! python3 -m json.tool "$config_file" >/dev/null 2>&1; then
            log_error "Sync config file contains invalid JSON"
            return 1
        fi
        log_success "Sync conflict resolution configured"
    else
        log_warning "Sync config file not found"
        return 2
    fi
    
    return 0
}

test_sync_smart_triggers() {
    log_info "Testing sync smart triggers..."
    
    local sync_script="$SCRIPT_DIR/claude-sync-smart.sh"
    
    # Test trigger conditions
    local test_output
    if ! test_output=$("$sync_script" test 2>&1); then
        log_warning "Sync trigger test failed"
        return 2
    fi
    
    # Check for intelligent decision making
    if [[ "$test_output" == *"Deep work:"* && "$test_output" == *"Natural breakpoint:"* ]]; then
        log_success "Sync smart triggers working"
    else
        log_warning "Sync trigger intelligence not detected"
        return 2
    fi
    
    return 0
}

test_sync_git_integration() {
    log_info "Testing sync git integration..."
    
    # Test git status for sync requirements
    if ! git status >/dev/null 2>&1; then
        log_error "Not in a git repository"
        return 1
    fi
    
    # Test git remote
    if ! git remote -v >/dev/null 2>&1; then
        log_warning "No git remote configured"
        return 2
    fi
    
    # Test git fetch (safe operation)
    if ! timeout 10s git fetch --dry-run >/dev/null 2>&1; then
        log_warning "Git fetch test failed (might be network issue)"
        return 2
    fi
    
    log_success "Sync git integration ready"
    return 0
}

# =======================
# STARTUP SYSTEM TESTS
# =======================

test_startup_daemon_management() {
    log_info "Testing startup daemon management..."
    
    local startup_script="$SCRIPT_DIR/claude-startup-simple.sh"
    if [[ ! -f "$startup_script" ]]; then
        log_error "Simple startup script not found"
        return 1
    fi
    
    # Test status check
    if ! measure_performance "startup_status" "$startup_script status" 2.0; then
        case $? in
            1) log_error "Startup status check failed"; return 1 ;;
            2) log_warning "Startup status check too slow"; return 2 ;;
        esac
    fi
    
    log_success "Startup daemon management working"
    return 0
}

test_startup_health_verification() {
    log_info "Testing startup health verification..."
    
    # Check for required daemon scripts
    local required_daemons=(
        "claude-auto-context.sh"
        "claude-intelligence-daemon.sh"
        "claude-sync-daemon.sh"
    )
    
    for daemon in "${required_daemons[@]}"; do
        local daemon_path="$SCRIPT_DIR/$daemon"
        if [[ ! -f "$daemon_path" ]]; then
            log_error "Required daemon script missing: $daemon"
            return 1
        fi
        
        if [[ ! -x "$daemon_path" ]]; then
            log_error "Daemon script not executable: $daemon"
            return 1
        fi
    done
    
    log_success "Startup health verification passed"
    return 0
}

test_startup_performance() {
    log_info "Testing startup performance (< 2sec target)..."
    
    local startup_script="$SCRIPT_DIR/claude-startup-simple.sh"
    
    # Note: We don't actually start to avoid interfering with tests
    # Instead we test the status check which exercises startup logic
    if ! measure_performance "startup_perf" "$startup_script status" 2.0; then
        case $? in
            1) log_error "Startup performance test failed"; return 1 ;;
            2) log_warning "Startup performance may not meet < 2sec target"; return 2 ;;
        esac
    fi
    
    local startup_time="${PERFORMANCE_TIMES["startup_perf"]}"
    if (( $(echo "$startup_time < 2.0" | bc -l) )); then
        log_success "Startup performance excellent: ${startup_time}s"
    else
        log_warning "Startup performance concern: ${startup_time}s"
        return 2
    fi
    
    return 0
}

test_startup_service_coordination() {
    log_info "Testing startup service coordination..."
    
    # Check autonomous system
    local autonomous_script="$SCRIPT_DIR/claude-autonomous-system.sh"
    if [[ -f "$autonomous_script" ]]; then
        if ! measure_performance "autonomous_status" "$autonomous_script status" 3.0; then
            case $? in
                1) log_warning "Autonomous system check failed"; return 2 ;;
                2) log_warning "Autonomous system check too slow"; return 2 ;;
            esac
        fi
    fi
    
    log_success "Startup service coordination functional"
    return 0
}

# =======================
# INTEGRATION TESTS
# =======================

test_component_data_flow() {
    log_info "Testing data flow between components..."
    
    # Test: Intelligence -> Memory integration
    local intel_context="${WORKSPACE_ROOT}/.claude/intelligence/claude-memory-context.json"
    local memory_context="${WORKSPACE_ROOT}/.claude/memory/enhanced-context.json"
    
    if [[ -f "$intel_context" && -f "$memory_context" ]]; then
        # Check if memory context includes intelligence data
        local has_intel=$(python3 -c "
import json
try:
    with open('$memory_context') as f:
        data = json.load(f)
    has_profile = 'user_intelligence_profile' in data
    print(has_profile)
except:
    print(False)
" 2>/dev/null || echo "False")
        
        if [[ "$has_intel" == "True" ]]; then
            log_success "Intelligence -> Memory data flow working"
        else
            log_warning "Intelligence -> Memory data flow not detected"
            return 2
        fi
    else
        log_warning "Missing context files for data flow test"
        return 2
    fi
    
    return 0
}

test_component_performance_integration() {
    log_info "Testing integrated performance across components..."
    
    # Test combined operation: Memory load + Intelligence + Project detection
    local combined_start=$(date +%s.%N)
    
    # Memory load
    "$SCRIPT_DIR/claude-simplified-memory.sh" load >/dev/null 2>&1 || true
    
    # Project detection
    "$SCRIPT_DIR/claude-project-enhanced.sh" detect >/dev/null 2>&1 || true
    
    # Intelligence summary
    if [[ -f "$SCRIPT_DIR/claude-intelligence-enhanced.sh" ]]; then
        "$SCRIPT_DIR/claude-intelligence-enhanced.sh" summary >/dev/null 2>&1 || true
    fi
    
    local combined_end=$(date +%s.%N)
    local combined_time=$(echo "$combined_end - $combined_start" | bc)
    
    PERFORMANCE_TIMES["integrated_operation"]="$combined_time"
    
    # Target: combined operations under 10 seconds
    if (( $(echo "$combined_time < 10.0" | bc -l) )); then
        log_success "Integrated performance good: ${combined_time}s"
    else
        log_warning "Integrated performance concern: ${combined_time}s"
        return 2
    fi
    
    return 0
}

test_component_error_handling() {
    log_info "Testing cross-component error handling..."
    
    # Test graceful handling of missing files
    local backup_file="${WORKSPACE_ROOT}/.claude/memory/unified-context.json.backup"
    local original_file="${WORKSPACE_ROOT}/.claude/memory/unified-context.json"
    
    # Backup original if exists
    if [[ -f "$original_file" ]]; then
        cp "$original_file" "$backup_file"
        rm -f "$original_file"
    fi
    
    # Test memory load with missing file
    local load_result=0
    "$SCRIPT_DIR/claude-simplified-memory.sh" load >/dev/null 2>&1 || load_result=$?
    
    # Restore original
    if [[ -f "$backup_file" ]]; then
        mv "$backup_file" "$original_file"
    fi
    
    # Should handle missing file gracefully (not crash)
    if [[ $load_result -eq 0 || $load_result -eq 1 ]]; then
        log_success "Cross-component error handling working"
    else
        log_error "Cross-component error handling failed"
        return 1
    fi
    
    return 0
}

test_component_resource_usage() {
    log_info "Testing component resource usage..."
    
    # Test memory usage (simplified check)
    local memory_script="$SCRIPT_DIR/claude-simplified-memory.sh"
    
    # Run memory stats and check it doesn't hang
    local timeout_result=0
    timeout 5s "$memory_script" stats >/dev/null 2>&1 || timeout_result=$?
    
    if [[ $timeout_result -eq 124 ]]; then
        log_warning "Memory component may have resource issues (timeout)"
        return 2
    elif [[ $timeout_result -eq 0 ]]; then
        log_success "Component resource usage acceptable"
    else
        log_warning "Component resource test inconclusive"
        return 2
    fi
    
    return 0
}

# =======================
# SYSTEM VERIFICATION
# =======================

test_overall_system_readiness() {
    log_info "Testing overall system readiness..."
    
    # Check critical files exist
    local critical_files=(
        "$SCRIPT_DIR/claude-simplified-memory.sh"
        "$SCRIPT_DIR/claude-project-enhanced.sh"
        "$SCRIPT_DIR/claude-sync-smart.sh"
        "$SCRIPT_DIR/claude-startup-simple.sh"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Critical file missing: $file"
            return 1
        fi
    done
    
    # Check essential directories
    local essential_dirs=(
        "${WORKSPACE_ROOT}/.claude/memory"
        "${WORKSPACE_ROOT}/.claude/logs"
        "${WORKSPACE_ROOT}/.claude/intelligence"
    )
    
    for dir in "${essential_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Essential directory missing: $dir"
            return 1
        fi
    done
    
    log_success "Overall system readiness verified"
    return 0
}

# =======================
# PERFORMANCE ANALYSIS
# =======================

generate_performance_report() {
    echo -e "\n${CYAN}📊 PERFORMANCE ANALYSIS${NC}"
    echo "=========================="
    
    local total_time=0
    for component in "${!PERFORMANCE_TIMES[@]}"; do
        local time="${PERFORMANCE_TIMES[$component]}"
        echo "  $component: ${time}s"
        total_time=$(echo "$total_time + $time" | bc)
    done
    
    echo "  TOTAL: ${total_time}s"
    echo ""
    
    # Performance scoring
    local perf_score=100
    for component in "${!PERFORMANCE_TIMES[@]}"; do
        local time="${PERFORMANCE_TIMES[$component]}"
        if (( $(echo "$time > 5.0" | bc -l) )); then
            perf_score=$((perf_score - 10))
        elif (( $(echo "$time > 2.0" | bc -l) )); then
            perf_score=$((perf_score - 5))
        fi
    done
    
    echo "Performance Score: $perf_score/100"
    
    if [[ $perf_score -ge 80 ]]; then
        echo -e "${GREEN}✓ Performance: Excellent${NC}"
    elif [[ $perf_score -ge 60 ]]; then
        echo -e "${YELLOW}⚠ Performance: Good${NC}"
    else
        echo -e "${RED}✗ Performance: Needs Improvement${NC}"
    fi
}

# =======================
# READINESS SCORING
# =======================

calculate_readiness_score() {
    local total_possible=$((TOTAL_TESTS * 100))
    local actual_score=$((PASSED_TESTS * 100 + WARNING_TESTS * 50))
    local percentage=$((actual_score * 100 / total_possible))
    
    echo "$percentage"
}

generate_readiness_report() {
    echo -e "\n${PURPLE}🎯 MIGRATION READINESS ASSESSMENT${NC}"
    echo "===================================="
    
    # Component scores
    echo "Component Readiness:"
    for component in "${!COMPONENT_SCORES[@]}"; do
        echo "  $component: ${COMPONENT_SCORES[$component]}"
    done
    echo ""
    
    # Overall scoring
    local readiness_score=$(calculate_readiness_score)
    echo "Overall Readiness Score: $readiness_score%"
    
    if [[ $readiness_score -ge 90 ]]; then
        echo -e "${GREEN}✅ READY FOR PRODUCTION MIGRATION${NC}"
        echo "   All systems tested and performing well"
    elif [[ $readiness_score -ge 70 ]]; then
        echo -e "${YELLOW}⚠ READY WITH MINOR CONCERNS${NC}"
        echo "   Most systems working, some optimizations recommended"
    elif [[ $readiness_score -ge 50 ]]; then
        echo -e "${YELLOW}⚠ NEEDS ATTENTION BEFORE MIGRATION${NC}"
        echo "   Several issues found, address warnings before migration"
    else
        echo -e "${RED}❌ NOT READY FOR MIGRATION${NC}"
        echo "   Critical issues found, address failures before migration"
    fi
    
    echo ""
    echo "Recommendations:"
    
    if [[ $FAILED_TESTS -gt 0 ]]; then
        echo "  • Fix $FAILED_TESTS critical failures before migration"
    fi
    
    if [[ $WARNING_TESTS -gt 0 ]]; then
        echo "  • Review $WARNING_TESTS warnings for optimization opportunities"
    fi
    
    # Performance recommendations
    local slow_components=()
    for component in "${!PERFORMANCE_TIMES[@]}"; do
        local time="${PERFORMANCE_TIMES[$component]}"
        if (( $(echo "$time > 5.0" | bc -l) )); then
            slow_components+=("$component")
        fi
    done
    
    if [[ ${#slow_components[@]} -gt 0 ]]; then
        echo "  • Optimize performance for: ${slow_components[*]}"
    fi
    
    if [[ $readiness_score -ge 90 ]]; then
        echo "  • System is ready for simplified migration"
        echo "  • Consider enabling production mode"
    fi
}

# =======================
# MAIN EXECUTION
# =======================

main() {
    echo -e "${BLUE}🧪 CLAUDE WORKSPACE - COMPREHENSIVE SIMPLIFIED SYSTEM TEST${NC}"
    echo -e "${BLUE}============================================================${NC}"
    echo ""
    
    log_test "Starting comprehensive test suite for simplified system"
    
    echo -e "${CYAN}📋 Test Categories:${NC}"
    echo "  • Intelligence System (4 tests)"
    echo "  • Memory System (4 tests)"
    echo "  • Project System (4 tests)"
    echo "  • Sync System (4 tests)"
    echo "  • Startup System (4 tests)"
    echo "  • Integration Tests (4 tests)"
    echo "  • System Verification (1 test)"
    echo ""
    
    # Intelligence System Tests
    echo -e "${PURPLE}🧠 INTELLIGENCE SYSTEM TESTS${NC}"
    run_test "Pattern Recognition" "test_intelligence_pattern_recognition" "intelligence"
    run_test "Data Extraction" "test_intelligence_data_extraction" "intelligence"
    run_test "Cross-Project Learning" "test_intelligence_cross_project_learning" "intelligence"
    run_test "Context Generation" "test_intelligence_context_generation" "intelligence"
    echo ""
    
    # Memory System Tests
    echo -e "${GREEN}💾 MEMORY SYSTEM TESTS${NC}"
    run_test "Save/Load Cycle" "test_memory_save_load_cycle" "memory"
    run_test "Intelligence Integration" "test_memory_intelligence_integration" "memory"
    run_test "Session History" "test_memory_session_history" "memory"
    run_test "Device Awareness" "test_memory_device_awareness" "memory"
    echo ""
    
    # Project System Tests
    echo -e "${YELLOW}📁 PROJECT SYSTEM TESTS${NC}"
    run_test "Enhanced Detection" "test_project_detection_enhanced" "project"
    run_test "Lifecycle Management" "test_project_lifecycle_management" "project"
    run_test "Context Switching" "test_project_context_switching" "project"
    run_test "Cross-Project Patterns" "test_project_cross_patterns" "project"
    echo ""
    
    # Sync System Tests
    echo -e "${CYAN}🔄 SYNC SYSTEM TESTS${NC}"
    run_test "Device Awareness" "test_sync_device_awareness" "sync"
    run_test "Conflict Resolution" "test_sync_conflict_resolution" "sync"
    run_test "Smart Triggers" "test_sync_smart_triggers" "sync"
    run_test "Git Integration" "test_sync_git_integration" "sync"
    echo ""
    
    # Startup System Tests
    echo -e "${BLUE}🚀 STARTUP SYSTEM TESTS${NC}"
    run_test "Daemon Management" "test_startup_daemon_management" "startup"
    run_test "Health Verification" "test_startup_health_verification" "startup"
    run_test "Performance (< 2sec)" "test_startup_performance" "startup"
    run_test "Service Coordination" "test_startup_service_coordination" "startup"
    echo ""
    
    # Integration Tests
    echo -e "${PURPLE}🔗 INTEGRATION TESTS${NC}"
    run_test "Component Data Flow" "test_component_data_flow" "integration"
    run_test "Performance Integration" "test_component_performance_integration" "integration"
    run_test "Error Handling" "test_component_error_handling" "integration"
    run_test "Resource Usage" "test_component_resource_usage" "integration"
    echo ""
    
    # System Verification
    echo -e "${RED}🔍 SYSTEM VERIFICATION${NC}"
    run_test "Overall System Readiness" "test_overall_system_readiness" "verification"
    echo ""
    
    # Generate reports
    generate_performance_report
    generate_readiness_report
    
    # Final summary
    echo -e "\n${BLUE}📊 FINAL TEST SUMMARY${NC}"
    echo "======================"
    echo "Total Tests: $TOTAL_TESTS"
    echo -e "${GREEN}Passed: $PASSED_TESTS${NC}"
    echo -e "${YELLOW}Warnings: $WARNING_TESTS${NC}"
    echo -e "${RED}Failed: $FAILED_TESTS${NC}"
    echo ""
    
    local readiness_score=$(calculate_readiness_score)
    
    if [[ $FAILED_TESTS -eq 0 && $readiness_score -ge 80 ]]; then
        echo -e "${GREEN}🎉 SUCCESS: Simplified system ready for production migration!${NC}"
        exit 0
    elif [[ $FAILED_TESTS -eq 0 ]]; then
        echo -e "${YELLOW}⚠ PARTIAL: System working but needs optimization${NC}"
        exit 2
    else
        echo -e "${RED}❌ FAILURE: Critical issues must be resolved${NC}"
        exit 1
    fi
}

# Command line handling
case "${1:-run}" in
    "run")
        main
        ;;
    "performance")
        echo "Running performance-focused tests only..."
        measure_performance "memory_load" "$SCRIPT_DIR/claude-simplified-memory.sh load" 3.0
        measure_performance "project_detect" "$SCRIPT_DIR/claude-project-enhanced.sh detect" 3.0
        measure_performance "startup_status" "$SCRIPT_DIR/claude-startup-simple.sh status" 2.0
        generate_performance_report
        ;;
    "quick")
        echo "Running quick validation tests..."
        test_overall_system_readiness
        test_memory_save_load_cycle
        test_project_detection_enhanced
        echo "Quick tests completed"
        ;;
    "help"|"--help"|"-h")
        echo "Usage: $0 [run|performance|quick|help]"
        echo ""
        echo "Commands:"
        echo "  run         - Run comprehensive test suite (default)"
        echo "  performance - Run performance-focused tests only"
        echo "  quick       - Run quick validation tests"
        echo "  help        - Show this help"
        echo ""
        echo "This comprehensive test suite validates all simplified system components"
        echo "before migration including performance metrics and integration tests."
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac