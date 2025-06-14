#!/usr/bin/env python3
"""
Performance Benchmark Tool
Misura improvement delle ottimizzazioni implementate.
"""

import time
import json
import os
import tempfile
import subprocess
import statistics
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import sys

# Import all our optimized tools
try:
    from json_cache_manager import get_cache_manager, cached_json_read, cached_json_write
    from safe_json_operations import safe_json_read, safe_json_write, batch_json_operations, parallel_json_reads
    from memory_operations import MemoryOperations
    OPTIMIZED_AVAILABLE = True
except ImportError as e:
    print(f"Warning: Optimized modules not available: {e}")
    OPTIMIZED_AVAILABLE = False


class PerformanceBenchmark:
    """Comprehensive performance benchmarking suite."""
    
    def __init__(self, workspace_dir: str):
        self.workspace_dir = Path(workspace_dir)
        self.results = {}
        
    def benchmark_json_operations(self, iterations: int = 100) -> dict:
        """Benchmark JSON read/write operations."""
        print(f"🔄 Benchmarking JSON operations ({iterations} iterations)...")
        
        results = {
            'iterations': iterations,
            'individual_operations': {},
            'batch_operations': {},
            'parallel_operations': {}
        }
        
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            test_data = {
                'test': True,
                'iteration': 0,
                'data': ['item' + str(i) for i in range(100)],
                'metadata': {'created': time.time(), 'version': '1.0'}
            }
            
            # Individual operations benchmark
            individual_times = []
            for i in range(iterations):
                test_file = temp_path / f"test_{i}.json"
                test_data['iteration'] = i
                
                start_time = time.perf_counter()
                
                if OPTIMIZED_AVAILABLE:
                    # Use optimized operations
                    cached_json_write(str(test_file), test_data)
                    read_data = cached_json_read(str(test_file))
                else:
                    # Fallback to basic operations
                    with open(test_file, 'w') as f:
                        json.dump(test_data, f)
                    with open(test_file, 'r') as f:
                        read_data = json.load(f)
                
                end_time = time.perf_counter()
                individual_times.append(end_time - start_time)
            
            results['individual_operations'] = {
                'mean_time': statistics.mean(individual_times),
                'median_time': statistics.median(individual_times),
                'min_time': min(individual_times),
                'max_time': max(individual_times),
                'total_time': sum(individual_times)
            }
            
            # Batch operations benchmark
            if OPTIMIZED_AVAILABLE:
                batch_operations = []
                for i in range(iterations):
                    test_file = temp_path / f"batch_{i}.json"
                    test_data['iteration'] = i
                    batch_operations.append({
                        'type': 'write',
                        'file_path': str(test_file),
                        'data': test_data.copy()
                    })
                
                start_time = time.perf_counter()
                batch_results = batch_json_operations(batch_operations)
                end_time = time.perf_counter()
                
                results['batch_operations'] = {
                    'total_time': end_time - start_time,
                    'operations_per_second': iterations / (end_time - start_time),
                    'success_rate': sum(1 for r in batch_results.values() if r is True) / len(batch_results)
                }
            
            # Parallel reads benchmark
            if OPTIMIZED_AVAILABLE:
                # Create test files
                test_files = []
                for i in range(min(iterations, 50)):  # Limit for parallel test
                    test_file = temp_path / f"parallel_{i}.json"
                    test_data['iteration'] = i
                    cached_json_write(str(test_file), test_data)
                    test_files.append(str(test_file))
                
                start_time = time.perf_counter()
                parallel_results = parallel_json_reads(test_files)
                end_time = time.perf_counter()
                
                results['parallel_operations'] = {
                    'files_read': len(test_files),
                    'total_time': end_time - start_time,
                    'files_per_second': len(test_files) / (end_time - start_time),
                    'success_rate': sum(1 for r in parallel_results.values() 
                                      if not isinstance(r, Exception)) / len(parallel_results)
                }
        
        return results
    
    def benchmark_memory_operations(self, iterations: int = 50) -> dict:
        """Benchmark memory operations (context save/load)."""
        print(f"🧠 Benchmarking memory operations ({iterations} iterations)...")
        
        results = {
            'iterations': iterations,
            'save_operations': {},
            'load_operations': {},
            'git_status_cache': {}
        }
        
        if not OPTIMIZED_AVAILABLE:
            return {'error': 'Optimized memory operations not available'}
        
        memory_ops = MemoryOperations(str(self.workspace_dir))
        
        # Save operations benchmark
        save_times = []
        for i in range(iterations):
            start_time = time.perf_counter()
            memory_ops.save_context(
                save_reason=f"benchmark_{i}",
                conversation_summary=f"Benchmark iteration {i}",
                open_issues=[f"Issue {i}"],
                next_actions=[f"Action {i}"]
            )
            end_time = time.perf_counter()
            save_times.append(end_time - start_time)
        
        results['save_operations'] = {
            'mean_time': statistics.mean(save_times),
            'median_time': statistics.median(save_times),
            'min_time': min(save_times),
            'max_time': max(save_times),
            'total_time': sum(save_times)
        }
        
        # Load operations benchmark
        load_times = []
        for i in range(iterations):
            start_time = time.perf_counter()
            context = memory_ops.load_context()
            end_time = time.perf_counter()
            load_times.append(end_time - start_time)
        
        results['load_operations'] = {
            'mean_time': statistics.mean(load_times),
            'median_time': statistics.median(load_times),
            'min_time': min(load_times),
            'max_time': max(load_times),
            'total_time': sum(load_times)
        }
        
        # Git status caching benchmark
        git_times_no_cache = []
        git_times_with_cache = []
        
        # Clear cache first
        cache_file = self.workspace_dir / ".claude" / "memory" / "git-status-cache.json"
        if cache_file.exists():
            cache_file.unlink()
        
        # Test without cache (first call)
        start_time = time.perf_counter()
        git_status1 = memory_ops.get_git_status()
        end_time = time.perf_counter()
        git_times_no_cache.append(end_time - start_time)
        
        # Test with cache (subsequent calls)
        for i in range(10):
            start_time = time.perf_counter()
            git_status2 = memory_ops.get_git_status()
            end_time = time.perf_counter()
            git_times_with_cache.append(end_time - start_time)
        
        results['git_status_cache'] = {
            'no_cache_time': git_times_no_cache[0],
            'cached_mean_time': statistics.mean(git_times_with_cache),
            'cache_speedup': git_times_no_cache[0] / statistics.mean(git_times_with_cache) if git_times_with_cache else 0
        }
        
        return results
    
    def benchmark_consistency_checking(self) -> dict:
        """Benchmark consistency checking performance."""
        print("🔍 Benchmarking consistency checking...")
        
        results = {}
        
        # Test old vs new consistency checking
        claude_dir = self.workspace_dir / ".claude"
        json_files = list(claude_dir.glob("**/*.json"))[:20]  # Limit for test
        
        if not json_files:
            return {'error': 'No JSON files found for testing'}
        
        # Simulate old approach: individual file checks
        old_times = []
        for file_path in json_files:
            start_time = time.perf_counter()
            try:
                with open(file_path, 'r') as f:
                    json.load(f)
                status = 'valid'
            except:
                status = 'invalid'
            end_time = time.perf_counter()
            old_times.append(end_time - start_time)
        
        results['individual_checks'] = {
            'files_checked': len(json_files),
            'total_time': sum(old_times),
            'mean_time_per_file': statistics.mean(old_times),
            'files_per_second': len(json_files) / sum(old_times)
        }
        
        # New approach: smart consistency monitor
        if OPTIMIZED_AVAILABLE:
            try:
                from smart_consistency_monitor import SmartConsistencyMonitor
                
                monitor = SmartConsistencyMonitor(str(self.workspace_dir))
                
                start_time = time.perf_counter()
                batch_result = monitor.batch_validate(force_all=True)
                end_time = time.perf_counter()
                
                results['smart_batch_checks'] = {
                    'files_checked': batch_result['checked'],
                    'total_time': end_time - start_time,
                    'files_per_second': batch_result['checked'] / (end_time - start_time),
                    'valid_files': batch_result['valid'],
                    'invalid_files': batch_result['invalid'],
                    'speedup_vs_individual': sum(old_times) / (end_time - start_time)
                }
            except ImportError:
                results['smart_batch_checks'] = {'error': 'Smart monitor not available'}
        
        return results
    
    def benchmark_cache_performance(self) -> dict:
        """Benchmark cache manager performance."""
        print("💾 Benchmarking cache performance...")
        
        if not OPTIMIZED_AVAILABLE:
            return {'error': 'Cache manager not available'}
        
        cache_manager = get_cache_manager()
        results = {}
        
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            test_files = []
            
            # Create test files
            for i in range(50):
                test_file = temp_path / f"cache_test_{i}.json"
                test_data = {'id': i, 'data': f'test_data_{i}'}
                with open(test_file, 'w') as f:
                    json.dump(test_data, f)
                test_files.append(str(test_file))
            
            # Cold cache performance (first reads)
            cold_times = []
            for file_path in test_files:
                start_time = time.perf_counter()
                data = cache_manager.read_json(file_path)
                end_time = time.perf_counter()
                cold_times.append(end_time - start_time)
            
            # Warm cache performance (second reads)
            warm_times = []
            for file_path in test_files:
                start_time = time.perf_counter()
                data = cache_manager.read_json(file_path)
                end_time = time.perf_counter()
                warm_times.append(end_time - start_time)
            
            cache_stats = cache_manager.get_stats()
            
            results = {
                'cold_cache': {
                    'mean_time': statistics.mean(cold_times),
                    'total_time': sum(cold_times)
                },
                'warm_cache': {
                    'mean_time': statistics.mean(warm_times),
                    'total_time': sum(warm_times)
                },
                'cache_speedup': statistics.mean(cold_times) / statistics.mean(warm_times),
                'cache_stats': cache_stats
            }
        
        return results
    
    def run_full_benchmark(self) -> dict:
        """Run complete performance benchmark suite."""
        print("🚀 Starting comprehensive performance benchmark...")
        start_time = time.time()
        
        self.results = {
            'timestamp': start_time,
            'workspace_dir': str(self.workspace_dir),
            'optimized_available': OPTIMIZED_AVAILABLE
        }
        
        try:
            self.results['json_operations'] = self.benchmark_json_operations()
        except Exception as e:
            self.results['json_operations'] = {'error': str(e)}
        
        try:
            self.results['memory_operations'] = self.benchmark_memory_operations()
        except Exception as e:
            self.results['memory_operations'] = {'error': str(e)}
        
        try:
            self.results['consistency_checking'] = self.benchmark_consistency_checking()
        except Exception as e:
            self.results['consistency_checking'] = {'error': str(e)}
        
        try:
            self.results['cache_performance'] = self.benchmark_cache_performance()
        except Exception as e:
            self.results['cache_performance'] = {'error': str(e)}
        
        end_time = time.time()
        self.results['benchmark_duration'] = end_time - start_time
        
        print(f"✅ Benchmark completed in {self.results['benchmark_duration']:.2f} seconds")
        return self.results
    
    def save_results(self, output_file: str):
        """Save benchmark results to file."""
        with open(output_file, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"📊 Results saved to {output_file}")
    
    def print_summary(self):
        """Print benchmark summary."""
        if not self.results:
            print("No benchmark results available")
            return
        
        print("\n" + "="*60)
        print("📊 PERFORMANCE BENCHMARK SUMMARY")
        print("="*60)
        
        if 'json_operations' in self.results and 'individual_operations' in self.results['json_operations']:
            json_ops = self.results['json_operations']['individual_operations']
            print(f"📄 JSON Operations:")
            print(f"   Mean time per operation: {json_ops['mean_time']*1000:.2f}ms")
            print(f"   Operations per second: {1/json_ops['mean_time']:.0f}")
            
            if 'batch_operations' in self.results['json_operations']:
                batch_ops = self.results['json_operations']['batch_operations']
                if 'operations_per_second' in batch_ops:
                    print(f"   Batch operations/sec: {batch_ops['operations_per_second']:.0f}")
        
        if 'memory_operations' in self.results and 'save_operations' in self.results['memory_operations']:
            mem_ops = self.results['memory_operations']
            print(f"🧠 Memory Operations:")
            print(f"   Context save time: {mem_ops['save_operations']['mean_time']*1000:.2f}ms")
            print(f"   Context load time: {mem_ops['load_operations']['mean_time']*1000:.2f}ms")
            if 'git_status_cache' in mem_ops:
                cache_speedup = mem_ops['git_status_cache']['cache_speedup']
                print(f"   Git status cache speedup: {cache_speedup:.1f}x")
        
        if 'consistency_checking' in self.results:
            consistency = self.results['consistency_checking']
            if 'smart_batch_checks' in consistency and 'speedup_vs_individual' in consistency['smart_batch_checks']:
                speedup = consistency['smart_batch_checks']['speedup_vs_individual']
                print(f"🔍 Consistency Checking:")
                print(f"   Smart batch speedup: {speedup:.1f}x")
        
        if 'cache_performance' in self.results and 'cache_speedup' in self.results['cache_performance']:
            cache_speedup = self.results['cache_performance']['cache_speedup']
            print(f"💾 Cache Performance:")
            print(f"   Cache hit speedup: {cache_speedup:.1f}x")
        
        print(f"⏱️  Total benchmark time: {self.results['benchmark_duration']:.2f}s")
        print("="*60)


def main():
    """CLI interface for performance benchmarking."""
    workspace_dir = os.environ.get('WORKSPACE_DIR', os.path.expanduser('~/claude-workspace'))
    
    if len(sys.argv) > 1 and sys.argv[1] == "quick":
        # Quick benchmark with fewer iterations
        benchmark = PerformanceBenchmark(workspace_dir)
        benchmark.results = benchmark.run_full_benchmark()
        benchmark.print_summary()
    else:
        # Full benchmark
        benchmark = PerformanceBenchmark(workspace_dir)
        benchmark.results = benchmark.run_full_benchmark()
        
        # Save results
        timestamp = int(time.time())
        output_file = f"benchmark-results-{timestamp}.json"
        benchmark.save_results(output_file)
        
        # Print summary
        benchmark.print_summary()


if __name__ == "__main__":
    main()