#!/bin/bash
# Test JSON Locking System - Comprehensive test for safe JSON operations on real workspace files

WORKSPACE_DIR="$HOME/claude-workspace"
source "$WORKSPACE_DIR/scripts/json-safe-operations.sh"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Test files (critical workspace JSON files)
TEST_FILES=(
    "memory/enhanced-context.json"
    "sync/config.json"
    "autonomous/service-status.json"
    "intelligence/auto-learnings.json"
    "settings.local.json"
)

echo -e "${BLUE}🧪 Testing JSON Locking System on Real Workspace Files${NC}"
echo

# Test 1: Basic read/write operations
test_basic_operations() {
    echo -e "${CYAN}Test 1: Basic Read/Write Operations${NC}"
    local passed=0
    local total=0
    
    for file in "${TEST_FILES[@]}"; do
        echo -n "  Testing $file... "
        ((total++))
        
        # Test read
        local original_data
        original_data=$(safe_json_read "$file" "{}")
        if [[ $? -eq 0 ]]; then
            # Test write (write the same data back)
            if safe_json_write "$file" "$original_data" > /dev/null 2>&1; then
                echo -e "${GREEN}✓${NC}"
                ((passed++))
            else
                echo -e "${RED}✗ (write failed)${NC}"
            fi
        else
            echo -e "${RED}✗ (read failed)${NC}"
        fi
    done
    
    echo "  Result: $passed/$total tests passed"
    return $((total - passed))
}

