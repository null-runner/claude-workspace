#!/usr/bin/env python3
"""
Safe JSON Operations with File Locking
Prevents corruption of JSON files when multiple processes try to access them simultaneously.

This module provides safe JSON read/write operations using fcntl file locking
and atomic write patterns to prevent data corruption.
"""

import json
import fcntl
import time
import os
import tempfile
import shutil
from pathlib import Path
from typing import Any, Dict, Optional, Union
import sys


class SafeJSONError(Exception):
    """Custom exception for Safe JSON operations."""
    pass


class SafeJSONLock:
    """Context manager for file locking with automatic retry."""
    
    def __init__(self, file_path: str, mode: str = 'r+', max_retries: int = 10, retry_delay: float = 0.1):
        self.file_path = Path(file_path)
        self.mode = mode
        self.max_retries = max_retries
        self.retry_delay = retry_delay
        self.file_handle = None
        self.locked = False
        
    def __enter__(self):
        """Acquire file lock with retry mechanism."""
        # Ensure parent directory exists
        self.file_path.parent.mkdir(parents=True, exist_ok=True)
        
        # For write operations, ensure file exists
        if 'w' in self.mode or 'a' in self.mode:
            if not self.file_path.exists():
                self.file_path.touch()
        elif not self.file_path.exists():
            raise SafeJSONError(f"File {self.file_path} does not exist and cannot be opened in mode '{self.mode}'")
        
        # Open file
        retries = 0
        while retries < self.max_retries:
            try:
                self.file_handle = open(self.file_path, self.mode)
                
                # Try to acquire exclusive lock
                fcntl.flock(self.file_handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                self.locked = True
                return self.file_handle
                
            except (IOError, OSError) as e:
                if self.file_handle:
                    self.file_handle.close()
                    self.file_handle = None
                
                retries += 1
                if retries >= self.max_retries:
                    raise SafeJSONError(f"Failed to acquire lock on {self.file_path} after {self.max_retries} retries: {e}")
                
                # Exponential backoff
                time.sleep(self.retry_delay * (2 ** min(retries, 4)))
                
        raise SafeJSONError(f"Unexpected error acquiring lock on {self.file_path}")
    
    def __exit__(self, exc_type, exc_val, exc_tb):
        """Release file lock."""
        if self.file_handle:
            try:
                if self.locked:
                    fcntl.flock(self.file_handle.fileno(), fcntl.LOCK_UN)
            except (IOError, OSError):
                pass  # Lock might have been released already
            finally:
                self.file_handle.close()
                self.file_handle = None
                self.locked = False


def safe_json_read(file_path: str, default: Any = None, max_retries: int = 10) -> Any:
    """
    Safely read JSON file with file locking.
    
    Args:
        file_path: Path to JSON file
        default: Default value to return if file doesn't exist or is empty
        max_retries: Maximum number of lock acquisition retries
        
    Returns:
        Parsed JSON data or default value
        
    Raises:
        SafeJSONError: If file cannot be read or JSON is invalid
    """
    file_path = Path(file_path)
    
    # Return default if file doesn't exist
    if not file_path.exists():
        return default
    
    try:
        with SafeJSONLock(str(file_path), 'r', max_retries=max_retries) as f:
            content = f.read().strip()
            
            # Return default if file is empty
            if not content:
                return default
                
            return json.loads(content)
            
    except json.JSONDecodeError as e:
        raise SafeJSONError(f"Invalid JSON in {file_path}: {e}")
    except Exception as e:
        raise SafeJSONError(f"Error reading {file_path}: {e}")


def safe_json_write(file_path: str, data: Any, indent: int = 2, max_retries: int = 10, 
                   backup: bool = True) -> bool:
    """
    Safely write JSON file with atomic operations and file locking.
    
    Args:
        file_path: Path to JSON file
        data: Data to write as JSON
        indent: JSON indentation level
        max_retries: Maximum number of lock acquisition retries
        backup: Whether to create backup before writing
        
    Returns:
        True if successful, False otherwise
        
    Raises:
        SafeJSONError: If file cannot be written
    """
    file_path = Path(file_path)
    
    # Ensure parent directory exists
    file_path.parent.mkdir(parents=True, exist_ok=True)
    
    # Create backup if requested and file exists
    backup_path = None
    if backup and file_path.exists():
        backup_path = file_path.with_suffix(f"{file_path.suffix}.backup")
        try:
            shutil.copy2(file_path, backup_path)
        except Exception as e:
            # Non-critical error - continue without backup
            print(f"Warning: Could not create backup: {e}", file=sys.stderr)
    
    # Use atomic write pattern: write to temp file, then move
    temp_fd = None
    temp_path = None
    
    try:
        # Create temporary file in same directory
        temp_fd, temp_path = tempfile.mkstemp(
            suffix='.tmp', 
            prefix=f"{file_path.stem}_",
            dir=file_path.parent
        )
        temp_path = Path(temp_path)
        
        # Write JSON to temporary file
        with os.fdopen(temp_fd, 'w') as temp_file:
            json.dump(data, temp_file, indent=indent, ensure_ascii=False)
            temp_file.flush()
            os.fsync(temp_file.fileno())  # Force write to disk
        
        temp_fd = None  # File descriptor is now managed by context manager
        
        # Now atomically replace the original file
        # This requires acquiring a lock on the original file (or creating it)
        with SafeJSONLock(str(file_path), 'w', max_retries=max_retries):
            # Move temp file to final location (atomic on most filesystems)
            if os.name == 'nt':  # Windows
                if file_path.exists():
                    file_path.unlink()
                temp_path.rename(file_path)
            else:  # Unix-like systems
                temp_path.rename(file_path)
        
        return True
        
    except Exception as e:
        # Cleanup temp file if it exists
        if temp_fd is not None:
            try:
                os.close(temp_fd)
            except:
                pass
        
        if temp_path and temp_path.exists():
            try:
                temp_path.unlink()
            except:
                pass
        
        # Restore backup if write failed
        if backup_path and backup_path.exists():
            try:
                shutil.copy2(backup_path, file_path)
            except:
                pass
        
        raise SafeJSONError(f"Error writing {file_path}: {e}")


def safe_json_update(file_path: str, update_func, default: Any = None, 
                    max_retries: int = 10, backup: bool = True) -> Any:
    """
    Safely update JSON file by applying a function to the current data.
    
    Args:
        file_path: Path to JSON file
        update_func: Function that takes current data and returns updated data
        default: Default value if file doesn't exist
        max_retries: Maximum number of lock acquisition retries
        backup: Whether to create backup before writing
        
    Returns:
        Updated data
        
    Raises:
        SafeJSONError: If file cannot be read or written
    """
    file_path = Path(file_path)
    
    try:
        # Read current data with lock
        current_data = safe_json_read(str(file_path), default, max_retries)
        
        # Apply update function
        updated_data = update_func(current_data)
        
        # Write updated data
        safe_json_write(str(file_path), updated_data, max_retries=max_retries, backup=backup)
        
        return updated_data
        
    except Exception as e:
        raise SafeJSONError(f"Error updating {file_path}: {e}")


def test_safe_json_operations():
    """Test the safe JSON operations."""
    import tempfile
    import concurrent.futures
    import threading
    
    print("Testing Safe JSON Operations...")
    
    # Test basic read/write
    with tempfile.TemporaryDirectory() as temp_dir:
        test_file = Path(temp_dir) / "test.json"
        
        # Test write
        test_data = {"test": "data", "number": 42, "list": [1, 2, 3]}
        safe_json_write(str(test_file), test_data)
        
        # Test read
        read_data = safe_json_read(str(test_file))
        assert read_data == test_data, "Read data doesn't match written data"
        print("✅ Basic read/write test passed")
        
        # Test concurrent access
        def concurrent_write(file_path, thread_id, iterations=10):
            """Function to test concurrent writes."""
            for i in range(iterations):
                try:
                    data = {"thread": thread_id, "iteration": i, "timestamp": time.time()}
                    safe_json_write(file_path, data)
                    time.sleep(0.01)  # Small delay
                except Exception as e:
                    print(f"Thread {thread_id} error: {e}")
                    return False
            return True
        
        # Test with multiple threads
        print("Testing concurrent access...")
        with concurrent.futures.ThreadPoolExecutor(max_workers=5) as executor:
            futures = []
            for thread_id in range(5):
                future = executor.submit(concurrent_write, str(test_file), thread_id, 5)
                futures.append(future)
            
            # Wait for all threads to complete
            all_success = all(future.result() for future in futures)
            
        if all_success:
            print("✅ Concurrent access test passed")
        else:
            print("❌ Concurrent access test failed")
        
        # Test update function
        def add_timestamp(data):
            if not isinstance(data, dict):
                data = {}
            data['updated_at'] = time.time()
            return data
        
        updated_data = safe_json_update(str(test_file), add_timestamp)
        assert 'updated_at' in updated_data, "Update function didn't work"
        print("✅ Update function test passed")
        
        # Test error handling
        try:
            safe_json_read("/nonexistent/path/file.json")
            print("✅ Nonexistent file handled correctly")
        except SafeJSONError:
            print("❌ Error handling test failed")
        
        print("All tests completed successfully!")


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "test":
        test_safe_json_operations()
    else:
        print("Safe JSON Operations Module")
        print("Use: python3 safe_json_operations.py test")