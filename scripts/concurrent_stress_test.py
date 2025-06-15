#!/usr/bin/env python3
"""
Concurrent stress test for Python backend operations
"""

import time
import tempfile
import threading
import concurrent.futures
import os
import json
from pathlib import Path
import hashlib

from safe_json_operations import safe_json_read, safe_json_write, safe_json_update
from json_cache_manager import get_cache_manager

def stress_test_concurrent_writes(test_dir, num_threads=20, operations_per_thread=100):
    """Stress test concurrent writes to same file."""
    print(f"=== STRESS TEST: {num_threads} threads x {operations_per_thread} ops ===")
    
    test_file = Path(test_dir) / "stress_test.json"
    results = []
    errors = []
    
    def worker_thread(thread_id):
        """Worker thread function."""
        thread_results = []
        thread_errors = []
        
        for i in range(operations_per_thread):
            try:
                # Create unique data for each operation
                data = {
                    "thread_id": thread_id,
                    "operation": i,
                    "timestamp": time.time(),
                    "data": f"data_{thread_id}_{i}",
                    "checksum": hashlib.md5(f"{thread_id}_{i}".encode()).hexdigest()
                }
                
                # Write and immediately read back
                success = safe_json_write(str(test_file), data)
                if success:
                    read_data = safe_json_read(str(test_file))
                    if read_data == data:
                        thread_results.append(True)
                    else:
                        thread_errors.append(f"Data mismatch in thread {thread_id}, op {i}")
                else:
                    thread_errors.append(f"Write failed in thread {thread_id}, op {i}")
                    
            except Exception as e:
                thread_errors.append(f"Exception in thread {thread_id}, op {i}: {e}")
        
        return thread_results, thread_errors
    
    # Run stress test
    start_time = time.time()
    
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_threads) as executor:
        futures = [executor.submit(worker_thread, i) for i in range(num_threads)]
        
        for future in concurrent.futures.as_completed(futures):
            try:
                thread_results, thread_errors = future.result()
                results.extend(thread_results)
                errors.extend(thread_errors)
            except Exception as e:
                errors.append(f"Thread execution error: {e}")
    
    total_time = time.time() - start_time
    
    total_operations = num_threads * operations_per_thread
    successful_operations = len(results)
    error_count = len(errors)
    
    print(f"Total operations: {total_operations}")
    print(f"Successful operations: {successful_operations}")
    print(f"Errors: {error_count}")
    print(f"Success rate: {(successful_operations/total_operations)*100:.1f}%")
    print(f"Total time: {total_time:.3f}s")
    print(f"Operations per second: {total_operations/total_time:.1f}")
    
    if error_count > 0:
        print("First 5 errors:")
        for error in errors[:5]:
            print(f"  - {error}")
    
    return {
        "total_operations": total_operations,
        "successful_operations": successful_operations,
        "error_count": error_count,
        "success_rate": successful_operations/total_operations,
        "total_time": total_time,
        "ops_per_second": total_operations/total_time
    }

def test_atomic_operations(test_dir):
    """Test atomic operations integrity."""
    print("\n=== ATOMIC OPERATIONS TEST ===")
    
    test_file = Path(test_dir) / "atomic_test.json"
    
    # Initialize with counter
    safe_json_write(str(test_file), {"counter": 0})
    
    def increment_counter(thread_id, increments=50):
        """Increment counter atomically."""
        errors = []
        for i in range(increments):
            try:
                def increment_func(data):
                    current = data.get("counter", 0)
                    return {"counter": current + 1, "last_thread": thread_id}
                
                safe_json_update(str(test_file), increment_func, default={"counter": 0})
            except Exception as e:
                errors.append(f"Thread {thread_id}, increment {i}: {e}")
        return errors
    
    # Run atomic increments
    num_threads = 10
    increments_per_thread = 50
    expected_final_value = num_threads * increments_per_thread
    
    start_time = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_threads) as executor:
        futures = [executor.submit(increment_counter, i, increments_per_thread) for i in range(num_threads)]
        
        all_errors = []
        for future in concurrent.futures.as_completed(futures):
            errors = future.result()
            all_errors.extend(errors)
    
    atomic_time = time.time() - start_time
    
    # Check final value
    final_data = safe_json_read(str(test_file))
    actual_final_value = final_data.get("counter", 0)
    
    print(f"Expected final counter: {expected_final_value}")
    print(f"Actual final counter: {actual_final_value}")
    print(f"Atomic operation errors: {len(all_errors)}")
    print(f"Atomic operations time: {atomic_time:.3f}s")
    
    integrity_maintained = actual_final_value == expected_final_value
    
    if integrity_maintained:
        print("✅ ATOMICITY: Perfect - no data corruption")
    else:
        print(f"❌ ATOMICITY: Failed - data corruption detected ({actual_final_value} != {expected_final_value})")
    
    return {
        "expected_value": expected_final_value,
        "actual_value": actual_final_value,
        "integrity_maintained": integrity_maintained,
        "atomic_errors": len(all_errors),
        "atomic_time": atomic_time
    }

