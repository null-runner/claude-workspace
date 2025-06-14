#!/usr/bin/env python3
"""
Smart Consistency Monitor - Intelligent File Monitoring
Riduce overhead usando dirty tracking e event-based monitoring invece di polling continuo.
"""

import json
import os
import time
import hashlib
import threading
from pathlib import Path
from typing import Dict, Set, Optional, Any
from dataclasses import dataclass, field
import sys
import logging
from concurrent.futures import ThreadPoolExecutor
import signal

# Import optimized JSON operations
try:
    from json_cache_manager import get_cache_manager
    from safe_json_operations import safe_json_read, safe_json_write, SafeJSONError
    USE_CACHE = True
except ImportError:
    from safe_json_operations import safe_json_read, safe_json_write, SafeJSONError
    USE_CACHE = False


@dataclass
class FileState:
    """Track file state for dirty checking."""
    path: Path
    last_check: float
    last_mtime: float
    last_size: int
    checksum: Optional[str] = None
    is_dirty: bool = False
    check_count: int = 0
    error_count: int = 0


class SmartConsistencyMonitor:
    """
    Smart file consistency monitor with:
    - Dirty tracking based on mtime and size
    - Exponential backoff for stable files
    - Batch validation for efficiency
    - Event-driven updates instead of continuous polling
    """
    
    def __init__(self, workspace_dir: str, check_interval: int = 60):
        self.workspace_dir = Path(workspace_dir)
        self.check_interval = check_interval
        self.running = False
        
        # State tracking
        self.file_states: Dict[str, FileState] = {}
        self.dirty_files: Set[str] = set()
        self.stable_files: Set[str] = set()
        
        # Performance tuning
        self.min_check_interval = 10  # Minimum seconds between checks for same file
        self.max_check_interval = 300  # Maximum seconds between checks
        self.stable_threshold = 5  # Number of clean checks before marking stable
        
        # Threading
        self.monitor_thread: Optional[threading.Thread] = None
        self.lock = threading.RLock()
        
        # Cache
        if USE_CACHE:
            self.cache = get_cache_manager(cache_ttl=120, max_cache_size=50)
        else:
            self.cache = None
        
        # Statistics
        self.stats = {
            'total_checks': 0,
            'dirty_detections': 0,
            'cache_hits': 0,
            'cache_misses': 0,
            'batch_validations': 0,
            'errors': 0
        }
        
        # Setup logging
        logging.basicConfig(level=logging.INFO)
        self.logger = logging.getLogger(__name__)
    
    def _get_file_signature(self, file_path: Path) -> tuple:
        """Get file signature for change detection."""
        try:
            stat = file_path.stat()
            return (stat.st_mtime, stat.st_size)
        except (OSError, IOError):
            return (0, 0)
    
    def _calculate_checksum(self, file_path: Path) -> Optional[str]:
        """Calculate file checksum for integrity verification."""
        try:
            if not file_path.exists() or file_path.stat().st_size > 1024 * 1024:  # Skip large files
                return None
            
            with open(file_path, 'rb') as f:
                content = f.read()
                return hashlib.sha256(content).hexdigest()[:16]  # Short hash
        except (OSError, IOError):
            return None
    
    def _validate_json_file(self, file_path: Path) -> Dict[str, Any]:
        """Validate single JSON file."""
        file_key = str(file_path)
        current_time = time.time()
        
        try:
            # Get file signature
            mtime, size = self._get_file_signature(file_path)
            
            # Check if we have state for this file
            if file_key in self.file_states:
                state = self.file_states[file_key]
                
                # Check if file changed
                if mtime == state.last_mtime and size == state.last_size:
                    # File unchanged, update check time
                    state.last_check = current_time
                    state.check_count += 1
                    
                    # Mark as stable if consistently clean
                    if state.check_count >= self.stable_threshold:
                        self.stable_files.add(file_key)
                        state.is_dirty = False
                        self.dirty_files.discard(file_key)
                    
                    return {
                        'path': file_key,
                        'status': 'unchanged',
                        'stable': file_key in self.stable_files
                    }
            
            # File is new or changed - validate content
            self.stats['total_checks'] += 1
            
            if self.cache:
                try:
                    data = self.cache.read_json(file_key, None)
                    self.stats['cache_hits'] += 1
                    validation_status = 'valid'
                except:
                    self.stats['cache_misses'] += 1
                    validation_status = 'invalid'
            else:
                try:
                    data = safe_json_read(file_key, None)
                    validation_status = 'valid' if data is not None else 'invalid'
                except SafeJSONError:
                    validation_status = 'invalid'
                    self.stats['errors'] += 1
            
            # Update file state
            checksum = self._calculate_checksum(file_path) if validation_status == 'invalid' else None
            
            self.file_states[file_key] = FileState(
                path=file_path,
                last_check=current_time,
                last_mtime=mtime,
                last_size=size,
                checksum=checksum,
                is_dirty=(validation_status == 'invalid'),
                check_count=1,
                error_count=1 if validation_status == 'invalid' else 0
            )
            
            # Update dirty tracking
            if validation_status == 'invalid':
                self.dirty_files.add(file_key)
                self.stable_files.discard(file_key)
                self.stats['dirty_detections'] += 1
            else:
                self.dirty_files.discard(file_key)
            
            return {
                'path': file_key,
                'status': validation_status,
                'mtime': mtime,
                'size': size,
                'checksum': checksum
            }
            
        except Exception as e:
            self.stats['errors'] += 1
            self.logger.error(f"Error validating {file_path}: {e}")
            return {
                'path': file_key,
                'status': 'error',
                'error': str(e)
            }
    
    def _get_monitored_files(self) -> list:
        """Get list of JSON files to monitor."""
        claude_dir = self.workspace_dir / ".claude"
        if not claude_dir.exists():
            return []
        
        json_files = []
        for pattern in ["**/*.json"]:
            json_files.extend(claude_dir.glob(pattern))
        
        # Filter out temporary and backup files
        return [f for f in json_files 
                if not any(part.startswith('.') for part in f.parts[len(claude_dir.parts):])
                and not f.name.endswith('.backup')
                and not f.name.endswith('.tmp')]
    
    def _should_check_file(self, file_path: str) -> bool:
        """Determine if file should be checked based on smart scheduling."""
        current_time = time.time()
        
        if file_path not in self.file_states:
            return True  # Always check new files
        
        state = self.file_states[file_path]
        
        # Calculate dynamic check interval based on file stability
        if file_path in self.stable_files:
            # Stable files checked less frequently
            check_interval = min(self.max_check_interval, 
                               self.min_check_interval * (2 ** min(state.check_count - self.stable_threshold, 4)))
        else:
            # Dirty or new files checked more frequently
            check_interval = self.min_check_interval
        
        return (current_time - state.last_check) >= check_interval
    
    def batch_validate(self, force_all: bool = False) -> Dict[str, Any]:
        """Perform batch validation of monitored files."""
        files_to_check = self._get_monitored_files()
        
        if not force_all:
            # Filter to only files that need checking
            files_to_check = [f for f in files_to_check 
                             if self._should_check_file(str(f))]
        
        if not files_to_check:
            return {
                'checked': 0,
                'dirty': len(self.dirty_files),
                'stable': len(self.stable_files),
                'status': 'no_files_to_check'
            }
        
        self.stats['batch_validations'] += 1
        results = []
        
        # Use thread pool for parallel validation
        with ThreadPoolExecutor(max_workers=4) as executor:
            future_to_file = {
                executor.submit(self._validate_json_file, file_path): file_path
                for file_path in files_to_check
            }
            
            for future in future_to_file:
                try:
                    result = future.result(timeout=5)
                    results.append(result)
                except Exception as e:
                    file_path = future_to_file[future]
                    self.logger.error(f"Validation failed for {file_path}: {e}")
                    results.append({
                        'path': str(file_path),
                        'status': 'timeout',
                        'error': str(e)
                    })
        
        # Summary
        valid_count = sum(1 for r in results if r['status'] == 'valid')
        invalid_count = sum(1 for r in results if r['status'] == 'invalid')
        error_count = sum(1 for r in results if r['status'] in ['error', 'timeout'])
        
        return {
            'checked': len(results),
            'valid': valid_count,
            'invalid': invalid_count,
            'errors': error_count,
            'dirty_files': list(self.dirty_files),
            'stable_files': len(self.stable_files),
            'results': results
        }
    
    def start_monitoring(self):
        """Start background monitoring thread."""
        if self.running:
            return
        
        self.running = True
        self.monitor_thread = threading.Thread(target=self._monitor_loop, daemon=True)
        self.monitor_thread.start()
        self.logger.info("Smart consistency monitoring started")
    
    def stop_monitoring(self):
        """Stop background monitoring."""
        self.running = False
        if self.monitor_thread:
            self.monitor_thread.join(timeout=5)
        self.logger.info("Smart consistency monitoring stopped")
    
    def _monitor_loop(self):
        """Main monitoring loop."""
        while self.running:
            try:
                result = self.batch_validate()
                
                if result['checked'] > 0:
                    self.logger.info(f"Batch validation: {result['checked']} files checked, "
                                   f"{result.get('invalid', 0)} dirty, "
                                   f"{result.get('errors', 0)} errors")
                
                # Adaptive sleep based on dirty file count
                if len(self.dirty_files) > 0:
                    sleep_time = self.check_interval // 2  # Check dirty files more frequently
                else:
                    sleep_time = self.check_interval
                
                time.sleep(sleep_time)
                
            except Exception as e:
                self.logger.error(f"Monitor loop error: {e}")
                time.sleep(self.check_interval)
    
    def get_status(self) -> Dict[str, Any]:
        """Get current monitor status and statistics."""
        return {
            'running': self.running,
            'total_files': len(self.file_states),
            'dirty_files': len(self.dirty_files),
            'stable_files': len(self.stable_files),
            'dirty_file_list': list(self.dirty_files),
            'stats': dict(self.stats),
            'last_check': max([state.last_check for state in self.file_states.values()], default=0)
        }
    
    def force_check(self, file_path: Optional[str] = None):
        """Force immediate check of specific file or all files."""
        if file_path:
            if Path(file_path).exists():
                result = self._validate_json_file(Path(file_path))
                return {'file': file_path, 'result': result}
            else:
                return {'error': f'File not found: {file_path}'}
        else:
            return self.batch_validate(force_all=True)


