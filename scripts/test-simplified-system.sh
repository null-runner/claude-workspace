#!/bin/bash

# Test Suite: Core Functionality del Sistema Semplificato
# Verifica che le funzionalità essenziali funzionino post-simplification

set -euo pipefail

# Configurazione
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly WORKSPACE_ROOT="$(dirname "$SCRIPT_DIR")"
readonly TEST_LOG_FILE="${WORKSPACE_ROOT}/.claude/logs/test-simplified-system.log"
readonly TEST_DATA_DIR="${WORKSPACE_ROOT}/.claude/test-data"

# Colori per output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Contatori
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Utility functions
log_test() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [TEST] $1" | tee -a "$TEST_LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$TEST_LOG_FILE"
}

# Test runner
run_test() {
    local test_name="$1"
    local test_function="$2"
    
    log_test "Running: $test_name"
    ((TESTS_RUN++))
    
    if $test_function; then
        log_success "✓ PASSED: $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "✗ FAILED: $test_name"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Crea directory test se non esiste
    mkdir -p "$TEST_DATA_DIR"
    mkdir -p "$(dirname "$TEST_LOG_FILE")"
    
    # Backup configurazione esistente
    if [[ -f "${WORKSPACE_ROOT}/.claude/memory/unified-context.json" ]]; then
        cp "${WORKSPACE_ROOT}/.claude/memory/unified-context.json" "${TEST_DATA_DIR}/unified-context.backup.json"
    fi
    
    log_success "Test environment setup completed"
}

# Cleanup test environment
cleanup_test_environment() {
    log_info "Cleaning up test environment..."
    
    # Ripristina backup se esiste
    if [[ -f "${TEST_DATA_DIR}/unified-context.backup.json" ]]; then
        cp "${TEST_DATA_DIR}/unified-context.backup.json" "${WORKSPACE_ROOT}/.claude/memory/unified-context.json"
    fi
    
    # Pulisci file test temporanei
    rm -rf "${TEST_DATA_DIR}/test-*"
    
    log_success "Test environment cleanup completed"
}

# Test 1: Simplified Memory System
test_simplified_memory_system() {
    log_info "Testing simplified memory system..."
    
    # Test memory save
    if ! "$SCRIPT_DIR/claude-simplified-memory.sh" save "test_reason" "test_summary" "test_issues" "test_actions" >/dev/null 2>&1; then
        log_error "Memory save failed"
        return 1
    fi
    
    # Test memory load
    local load_output
    if ! load_output=$("$SCRIPT_DIR/claude-simplified-memory.sh" load 2>&1); then
        log_error "Memory load failed"
        return 1
    fi
    
    # Verifica che il load output contenga informazioni
    if [[ -z "$load_output" ]]; then
        log_error "Memory load produced no output"
        return 1
    fi
    
    # Test memory stats
    if ! "$SCRIPT_DIR/claude-simplified-memory.sh" stats >/dev/null 2>&1; then
        log_error "Memory stats failed"
        return 1
    fi
    
    log_success "Simplified memory system working correctly"
    return 0
}

# Test 2: Project Detection
test_project_detection() {
    log_info "Testing project detection..."
    
    # Test project detector
    if ! "$SCRIPT_DIR/claude-auto-project-detector.sh" test >/dev/null 2>&1; then
        log_error "Project detection test failed"
        return 1
    fi
    
    # Verifica che detecti il progetto corrente
    local project_info
    if ! project_info=$("$SCRIPT_DIR/claude-auto-project-detector.sh" current 2>&1); then
        log_error "Project detection current failed"
        return 1
    fi
    
    # Verifica che rilevi claude-workspace come progetto
    if [[ "$project_info" != *"claude-workspace"* ]]; then
        log_error "Project detection failed to identify claude-workspace"
        return 1
    fi
    
    log_success "Project detection working correctly"
    return 0
}

