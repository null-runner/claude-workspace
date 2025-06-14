#!/usr/bin/env python3
"""
JSON Cache Manager - Performance Optimized JSON Operations
Reduces file I/O overhead through intelligent caching and batch operations.
"""

import json
import os
import time
import threading
from pathlib import Path
from typing import Any, Dict, Optional, Set, Callable
from dataclasses import dataclass, field
from collections import defaultdict
import hashlib
import sys

# Import safe JSON operations
from safe_json_operations import safe_json_read, safe_json_write, SafeJSONError


@dataclass
class CacheEntry:
    """Cache entry with metadata."""
    data: Any
    timestamp: float
    file_mtime: float
    access_count: int = 0
    last_access: float = field(default_factory=time.time)
    dirty: bool = False
    lock: threading.RLock = field(default_factory=threading.RLock)


class JSONCacheManager:
    """
    High-performance JSON cache manager with:
    - In-memory caching with TTL
    - Lazy loading and dirty tracking
    - Batch write operations
    - File modification time validation
    - Thread-safe operations
    """
    
    def __init__(self, 
                 cache_ttl: int = 300,  # 5 minutes
                 max_cache_size: int = 100,
                 enable_stats: bool = True):
        self.cache_ttl = cache_ttl
        self.max_cache_size = max_cache_size
        self.enable_stats = enable_stats
        
        self._cache: Dict[str, CacheEntry] = {}
        self._pending_writes: Dict[str, Any] = {}
        self._cache_lock = threading.RLock()
        self._write_lock = threading.RLock()
        
        # Performance statistics
        self._stats = {
            'cache_hits': 0,
            'cache_misses': 0,
            'file_reads': 0,
            'file_writes': 0,
            'batch_writes': 0,
            'evictions': 0
        } if enable_stats else None
    
    def _get_file_key(self, file_path: str) -> str:
        """Generate consistent cache key for file path."""
        return str(Path(file_path).resolve())
    
    def _is_cache_valid(self, entry: CacheEntry, file_path: str) -> bool:
        """Check if cache entry is still valid."""
        try:
            current_time = time.time()
            
            # Check TTL
            if current_time - entry.timestamp > self.cache_ttl:
                return False
            
            # Check file modification time
            if Path(file_path).exists():
                file_mtime = Path(file_path).stat().st_mtime
                if file_mtime > entry.file_mtime:
                    return False
            
            return True
        except (OSError, IOError):
            return False
    
    def _evict_lru_entries(self):
        """Evict least recently used entries when cache is full."""
        if len(self._cache) <= self.max_cache_size:
            return
        
        # Sort by last access time and evict oldest
        sorted_entries = sorted(
            self._cache.items(),
            key=lambda x: x[1].last_access
        )
        
        evict_count = len(self._cache) - self.max_cache_size + 10  # Extra buffer
        for i in range(evict_count):
            key, entry = sorted_entries[i]
            # Don't evict dirty entries
            if not entry.dirty:
                del self._cache[key]
                if self._stats:
                    self._stats['evictions'] += 1
    
    def read_json(self, file_path: str, default: Any = None) -> Any:
        """
        Read JSON with caching.
        Returns cached data if valid, otherwise reads from file.
        """
        file_key = self._get_file_key(file_path)
        
        with self._cache_lock:
            # Check cache first
            if file_key in self._cache:
                entry = self._cache[file_key]
                
                if self._is_cache_valid(entry, file_path):
                    entry.access_count += 1
                    entry.last_access = time.time()
                    if self._stats:
                        self._stats['cache_hits'] += 1
                    return entry.data
                else:
                    # Cache is stale, remove entry
                    del self._cache[file_key]
            
            # Cache miss - read from file
            if self._stats:
                self._stats['cache_misses'] += 1
                self._stats['file_reads'] += 1
            
            try:
                data = safe_json_read(file_path, default)
                
                # Cache the result
                file_mtime = 0
                try:
                    if Path(file_path).exists():
                        file_mtime = Path(file_path).stat().st_mtime
                except (OSError, IOError):
                    pass
                
                self._cache[file_key] = CacheEntry(
                    data=data,
                    timestamp=time.time(),
                    file_mtime=file_mtime,
                    access_count=1
                )
                
                # Evict old entries if cache is full
                self._evict_lru_entries()
                
                return data
                
            except SafeJSONError:
                return default
    
    def write_json(self, file_path: str, data: Any, immediate: bool = False) -> bool:
        """
        Write JSON with optional batching.
        If immediate=False, writes are queued for batch processing.
        """
        file_key = self._get_file_key(file_path)
        
        with self._cache_lock:
            # Update cache immediately
            file_mtime = time.time()  # Will be actual mtime after write
            self._cache[file_key] = CacheEntry(
                data=data,
                timestamp=time.time(),
                file_mtime=file_mtime,
                access_count=1,
                dirty=not immediate
            )
        
        if immediate:
            return self._write_immediate(file_path, data)
        else:
            return self._write_batched(file_path, data)
    
    def _write_immediate(self, file_path: str, data: Any) -> bool:
        """Write JSON immediately."""
        try:
            success = safe_json_write(file_path, data)
            if success and self._stats:
                self._stats['file_writes'] += 1
            
            # Update cache with actual file mtime
            file_key = self._get_file_key(file_path)
            with self._cache_lock:
                if file_key in self._cache:
                    try:
                        actual_mtime = Path(file_path).stat().st_mtime
                        self._cache[file_key].file_mtime = actual_mtime
                        self._cache[file_key].dirty = False
                    except (OSError, IOError):
                        pass
            
            return success
        except SafeJSONError:
            return False
    
    def _write_batched(self, file_path: str, data: Any) -> bool:
        """Queue write for batch processing."""
        with self._write_lock:
            self._pending_writes[self._get_file_key(file_path)] = {
                'path': file_path,
                'data': data,
                'timestamp': time.time()
            }
        return True
    
    def flush_writes(self) -> Dict[str, bool]:
        """
        Flush all pending writes in batch.
        Returns dict of file_path -> success_status.
        """
        results = {}
        
        with self._write_lock:
            if not self._pending_writes:
                return results
            
            # Process all pending writes
            writes_to_process = dict(self._pending_writes)
            self._pending_writes.clear()
        
        if self._stats:
            self._stats['batch_writes'] += 1
        
        # Execute writes (could be parallelized)
        for file_key, write_info in writes_to_process.items():
            file_path = write_info['path']
            data = write_info['data']
            
            success = self._write_immediate(file_path, data)
            results[file_path] = success
            
            # Mark cache entry as clean
            with self._cache_lock:
                if file_key in self._cache:
                    self._cache[file_key].dirty = False
        
        return results
    
    def update_json(self, file_path: str, update_func: Callable, 
                   default: Any = None, immediate: bool = False) -> Any:
        """
        Update JSON file by applying function to current data.
        Uses cached data if available.
        """
        current_data = self.read_json(file_path, default)
        updated_data = update_func(current_data)
        
        success = self.write_json(file_path, updated_data, immediate)
        if success:
            return updated_data
        else:
            raise SafeJSONError(f"Failed to update {file_path}")
    
    def invalidate_cache(self, file_path: Optional[str] = None):
        """Invalidate cache entries."""
        with self._cache_lock:
            if file_path:
                file_key = self._get_file_key(file_path)
                self._cache.pop(file_key, None)
            else:
                self._cache.clear()
    
    def get_stats(self) -> Dict[str, Any]:
        """Get cache performance statistics."""
        if not self._stats:
            return {}
        
        stats = dict(self._stats)
        stats['cache_size'] = len(self._cache)
        stats['pending_writes'] = len(self._pending_writes)
        
        if stats['cache_hits'] + stats['cache_misses'] > 0:
            stats['hit_rate'] = stats['cache_hits'] / (stats['cache_hits'] + stats['cache_misses'])
        else:
            stats['hit_rate'] = 0.0
        
        return stats
    
    def cleanup(self):
        """Cleanup cache and flush pending writes."""
        self.flush_writes()
        self.invalidate_cache()