# Test 2: Concurrent access simulation
test_concurrent_access() {
    echo -e "${CYAN}Test 2: Concurrent Access Simulation${NC}"
    
    # Use a test file for concurrent access
    local test_file="test/concurrent-test.json"
    local initial_data='{"counter": 0, "workers": {}, "test_start": "'$(date -Iseconds)'"}'
    
    # Initialize test file
    safe_json_write "$test_file" "$initial_data" > /dev/null
    
    echo "  Starting 5 concurrent workers..."
    
    # Start multiple workers that update the same file
    local pids=()
    for i in {1..5}; do
        (
            for j in {1..3}; do
                local worker_data="{\"worker_${i}_update_${j}\": \"$(date -Iseconds)\", \"pid\": $$}"
                safe_json_merge "$test_file" "$worker_data" > /dev/null 2>&1
                sleep 0.1
            done
        ) &
        pids+=($!)
    done
    
    # Wait for all workers
    local failed=0
    for pid in "${pids[@]}"; do
        if ! wait "$pid"; then
            ((failed++))
        fi
    done
    
    # Check final state
    local final_data
    final_data=$(safe_json_read "$test_file")
    local worker_count=$(echo "$final_data" | python3 -c "
import json, sys
data = json.load(sys.stdin)
count = sum(1 for key in data.keys() if key.startswith('worker_'))
print(count)
" 2>/dev/null || echo "0")
    
    echo "  Workers that failed: $failed/5"
    echo "  Worker updates recorded: $worker_count/15"
    
    # Cleanup
    rm -f "$WORKSPACE_DIR/.claude/$test_file"
    
    if [[ $failed -eq 0 ]] && [[ $worker_count -ge 10 ]]; then
        echo -e "  Result: ${GREEN}✓ Concurrent access test passed${NC}"
        return 0
    else
        echo -e "  Result: ${RED}✗ Concurrent access test failed${NC}"
        return 1
    fi
}

# Test 3: Lock cleanup verification
test_lock_cleanup() {
    echo -e "${CYAN}Test 3: Lock Cleanup Verification${NC}"
    
    # Create some fake old lock files
    local locks_dir="$WORKSPACE_DIR/.claude/locks"
    mkdir -p "$locks_dir"
    
    # Create old lock files
    local old_lock1="$locks_dir/old_test_1.lock"
    local old_lock2="$locks_dir/old_test_2.lock"
    
    echo "999999" > "$old_lock1"  # Non-existent PID
    echo "999998" > "$old_lock2"  # Non-existent PID
    
    # Make them old
    touch -t 202501010000 "$old_lock1" "$old_lock2"
    
    local initial_locks=$(find "$locks_dir" -name "*.lock" | wc -l)
    
    # Run cleanup
    cleanup_orphaned_locks 60  # 1 minute max age
    
    local final_locks=$(find "$locks_dir" -name "*.lock" | wc -l)
    local cleaned=$((initial_locks - final_locks))
    
    echo "  Locks before cleanup: $initial_locks"
    echo "  Locks after cleanup: $final_locks"
    echo "  Locks cleaned: $cleaned"
    
    if [[ $cleaned -ge 2 ]]; then
        echo -e "  Result: ${GREEN}✓ Lock cleanup test passed${NC}"
        return 0
    else
        echo -e "  Result: ${RED}✗ Lock cleanup test failed${NC}"
        return 1
    fi
}

# Test 4: Error handling and rollback
test_error_handling() {
    echo -e "${CYAN}Test 4: Error Handling and Rollback${NC}"
    
    local test_file="test/error-test.json"
    local valid_data='{"test": "valid", "timestamp": "'$(date -Iseconds)'"}'
    local invalid_data='{"test": invalid json}'
    
    # Create test file with valid data
    safe_json_write "$test_file" "$valid_data" > /dev/null
    local original_content=$(safe_json_read "$test_file")
    
    # Try to write invalid JSON
    if safe_json_write "$test_file" "$invalid_data" > /dev/null 2>&1; then
        echo -e "  Result: ${RED}✗ Invalid JSON was accepted${NC}"
        return 1
    fi
    
    # Check that original data is preserved
    local preserved_content=$(safe_json_read "$test_file")
    
    if [[ "$original_content" == "$preserved_content" ]]; then
        echo -e "  Result: ${GREEN}✓ Error handling test passed${NC}"
        rm -f "$WORKSPACE_DIR/.claude/$test_file"
        return 0
    else
        echo -e "  Result: ${RED}✗ Original data was corrupted${NC}"
        return 1
    fi
}

# Test 5: Performance benchmark
test_performance() {
    echo -e "${CYAN}Test 5: Performance Benchmark${NC}"
    
    local test_file="test/performance-test.json"
    local test_data='{"benchmark": true, "data": {"key1": "value1", "key2": "value2", "nested": {"a": 1, "b": 2}}}'
    
    # Benchmark write operations
    local start_time=$(date +%s.%N)
    for i in {1..50}; do
        safe_json_write "$test_file" "$test_data" > /dev/null 2>&1
    done
    local end_time=$(date +%s.%N)
    
    local write_time=$(echo "$end_time - $start_time" | bc -l)
    local writes_per_second=$(echo "scale=2; 50 / $write_time" | bc -l)
    
    echo "  50 write operations: ${write_time}s"
    echo "  Write performance: ${writes_per_second} ops/sec"
    
    # Benchmark read operations
    start_time=$(date +%s.%N)
    for i in {1..100}; do
        safe_json_read "$test_file" > /dev/null 2>&1
    done
    end_time=$(date +%s.%N)
    
    local read_time=$(echo "$end_time - $start_time" | bc -l)
    local reads_per_second=$(echo "scale=2; 100 / $read_time" | bc -l)
    
    echo "  100 read operations: ${read_time}s"
    echo "  Read performance: ${reads_per_second} ops/sec"
    
    # Cleanup
    rm -f "$WORKSPACE_DIR/.claude/$test_file"
    
    # Performance is acceptable if we can do at least 10 ops/sec
    local acceptable_write=$(echo "$writes_per_second >= 10" | bc -l)
    local acceptable_read=$(echo "$reads_per_second >= 20" | bc -l)
    
    if [[ $acceptable_write -eq 1 ]] && [[ $acceptable_read -eq 1 ]]; then
        echo -e "  Result: ${GREEN}✓ Performance benchmark passed${NC}"
        return 0
    else
        echo -e "  Result: ${YELLOW}⚠ Performance could be better${NC}"
        return 0  # Not a failure, just a warning
    fi
}

# Run all tests
run_all_tests() {
    echo -e "${BLUE}Running comprehensive JSON locking tests...${NC}"
    echo
    
    local passed=0
    local total=5
    
    test_basic_operations && ((passed++))
    echo
    
    test_concurrent_access && ((passed++))
    echo
    
    test_lock_cleanup && ((passed++))
    echo
    
    test_error_handling && ((passed++))
    echo
    
    test_performance && ((passed++))
    echo
    
    echo -e "${BLUE}🏁 Test Summary${NC}"
    echo "Tests passed: $passed/$total"
    
    if [[ $passed -eq $total ]]; then
        echo -e "${GREEN}✅ All tests passed! JSON locking system is working correctly.${NC}"
        return 0
    else
        echo -e "${RED}❌ Some tests failed. JSON locking system needs attention.${NC}"
        return 1
    fi
}

# Command handling
case "${1:-all}" in
    "all")
        run_all_tests
        ;;
    "basic")
        test_basic_operations
        ;;
    "concurrent")
        test_concurrent_access
        ;;
    "cleanup")
        test_lock_cleanup
        ;;
    "error")
        test_error_handling
        ;;
    "performance")
        test_performance
        ;;
    "status")
        show_json_status
        ;;
    "help")
        echo "JSON Locking Test Suite"
        echo
        echo "Usage: $0 [test]"
        echo
        echo "Tests:"
        echo "  all          - Run all tests (default)"
        echo "  basic        - Test basic read/write operations"
        echo "  concurrent   - Test concurrent access"
        echo "  cleanup      - Test lock cleanup"
        echo "  error        - Test error handling"
        echo "  performance  - Run performance benchmark"
        echo "  status       - Show JSON operations status"
        ;;
    *)
        echo "Unknown test: $1"
        echo "Run '$0 help' for usage information"
        exit 1
        ;;
esac