def main():
    """CLI interface for smart consistency monitor."""
    if len(sys.argv) < 2:
        print("Usage: smart-consistency-monitor.py <command> [args...]")
        print("Commands:")
        print("  start     - Start background monitoring")
        print("  check     - Perform immediate batch check")
        print("  status    - Show current status")
        print("  force     - Force check all files")
        print("  daemon    - Run as daemon (blocking)")
        sys.exit(1)
    
    workspace_dir = os.environ.get('WORKSPACE_DIR', os.path.expanduser('~/claude-workspace'))
    monitor = SmartConsistencyMonitor(workspace_dir)
    
    command = sys.argv[1]
    
    if command == "start":
        monitor.start_monitoring()
        print("Smart consistency monitor started in background")
    
    elif command == "check":
        result = monitor.batch_validate()
        print(json.dumps(result, indent=2))
    
    elif command == "status":
        status = monitor.get_status()
        print(json.dumps(status, indent=2))
    
    elif command == "force":
        file_path = sys.argv[2] if len(sys.argv) > 2 else None
        result = monitor.force_check(file_path)
        print(json.dumps(result, indent=2))
    
    elif command == "daemon":
        # Run as blocking daemon
        def signal_handler(signum, frame):
            print("\nStopping monitor...")
            monitor.stop_monitoring()
            sys.exit(0)
        
        signal.signal(signal.SIGINT, signal_handler)
        signal.signal(signal.SIGTERM, signal_handler)
        
        monitor.start_monitoring()
        print("Smart consistency monitor running as daemon. Press Ctrl+C to stop.")
        
        try:
            while monitor.running:
                time.sleep(1)
        except KeyboardInterrupt:
            monitor.stop_monitoring()
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()