def test_cache_consistency(test_dir):
    """Test cache consistency under concurrent access."""
    print("\n=== CACHE CONSISTENCY TEST ===")
    
    test_file = Path(test_dir) / "cache_test.json"
    cache = get_cache_manager()
    
    # Initialize data
    initial_data = {"value": 0, "timestamp": time.time()}
    cache.write_json(str(test_file), initial_data, immediate=True)
    
    def cache_worker(thread_id, operations=30):
        """Worker that mixes reads and writes with cache."""
        errors = []
        for i in range(operations):
            try:
                # Read from cache
                data = cache.read_json(str(test_file))
                
                # Modify and write back
                new_data = {
                    "value": data.get("value", 0) + 1,
                    "timestamp": time.time(),
                    "last_thread": thread_id
                }
                
                cache.write_json(str(test_file), new_data, immediate=True)
                
                # Verify read consistency
                verify_data = cache.read_json(str(test_file))
                if verify_data != new_data:
                    errors.append(f"Cache inconsistency in thread {thread_id}, op {i}")
                    
            except Exception as e:
                errors.append(f"Cache error in thread {thread_id}, op {i}: {e}")
        
        return errors
    
    # Run cache consistency test
    num_threads = 8
    operations_per_thread = 30
    
    start_time = time.time()
    with concurrent.futures.ThreadPoolExecutor(max_workers=num_threads) as executor:
        futures = [executor.submit(cache_worker, i, operations_per_thread) for i in range(num_threads)]
        
        all_errors = []
        for future in concurrent.futures.as_completed(futures):
            errors = future.result()
            all_errors.extend(errors)
    
    cache_time = time.time() - start_time
    
    # Get final cache stats
    stats = cache.get_stats()
    
    print(f"Cache consistency errors: {len(all_errors)}")
    print(f"Cache test time: {cache_time:.3f}s")
    print(f"Cache hit rate: {stats.get('hit_rate', 0):.2f}")
    print(f"Cache operations: {stats.get('cache_hits', 0) + stats.get('cache_misses', 0)}")
    
    consistency_maintained = len(all_errors) == 0
    
    if consistency_maintained:
        print("✅ CACHE CONSISTENCY: Perfect - no inconsistencies")
    else:
        print(f"❌ CACHE CONSISTENCY: Issues detected ({len(all_errors)} errors)")
    
    return {
        "consistency_errors": len(all_errors),
        "consistency_maintained": consistency_maintained,
        "cache_stats": stats,
        "cache_time": cache_time
    }

def main():
    """Run all concurrent stress tests."""
    print("Concurrent Stress Test for Python Backend")
    print("=" * 50)
    
    with tempfile.TemporaryDirectory() as test_dir:
        # Test 1: Concurrent writes stress test
        stress_results = stress_test_concurrent_writes(test_dir, num_threads=20, operations_per_thread=50)
        
        # Test 2: Atomic operations test
        atomic_results = test_atomic_operations(test_dir)
        
        # Test 3: Cache consistency test
        cache_results = test_cache_consistency(test_dir)
        
        print("\n" + "=" * 50)
        print("CONCURRENT STRESS TEST SUMMARY")
        print("=" * 50)
        
        print(f"Stress test success rate: {stress_results['success_rate']*100:.1f}%")
        print(f"Stress test ops/sec: {stress_results['ops_per_second']:.1f}")
        
        print(f"Atomic operations integrity: {'✅ PASS' if atomic_results['integrity_maintained'] else '❌ FAIL'}")
        print(f"Cache consistency: {'✅ PASS' if cache_results['consistency_maintained'] else '❌ FAIL'}")
        
        # Overall assessment
        if (stress_results['success_rate'] > 0.95 and 
            atomic_results['integrity_maintained'] and 
            cache_results['consistency_maintained']):
            print("\n🎉 OVERALL ASSESSMENT: EXCELLENT")
            print("   ✅ High concurrent success rate")
            print("   ✅ Perfect atomic operation integrity")
            print("   ✅ Cache consistency maintained")
            recommendation = "STANDALONE_SUFFICIENT"
        elif (stress_results['success_rate'] > 0.85 and 
              atomic_results['integrity_maintained']):
            print("\n👍 OVERALL ASSESSMENT: GOOD")
            print("   ✅ Good concurrent performance")
            print("   ✅ Atomic operations work correctly")
            print("   ⚠️  Minor cache consistency issues")
            recommendation = "STANDALONE_SUFFICIENT"
        else:
            print("\n⚠️  OVERALL ASSESSMENT: NEEDS IMPROVEMENT")
            print("   ❌ Concurrent access issues detected")
            print("   ❌ Data integrity problems")
            recommendation = "NEEDS_WRAPPER"
        
        print(f"\nRECOMMENDATION: {recommendation}")
        
        return recommendation

if __name__ == "__main__":
    main()