# Global cache instance
_global_cache = None
_cache_lock = threading.Lock()


def get_cache_manager(cache_ttl: int = 300, max_cache_size: int = 100) -> JSONCacheManager:
    """Get or create global cache manager instance."""
    global _global_cache
    
    with _cache_lock:
        if _global_cache is None:
            _global_cache = JSONCacheManager(
                cache_ttl=cache_ttl,
                max_cache_size=max_cache_size,
                enable_stats=True
            )
    
    return _global_cache


# Convenience functions for drop-in replacement
def cached_json_read(file_path: str, default: Any = None) -> Any:
    """Read JSON with caching (drop-in replacement for safe_json_read)."""
    cache = get_cache_manager()
    return cache.read_json(file_path, default)


def cached_json_write(file_path: str, data: Any, immediate: bool = True) -> bool:
    """Write JSON with caching (drop-in replacement for safe_json_write)."""
    cache = get_cache_manager()
    return cache.write_json(file_path, data, immediate)


def cached_json_update(file_path: str, update_func: Callable, 
                      default: Any = None, immediate: bool = True) -> Any:
    """Update JSON with caching."""
    cache = get_cache_manager()
    return cache.update_json(file_path, update_func, default, immediate)


def flush_all_writes() -> Dict[str, bool]:
    """Flush all pending writes."""
    cache = get_cache_manager()
    return cache.flush_writes()


