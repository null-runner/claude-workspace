#!/bin/bash
# Claude Workspace - Auto-Sync Performance Benchmark Suite
# Comprehensive performance testing and monitoring

WORKSPACE_DIR="$HOME/claude-workspace"
BENCHMARK_DIR="$WORKSPACE_DIR/.claude/benchmarks"
RESULTS_FILE="$BENCHMARK_DIR/benchmark-results-$(date +%Y%m%d-%H%M%S).json"

mkdir -p "$BENCHMARK_DIR"

# Utility functions
log() {
    echo "[$(date '+%H:%M:%S')] $*"
}

measure_time() {
    local start=$(date +%s.%N)
    "$@"
    local end=$(date +%s.%N)
    echo "$(echo "$end - $start" | bc -l)"
}

measure_memory() {
    local pid="$1"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        ps -o rss= -p "$pid" | tr -d ' '
    else
        echo "0"
    fi
}

# Benchmark 1: File System Traversal Performance
benchmark_file_traversal() {
    log "🔍 Benchmarking file system traversal..."
    
    local results=()
    
    # Test 1: Find all files
    local time1=$(measure_time find "$WORKSPACE_DIR" -type f | wc -l)
    results+=("\"find_all_files\": {\"time\": $time1, \"files\": $(find "$WORKSPACE_DIR" -type f | wc -l)}")
    
    # Test 2: Find JSON files only
    local time2=$(measure_time find "$WORKSPACE_DIR" -name "*.json" | wc -l)
    results+=("\"find_json_files\": {\"time\": $time2, \"files\": $(find "$WORKSPACE_DIR" -name "*.json" | wc -l)}")
    
    # Test 3: Find with exclusions
    local time3=$(measure_time find "$WORKSPACE_DIR" -type f -not -path "*/.git/*" -not -name "*.tmp" | wc -l)
    results+=("\"find_filtered\": {\"time\": $time3, \"files\": $(find "$WORKSPACE_DIR" -type f -not -path "*/.git/*" -not -name "*.tmp" | wc -l)}")
    
    echo "{$(IFS=','; echo "${results[*]}")}"
}

# Benchmark 2: inotifywait Performance
benchmark_inotify_performance() {
    log "👁️  Benchmarking inotifywait performance..."
    
    local results=()
    local test_dir="$BENCHMARK_DIR/inotify-test"
    mkdir -p "$test_dir"
    
    # Test 1: Basic inotifywait on single directory
    inotifywait -m -t 5 "$test_dir" >/dev/null 2>&1 &
    local pid1=$!
    sleep 1
    local mem1=$(measure_memory $pid1)
    
    # Generate test events
    local start=$(date +%s.%N)
    for i in {1..10}; do
        echo "test $i" > "$test_dir/test$i.txt"
        rm "$test_dir/test$i.txt"
    done
    local end=$(date +%s.%N)
    local event_time=$(echo "$end - $start" | bc -l)
    
    kill $pid1 2>/dev/null
    results+=("\"single_dir\": {\"memory_kb\": $mem1, \"event_time\": $event_time}")
    
    # Test 2: Recursive inotifywait on workspace
    timeout 5s inotifywait -m -r "$WORKSPACE_DIR" >/dev/null 2>&1 &
    local pid2=$!
    sleep 2
    local mem2=$(measure_memory $pid2)
    kill $pid2 2>/dev/null
    
    results+=("\"recursive_workspace\": {\"memory_kb\": $mem2}")
    
    # Test 3: Filtered inotifywait
    timeout 5s inotifywait -m -r --include '\.(sh|json|md)$' "$WORKSPACE_DIR" >/dev/null 2>&1 &
    local pid3=$!
    sleep 2
    local mem3=$(measure_memory $pid3)
    kill $pid3 2>/dev/null
    
    results+=("\"filtered_workspace\": {\"memory_kb\": $mem3}")
    
    rm -rf "$test_dir"
    echo "{$(IFS=','; echo "${results[*]}")}"
}

# Benchmark 3: Git Operation Performance
benchmark_git_performance() {
    log "📦 Benchmarking git operations..."
    
    local results=()
    cd "$WORKSPACE_DIR"
    
    # Test 1: Git status performance
    local time1=$(measure_time git status --porcelain >/dev/null)
    results+=("\"git_status\": {\"time\": $time1}")
    
    # Test 2: Git add performance
    local test_file="$BENCHMARK_DIR/git-test-file.txt"
    echo "benchmark test" > "$test_file"
    local time2=$(measure_time git add "$test_file")
    results+=("\"git_add\": {\"time\": $time2}")
    
    # Test 3: Git commit performance
    local time3=$(measure_time git commit -m "Benchmark test commit" --quiet)
    results+=("\"git_commit\": {\"time\": $time3}")
    
    # Test 4: Git compression impact
    git config core.compression 0
    local time4a=$(measure_time git add "$test_file" && git commit --amend --no-edit --quiet)
    
    git config core.compression 9
    local time4b=$(measure_time git add "$test_file" && git commit --amend --no-edit --quiet)
    
    results+=("\"git_compression\": {\"no_compression\": $time4a, \"max_compression\": $time4b}")
    
    # Cleanup
    git reset --soft HEAD~1 >/dev/null 2>&1
    rm -f "$test_file"
    
    echo "{$(IFS=','; echo "${results[*]}")}"
}

# Benchmark 4: Hash Computation Performance
benchmark_hash_performance() {
    log "🔢 Benchmarking hash computation..."
    
    local results=()
    local test_files=()
    
    # Create test files of different sizes
    local sizes=(1 10 100 1000)  # KB
    for size in "${sizes[@]}"; do
        local test_file="$BENCHMARK_DIR/hash-test-${size}k.txt"
        dd if=/dev/zero of="$test_file" bs=1024 count=$size >/dev/null 2>&1
        test_files+=("$test_file")
    done
    
    # Test hash computation for each file
    for i in "${!test_files[@]}"; do
        local file="${test_files[$i]}"
        local size="${sizes[$i]}"
        
        local time_sha256=$(measure_time sha256sum "$file" >/dev/null)
        local time_md5=$(measure_time md5sum "$file" >/dev/null)
        
        results+=("\"${size}kb_file\": {\"sha256_time\": $time_sha256, \"md5_time\": $time_md5}")
    done
    
    # Test batch hashing
    local time_batch=$(measure_time sha256sum "${test_files[@]}" >/dev/null)
    results+=("\"batch_hash\": {\"time\": $time_batch, \"files\": ${#test_files[@]}}")
    
    # Cleanup
    rm -f "${test_files[@]}"
    
    echo "{$(IFS=','; echo "${results[*]}")}"
}

# Benchmark 5: Network Operation Simulation
benchmark_network_simulation() {
    log "🌐 Benchmarking network operation simulation..."
    
    local results=()
    cd "$WORKSPACE_DIR"
    
    # Test 1: Git fetch performance
    if git remote get-url origin >/dev/null 2>&1; then
        local time1=$(measure_time timeout 10s git fetch --dry-run origin main 2>/dev/null || true)
        results+=("\"git_fetch_dry_run\": {\"time\": $time1}")
    fi
    
    # Test 2: SSH connection time
    if [[ -f ~/.claude-access/keys/claude_deploy ]]; then
        local time2=$(measure_time timeout 5s ssh -i ~/.claude-access/keys/claude_deploy -o ConnectTimeout=5 -o BatchMode=yes git@github.com 2>/dev/null || true)
        results+=("\"ssh_connection\": {\"time\": $time2}")
    fi
    
    # Test 3: Compression impact simulation
    local test_data="$BENCHMARK_DIR/compression-test.txt"
    for i in {1..1000}; do
        echo "This is test line $i with some repeated content for compression testing" >> "$test_data"
    done
    
    local original_size=$(wc -c < "$test_data")
    local compressed_size=$(gzip -c "$test_data" | wc -c)
    local compression_ratio=$(echo "scale=2; $compressed_size * 100 / $original_size" | bc -l)
    
    results+=("\"compression_test\": {\"original_bytes\": $original_size, \"compressed_bytes\": $compressed_size, \"ratio_percent\": $compression_ratio}")
    
    rm -f "$test_data"
    
    echo "{$(IFS=','; echo "${results[*]}")}"
}

# System Resource Monitoring
monitor_system_resources() {
    log "📊 Monitoring system resources..."
    
    local results=()
    
    # CPU usage
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | sed 's/%us,//')
    results+=("\"cpu_usage_percent\": \"$cpu_usage\"")
    
    # Memory usage
    local mem_info=$(free -m | awk 'NR==2{printf "%.1f", $3*100/$2}')
    results+=("\"memory_usage_percent\": \"$mem_info\"")
    
    # Disk usage
    local disk_usage=$(df "$WORKSPACE_DIR" | awk 'NR==2{print $5}' | sed 's/%//')
    results+=("\"disk_usage_percent\": \"$disk_usage\"")
    
    # Load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | tr -d ' ')
    results+=("\"load_average\": \"$load_avg\"")
    
    # Active processes
    local claude_processes=$(ps aux | grep -c "[c]laude" || echo 0)
    results+=("\"claude_processes\": $claude_processes}")
    
    # Git repo size
    local repo_size=$(du -sh "$WORKSPACE_DIR/.git" | cut -f1)
    results+=("\"git_repo_size\": \"$repo_size\"")
    
    echo "{$(IFS=','; echo "${results[*]}")}"
}

# Main benchmark execution
run_full_benchmark() {
    log "🚀 Starting Claude Workspace Auto-Sync Performance Benchmark"
    log "============================================================="
    
    local benchmark_start=$(date +%s.%N)
    
    # System info
    local system_info="{
        \"timestamp\": \"$(date -Iseconds)\",
        \"hostname\": \"$(hostname)\",
        \"os\": \"$(uname -s)\",
        \"kernel\": \"$(uname -r)\",
        \"workspace_size\": \"$(du -sh "$WORKSPACE_DIR" | cut -f1)\",
        \"total_files\": $(find "$WORKSPACE_DIR" -type f | wc -l),
        \"git_version\": \"$(git --version | cut -d' ' -f3)\"
    }"
    
    # Run benchmarks
    local file_traversal=$(benchmark_file_traversal)
    local inotify_perf=$(benchmark_inotify_performance)
    local git_perf=$(benchmark_git_performance)
    local hash_perf=$(benchmark_hash_performance)
    local network_perf=$(benchmark_network_simulation)
    local system_resources=$(monitor_system_resources)
    
    local benchmark_end=$(date +%s.%N)
    local total_time=$(echo "$benchmark_end - $benchmark_start" | bc -l)
    
    # Compile results
    cat > "$RESULTS_FILE" <<EOF
{
    "system_info": $system_info,
    "benchmark_duration": $total_time,
    "results": {
        "file_traversal": $file_traversal,
        "inotify_performance": $inotify_perf,
        "git_performance": $git_perf,
        "hash_performance": $hash_perf,
        "network_simulation": $network_perf,
        "system_resources": $system_resources
    }
}
EOF

    log "✅ Benchmark completed in ${total_time}s"
    log "📄 Results saved to: $RESULTS_FILE"
    
    # Display summary
    echo ""
    echo "🏆 PERFORMANCE SUMMARY"
    echo "======================"
    python3 -c "
import json
try:
    with open('$RESULTS_FILE', 'r') as f:
        data = json.load(f)
    
    print(f\"📊 System: {data['system_info']['os']} on {data['system_info']['hostname']}\")
    print(f\"📁 Workspace: {data['system_info']['workspace_size']} ({data['system_info']['total_files']} files)\")
    print(f\"⏱️  Total benchmark time: {float(data['benchmark_duration']):.2f}s\")
    print()
    
    # Key performance metrics
    results = data['results']
    
    print('🔍 File Operations:')
    if 'file_traversal' in results:
        ft = results['file_traversal']
        print(f\"   Find all files: {float(ft['find_all_files']['time']):.3f}s ({ft['find_all_files']['files']} files)\")
        print(f\"   Find JSON files: {float(ft['find_json_files']['time']):.3f}s ({ft['find_json_files']['files']} files)\")
    
    print()
    print('📦 Git Operations:')
    if 'git_performance' in results:
        gp = results['git_performance']
        print(f\"   Status: {float(gp['git_status']['time']):.3f}s\")
        print(f\"   Add: {float(gp['git_add']['time']):.3f}s\")
        print(f\"   Commit: {float(gp['git_commit']['time']):.3f}s\")
    
    print()
    print('💾 Memory Usage:')
    if 'inotify_performance' in results:
        ip = results['inotify_performance']
        print(f\"   Single directory: {ip['single_dir']['memory_kb']}KB\")
        print(f\"   Recursive workspace: {ip['recursive_workspace']['memory_kb']}KB\")
        print(f\"   Filtered workspace: {ip['filtered_workspace']['memory_kb']}KB\")
    
    print()
    print('📊 System Resources:')
    if 'system_resources' in results:
        sr = results['system_resources']
        print(f\"   CPU Usage: {sr['cpu_usage_percent']}%\")
        print(f\"   Memory Usage: {sr['memory_usage_percent']}%\")
        print(f\"   Disk Usage: {sr['disk_usage_percent']}%\")
        print(f\"   Git Repo Size: {sr['git_repo_size']}\")
    
except Exception as e:
    print(f'Error processing results: {e}')
"
}

# Performance comparison with previous runs
compare_with_previous() {
    log "📈 Comparing with previous benchmark results..."
    
    local previous_results=($(ls -t "$BENCHMARK_DIR"/benchmark-results-*.json 2>/dev/null | head -2))
    
    if [[ ${#previous_results[@]} -lt 2 ]]; then
        log "⚠️  Not enough previous results for comparison"
        return
    fi
    
    local current="${previous_results[0]}"
    local previous="${previous_results[1]}"
    
    python3 -c "
import json
try:
    with open('$current', 'r') as f:
        current = json.load(f)
    with open('$previous', 'r') as f:
        previous = json.load(f)
    
    print('📊 PERFORMANCE COMPARISON')
    print('=========================')
    
    # Compare key metrics
    def compare_metric(path, format_str=':.3f', suffix=''):
        try:
            current_val = current
            previous_val = previous
            for key in path.split('.'):
                current_val = current_val[key]
                previous_val = previous_val[key]
            
            current_val = float(current_val)
            previous_val = float(previous_val)
            change = ((current_val - previous_val) / previous_val) * 100
            
            status = '📈' if change > 5 else '📉' if change < -5 else '➖'
            print(f'{status} {path}: {current_val{format_str}}{suffix} ({change:+.1f}%)')
        except:
            pass
    
    compare_metric('results.git_performance.git_status.time', ':.3f', 's')
    compare_metric('results.git_performance.git_commit.time', ':.3f', 's')
    compare_metric('results.inotify_performance.recursive_workspace.memory_kb', ':.0f', 'KB')
    compare_metric('benchmark_duration', ':.2f', 's')

except Exception as e:
    print(f'Error comparing results: {e}')
"
}

# Main execution
case "${1:-run}" in
    "run")
        run_full_benchmark
        compare_with_previous
        ;;
    "compare")
        compare_with_previous
        ;;
    "clean")
        log "🧹 Cleaning benchmark cache..."
        rm -rf "$BENCHMARK_DIR"
        log "✅ Benchmark cache cleaned"
        ;;
    *)
        echo "Usage: $0 [run|compare|clean]"
        echo "  run     - Run full benchmark suite (default)"
        echo "  compare - Compare with previous results"
        echo "  clean   - Clean benchmark cache"
        ;;
esac