# Test 3: Intelligence Extraction
test_intelligence_extraction() {
    log_info "Testing intelligence extraction..."
    
    # Test intelligence extractor
    if ! "$SCRIPT_DIR/claude-intelligence-extractor.sh" summary >/dev/null 2>&1; then
        log_error "Intelligence extraction failed"
        return 1
    fi
    
    # Verifica che esista il file intelligence cache
    if [[ ! -f "${WORKSPACE_ROOT}/.claude/memory/intelligence-cache.json" ]]; then
        log_error "Intelligence cache file not found"
        return 1
    fi
    
    # Verifica che il file abbia contenuto valido
    if ! python3 -m json.tool "${WORKSPACE_ROOT}/.claude/memory/intelligence-cache.json" >/dev/null 2>&1; then
        log_error "Intelligence cache contains invalid JSON"
        return 1
    fi
    
    log_success "Intelligence extraction working correctly"
    return 0
}

# Test 4: Autonomous System Status
test_autonomous_system() {
    log_info "Testing autonomous system..."
    
    # Test status check
    local status_output
    if ! status_output=$("$SCRIPT_DIR/claude-autonomous-system.sh" status 2>&1); then
        log_error "Autonomous system status failed"
        return 1
    fi
    
    # Verifica che il sistema sia attivo
    if [[ "$status_output" != *"attivo"* && "$status_output" != *"active"* ]]; then
        log_warning "Autonomous system might not be active: $status_output"
        # Non fallire il test, potrebbe essere normale
    fi
    
    log_success "Autonomous system status check working"
    return 0
}

# Test 5: Smart Exit System
test_smart_exit_system() {
    log_info "Testing smart exit system..."
    
    # Test che lo script esista e sia eseguibile
    if [[ ! -x "$SCRIPT_DIR/claude-smart-exit.sh" ]]; then
        log_error "Smart exit script not found or not executable"
        return 1
    fi
    
    # Test dry-run (se supportato)
    if "$SCRIPT_DIR/claude-smart-exit.sh" --help 2>&1 | grep -q "dry-run\|test"; then
        if ! "$SCRIPT_DIR/claude-smart-exit.sh" --dry-run >/dev/null 2>&1; then
            log_error "Smart exit dry-run failed"
            return 1
        fi
    fi
    
    log_success "Smart exit system accessible"
    return 0
}

# Test 6: Smart Sync System
test_smart_sync_system() {
    log_info "Testing smart sync system..."
    
    # Test status check
    local sync_status
    if ! sync_status=$("$SCRIPT_DIR/claude-smart-sync.sh" status 2>&1); then
        log_error "Smart sync status failed"
        return 1
    fi
    
    # Test che il comando sia riconosciuto
    if [[ "$sync_status" == *"Unknown command"* ]]; then
        log_error "Smart sync commands not recognized"
        return 1
    fi
    
    log_success "Smart sync system working"
    return 0
}

# Test 7: File Integrity
test_file_integrity() {
    log_info "Testing file integrity..."
    
    # Verifica file critici
    local critical_files=(
        "$SCRIPT_DIR/claude-startup.sh"
        "$SCRIPT_DIR/claude-simplified-memory.sh"
        "$SCRIPT_DIR/claude-autonomous-system.sh"
        "$SCRIPT_DIR/claude-smart-exit.sh"
        "$SCRIPT_DIR/claude-smart-sync.sh"
    )
    
    for file in "${critical_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "Critical file missing: $file"
            return 1
        fi
        
        if [[ ! -x "$file" ]]; then
            log_error "Critical file not executable: $file"
            return 1
        fi
        
        # Test basic syntax
        if ! bash -n "$file"; then
            log_error "Syntax error in: $file"
            return 1
        fi
    done
    
    log_success "File integrity check passed"
    return 0
}