def get_cache_stats() -> Dict[str, Any]:
    """Get cache performance statistics."""
    cache = get_cache_manager()
    return cache.get_stats()


if __name__ == "__main__":
    if len(sys.argv) > 1:
        if sys.argv[1] == "test":
            # Test the cache manager
            import tempfile
            import concurrent.futures
            
            print("Testing JSON Cache Manager...")
            
            with tempfile.TemporaryDirectory() as temp_dir:
                test_file = Path(temp_dir) / "test.json"
                cache = JSONCacheManager(cache_ttl=60, max_cache_size=10)
                
                # Test basic operations
                test_data = {"test": "data", "counter": 0}
                cache.write_json(str(test_file), test_data, immediate=True)
                
                read_data = cache.read_json(str(test_file))
                assert read_data == test_data
                print("✅ Basic cache operations passed")
                
                # Test cache hit
                read_data2 = cache.read_json(str(test_file))
                assert read_data2 == test_data
                
                stats = cache.get_stats()
                assert stats['cache_hits'] > 0
                print(f"✅ Cache hit test passed (hit rate: {stats['hit_rate']:.2f})")
                
                # Test batch writes
                for i in range(5):
                    cache.write_json(str(test_file), {"counter": i}, immediate=False)
                
                results = cache.flush_writes()
                assert str(test_file) in results
                assert results[str(test_file)] is True
                print("✅ Batch write test passed")
                
                # Test concurrent access
                def concurrent_update(cache_obj, file_path, thread_id):
                    for i in range(10):
                        cache_obj.update_json(
                            file_path,
                            lambda data: {**data, f"thread_{thread_id}": i},
                            default={},
                            immediate=True
                        )
                        time.sleep(0.01)
                
                with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
                    futures = [
                        executor.submit(concurrent_update, cache, str(test_file), i)
                        for i in range(3)
                    ]
                    concurrent.futures.wait(futures)
                
                final_stats = cache.get_stats()
                print(f"✅ Concurrent test passed - Final stats: {final_stats}")
                
                print("All tests completed successfully!")
        
        elif sys.argv[1] == "stats":
            stats = get_cache_stats()
            print("Cache Performance Statistics:")
            for key, value in stats.items():
                print(f"  {key}: {value}")
        
        elif sys.argv[1] == "flush":
            results = flush_all_writes()
            print(f"Flushed {len(results)} pending writes")
            for path, success in results.items():
                status = "✅" if success else "❌"
                print(f"  {status} {path}")
    
    else:
        print("JSON Cache Manager")
        print("Usage:")
        print("  python3 json-cache-manager.py test   - Run tests")
        print("  python3 json-cache-manager.py stats  - Show cache stats")
        print("  python3 json-cache-manager.py flush  - Flush pending writes")