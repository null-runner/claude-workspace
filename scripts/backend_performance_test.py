#!/usr/bin/env python3
"""
Performance test for backend Python operations
"""

import time
import tempfile
import json
import os
import sys
from pathlib import Path
import concurrent.futures
import threading

# Import the modules we're testing
from safe_json_operations import safe_json_read, safe_json_write
from json_cache_manager import get_cache_manager
from memory_operations import MemoryOperations

def test_basic_operations(test_dir):
    """Test basic JSON operations performance."""
    print("=== BASIC OPERATIONS TEST ===")
    
    test_file = Path(test_dir) / "basic_test.json"
    test_data = {"test": "data", "number": 42, "list": [1, 2, 3]}
    
    # Test direct operations
    start_time = time.time()
    for i in range(100):
        safe_json_write(str(test_file), {**test_data, "iteration": i})
        data = safe_json_read(str(test_file))
    direct_time = time.time() - start_time
    
    # Test cached operations
    cache = get_cache_manager()
    start_time = time.time()
    for i in range(100):
        cache.write_json(str(test_file), {**test_data, "iteration": i}, immediate=True)
        data = cache.read_json(str(test_file))
    cached_time = time.time() - start_time
    
    print(f"Direct operations (100 iterations): {direct_time:.3f}s")
    print(f"Cached operations (100 iterations): {cached_time:.3f}s")
    print(f"Cache performance gain: {(direct_time/cached_time):.2f}x")
    
    return {
        "direct_time": direct_time,
        "cached_time": cached_time,
        "cache_gain": direct_time/cached_time
    }

def test_concurrent_operations(test_dir):
    """Test concurrent access performance."""
    print("\n=== CONCURRENT OPERATIONS TEST ===")
    
    test_file = Path(test_dir) / "concurrent_test.json"
    
    def concurrent_writes(file_path, thread_id, iterations=50):
        """Concurrent write function."""
        for i in range(iterations):
            try:
                data = {"thread": thread_id, "iteration": i, "timestamp": time.time()}
                safe_json_write(file_path, data)
            except Exception as e:
                print(f"Error in thread {thread_id}: {e}")
                return False
        return True
    
    def concurrent_cached_writes(file_path, thread_id, iterations=50):
        """Concurrent cached write function."""
        cache = get_cache_manager()
        for i in range(iterations):
            try:
                data = {"thread": thread_id, "iteration": i, "timestamp": time.time()}
                cache.write_json(file_path, data, immediate=True)
            except Exception as e:
                print(f"Error in cached thread {thread_id}: {e}")
                return False
        return True
    
    # Test direct concurrent writes
    start_time = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(concurrent_writes, str(test_file), i) for i in range(5)]
        concurrent.futures.wait(futures)
    direct_concurrent_time = time.time() - start_time
    
    # Test cached concurrent writes
    start_time = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
        futures = [executor.submit(concurrent_cached_writes, str(test_file), i) for i in range(5)]
        concurrent.futures.wait(futures)
    cached_concurrent_time = time.time() - start_time
    
    print(f"Direct concurrent (5 threads x 50 ops): {direct_concurrent_time:.3f}s")
    print(f"Cached concurrent (5 threads x 50 ops): {cached_concurrent_time:.3f}s")
    print(f"Concurrent cache gain: {(direct_concurrent_time/cached_concurrent_time):.2f}x")
    
    return {
        "direct_concurrent_time": direct_concurrent_time,
        "cached_concurrent_time": cached_concurrent_time,
        "concurrent_gain": direct_concurrent_time/cached_concurrent_time
    }