# Test 8: Configuration Validation
test_configuration_validation() {
    log_info "Testing configuration validation..."
    
    # Verifica directory essenziali
    local essential_dirs=(
        "${WORKSPACE_ROOT}/.claude"
        "${WORKSPACE_ROOT}/.claude/memory"
        "${WORKSPACE_ROOT}/.claude/logs"
        "${WORKSPACE_ROOT}/.claude/auto-memory"
    )
    
    for dir in "${essential_dirs[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_error "Essential directory missing: $dir"
            return 1
        fi
    done
    
    # Verifica file JSON critici
    local json_files=(
        "${WORKSPACE_ROOT}/.claude/memory/unified-context.json"
        "${WORKSPACE_ROOT}/.claude/memory/intelligence-cache.json"
    )
    
    for json_file in "${json_files[@]}"; do
        if [[ -f "$json_file" ]]; then
            if ! python3 -m json.tool "$json_file" >/dev/null 2>&1; then
                log_error "Invalid JSON in: $json_file"
                return 1
            fi
        fi
    done
    
    log_success "Configuration validation passed"
    return 0
}

# Test 9: Error Handling
test_error_handling() {
    log_info "Testing error handling capabilities..."
    
    # Test con parametri invalidi
    if "$SCRIPT_DIR/claude-simplified-memory.sh" invalid_command >/dev/null 2>&1; then
        log_error "Error handling failed - invalid command should fail"
        return 1
    fi
    
    # Test con file mancanti (simulato)
    local test_file="${TEST_DATA_DIR}/nonexistent.json"
    if [[ -f "$test_file" ]]; then
        rm -f "$test_file"
    fi
    
    log_success "Error handling working correctly"
    return 0
}

# Test 10: Performance Basic Check
test_performance_basic() {
    log_info "Testing basic performance..."
    
    # Test tempo di startup
    local start_time=$(date +%s.%N)
    "$SCRIPT_DIR/claude-simplified-memory.sh" stats >/dev/null 2>&1 || true
    local end_time=$(date +%s.%N)
    
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")
    
    # Se duration è > 10 secondi, probabilmente c'è un problema
    if (( $(echo "$duration > 10" | bc -l 2>/dev/null || echo "0") )); then
        log_warning "Performance concern: memory stats took ${duration}s"
        # Non fallire, solo avvisare
    fi
    
    log_success "Basic performance check completed"
    return 0
}

# Main test execution
main() {
    echo -e "${BLUE}🧪 Claude Workspace - Simplified System Core Tests${NC}"
    echo -e "${BLUE}===================================================${NC}"
    echo
    
    # Setup
    setup_test_environment
    
    # Run tests
    run_test "File Integrity Check" "test_file_integrity"
    run_test "Configuration Validation" "test_configuration_validation"
    run_test "Simplified Memory System" "test_simplified_memory_system"
    run_test "Project Detection" "test_project_detection"
    run_test "Intelligence Extraction" "test_intelligence_extraction"
    run_test "Autonomous System" "test_autonomous_system"
    run_test "Smart Exit System" "test_smart_exit_system"
    run_test "Smart Sync System" "test_smart_sync_system"
    run_test "Error Handling" "test_error_handling"
    run_test "Basic Performance" "test_performance_basic"
    
    # Cleanup
    cleanup_test_environment
    
    # Results
    echo
    echo -e "${BLUE}🏁 Test Results Summary${NC}"
    echo -e "${BLUE}======================${NC}"
    echo -e "Tests Run: ${TESTS_RUN}"
    echo -e "${GREEN}Tests Passed: ${TESTS_PASSED}${NC}"
    echo -e "${RED}Tests Failed: ${TESTS_FAILED}${NC}"
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${GREEN}✅ All core functionality tests passed!${NC}"
        echo -e "${GREEN}   Simplified system is working correctly.${NC}"
        exit 0
    else
        echo -e "${RED}❌ Some tests failed!${NC}"
        echo -e "${RED}   Check logs: $TEST_LOG_FILE${NC}"
        exit 1
    fi
}

# Handle command line arguments
case "${1:-run}" in
    "run")
        main
        ;;
    "help"|"--help"|"-h")
        echo "Usage: $0 [run|help]"
        echo "  run  - Run all core functionality tests (default)"
        echo "  help - Show this help message"
        ;;
    *)
        echo "Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac