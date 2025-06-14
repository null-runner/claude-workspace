#!/bin/bash
# Test Migration Readiness - Verifica che il sistema sia pronto per la migrazione

set -euo pipefail

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}Migration Readiness Test${NC}"
echo ""

TESTS_PASSED=0
TESTS_FAILED=0

# Helper function for tests
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    echo -en "Testing $test_name... "
    
    if eval "$test_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# Test 1: Check current system status
echo -e "${BLUE}=== Current System Status ===${NC}"
run_test "Complex system running" "[[ -f '$WORKSPACE_DIR/scripts/claude-autonomous-system.sh' ]] && '$WORKSPACE_DIR/scripts/claude-autonomous-system.sh' status | grep -q 'RUNNING'"

# Test 2: Check simplified scripts exist
echo -e "${BLUE}=== Simplified System Components ===${NC}"
run_test "Simplified startup script" "[[ -f '$WORKSPACE_DIR/scripts/claude-startup-simple.sh' ]]"
run_test "Simplified memory script" "[[ -f '$WORKSPACE_DIR/scripts/claude-simplified-memory.sh' ]]"
run_test "Auto context script" "[[ -f '$WORKSPACE_DIR/scripts/claude-auto-context.sh' ]]"
run_test "Intelligence extractor" "[[ -f '$WORKSPACE_DIR/scripts/claude-intelligence-extractor.sh' ]]"
run_test "Smart sync script" "[[ -f '$WORKSPACE_DIR/scripts/claude-smart-sync.sh' ]]"

# Test 3: Check daemon scripts
echo -e "${BLUE}=== Daemon Scripts ===${NC}"
run_test "Intelligence daemon" "[[ -f '$WORKSPACE_DIR/scripts/claude-intelligence-daemon.sh' ]]"
run_test "Sync daemon" "[[ -f '$WORKSPACE_DIR/scripts/claude-sync-daemon.sh' ]]"

# Test 4: Check data directories
echo -e "${BLUE}=== Data Directories ===${NC}"
run_test "Memory directory" "[[ -d '$WORKSPACE_DIR/.claude/memory' ]]"
run_test "Intelligence directory" "[[ -d '$WORKSPACE_DIR/.claude/intelligence' ]]"
run_test "Projects directory" "[[ -d '$WORKSPACE_DIR/.claude/projects' ]]"
run_test "Logs directory" "[[ -d '$WORKSPACE_DIR/.claude/logs' ]]"

# Test 5: Check backup space
echo -e "${BLUE}=== Backup Requirements ===${NC}"
run_test "Backup directory writable" "mkdir -p '$WORKSPACE_DIR/.claude/migration-backups' && [[ -w '$WORKSPACE_DIR/.claude/migration-backups' ]]"
run_test "Sufficient disk space" "[[ \$(df '$WORKSPACE_DIR' | tail -1 | awk '{print \$4}') -gt 1000000 ]]"  # >1GB free

# Test 6: Check git status
echo -e "${BLUE}=== Git Repository ===${NC}"
run_test "Git repository" "cd '$WORKSPACE_DIR' && git status >/dev/null 2>&1"
run_test "Git clean working tree" "cd '$WORKSPACE_DIR' && [[ -z \$(git status --porcelain 2>/dev/null) ]]" || {
    echo -e "${YELLOW}  Warning: Working tree has uncommitted changes${NC}"
    echo -e "${YELLOW}  Recommendation: Commit changes before migration${NC}"
}

# Test 7: Check migration script
echo -e "${BLUE}=== Migration Tool ===${NC}"
run_test "Migration script exists" "[[ -f '$WORKSPACE_DIR/scripts/claude-migrate.sh' ]]"
run_test "Migration script executable" "[[ -x '$WORKSPACE_DIR/scripts/claude-migrate.sh' ]]"
run_test "Migration help works" "'$WORKSPACE_DIR/scripts/claude-migrate.sh' help"

echo ""
echo -e "${BOLD}=== Test Summary ===${NC}"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}✅ System is ready for migration!${NC}"
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "1. Create backup: ./scripts/claude-migrate.sh backup"
    echo "2. Run migration: ./scripts/claude-migrate.sh migrate"
    echo "3. Verify results: ./scripts/claude-migrate.sh status"
    exit 0
elif [[ $TESTS_FAILED -le 2 ]]; then
    echo ""
    echo -e "${YELLOW}⚠️  System has minor issues but migration may still work${NC}"
    echo -e "${YELLOW}Consider running: ./scripts/claude-migrate.sh test${NC}"
    exit 1
else
    echo ""
    echo -e "${RED}❌ System has significant issues - migration not recommended${NC}"
    echo -e "${RED}Please resolve failed tests before attempting migration${NC}"
    exit 2
fi