def test_memory_operations(test_dir):
    """Test memory operations performance."""
    print("\n=== MEMORY OPERATIONS TEST ===")
    
    os.environ['WORKSPACE_DIR'] = str(test_dir)
    memory_ops = MemoryOperations(str(test_dir))
    
    # Test multiple operations
    start_time = time.time()
    for i in range(20):
        git_status = memory_ops.get_git_status()
        project_info = memory_ops.get_project_info()
        memory_ops.save_context(
            save_reason=f"test_{i}",
            conversation_summary=f"Test iteration {i}",
            open_issues=[f"issue_{i}"],
            next_actions=[f"action_{i}"]
        )
        context = memory_ops.load_context()
    memory_ops_time = time.time() - start_time
    
    print(f"Memory operations (20 iterations): {memory_ops_time:.3f}s")
    print(f"Average per iteration: {(memory_ops_time/20):.3f}s")
    
    # Get cache stats
    stats = memory_ops.get_cache_stats()
    print(f"Cache statistics: {stats}")
    
    return {
        "memory_ops_time": memory_ops_time,
        "avg_per_iteration": memory_ops_time/20,
        "cache_stats": stats
    }

def test_error_handling():
    """Test error handling robustness."""
    print("\n=== ERROR HANDLING TEST ===")
    
    errors_caught = 0
    
    # Test nonexistent file
    try:
        safe_json_read("/nonexistent/path/file.json")
    except:
        errors_caught += 1
    
    # Test invalid JSON
    with tempfile.NamedTemporaryFile(mode='w', suffix='.json', delete=False) as f:
        f.write("invalid json content")
        f.flush()
        try:
            safe_json_read(f.name)
        except:
            errors_caught += 1
        finally:
            os.unlink(f.name)
    
    # Test permission errors (simulated)
    try:
        safe_json_write("/root/test.json", {"test": "data"})
    except:
        errors_caught += 1
    
    print(f"Error handling tests: {errors_caught}/3 errors properly caught")
    
    return {"errors_caught": errors_caught}

def main():
    """Run all performance tests."""
    print("Python Backend Performance Analysis")
    print("=" * 50)
    
    with tempfile.TemporaryDirectory() as test_dir:
        # Create necessary subdirectories
        claude_dir = Path(test_dir) / ".claude" / "memory"
        claude_dir.mkdir(parents=True, exist_ok=True)
        
        projects_dir = Path(test_dir) / ".claude" / "auto-projects"
        projects_dir.mkdir(parents=True, exist_ok=True)
        
        # Run tests
        basic_results = test_basic_operations(test_dir)
        concurrent_results = test_concurrent_operations(test_dir)
        memory_results = test_memory_operations(test_dir)
        error_results = test_error_handling()
        
        print("\n" + "=" * 50)
        print("SUMMARY RESULTS")
        print("=" * 50)
        
        print(f"Basic operations cache gain: {basic_results['cache_gain']:.2f}x")
        print(f"Concurrent operations cache gain: {concurrent_results['concurrent_gain']:.2f}x")
        print(f"Memory operations avg time: {memory_results['avg_per_iteration']:.3f}s")
        print(f"Error handling: {error_results['errors_caught']}/3 properly handled")
        
        # Overall assessment
        overall_performance = (basic_results['cache_gain'] + concurrent_results['concurrent_gain']) / 2
        print(f"\nOverall cache performance gain: {overall_performance:.2f}x")
        
        if overall_performance > 1.5:
            print("✅ PERFORMANCE: Excellent - significant improvements with caching")
        elif overall_performance > 1.1:
            print("✅ PERFORMANCE: Good - moderate improvements with caching")
        else:
            print("⚠️  PERFORMANCE: Minimal - caching provides little benefit")
        
        if memory_results['avg_per_iteration'] < 0.1:
            print("✅ RESPONSIVENESS: Excellent - very fast operations")
        elif memory_results['avg_per_iteration'] < 0.3:
            print("✅ RESPONSIVENESS: Good - acceptable performance")
        else:
            print("⚠️  RESPONSIVENESS: Slow - may impact user experience")
        
        if error_results['errors_caught'] >= 2:
            print("✅ ROBUSTNESS: Good - error handling is robust")
        else:
            print("⚠️  ROBUSTNESS: Needs improvement - error handling is weak")

if __name__ == "__main__":
    main()