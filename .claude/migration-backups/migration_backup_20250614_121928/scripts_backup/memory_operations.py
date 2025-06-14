#!/usr/bin/env python3
"""
Memory Operations - Persistent Python Process for claude-simplified-memory.sh
Elimina overhead di spawning Python ogni volta.
"""

import json
import sys
import os
import subprocess
from datetime import datetime
from pathlib import Path

# Import optimized JSON operations
try:
    from json_cache_manager import get_cache_manager
    from safe_json_operations import safe_json_read, safe_json_write, SafeJSONError
    USE_CACHE = True
except ImportError:
    from safe_json_operations import safe_json_read, safe_json_write, SafeJSONError
    USE_CACHE = False


class MemoryOperations:
    """Persistent memory operations handler."""
    
    def __init__(self, workspace_dir: str):
        self.workspace_dir = Path(workspace_dir)
        self.memory_dir = self.workspace_dir / ".claude" / "memory"
        self.context_file = self.memory_dir / "enhanced-context.json"
        
        if USE_CACHE:
            self.cache = get_cache_manager(cache_ttl=300, max_cache_size=50)
        else:
            self.cache = None
    
    def _json_read(self, file_path: str, default=None):
        """Optimized JSON read."""
        if self.cache:
            return self.cache.read_json(file_path, default)
        else:
            return safe_json_read(file_path, default)
    
    def _json_write(self, file_path: str, data, immediate=True):
        """Optimized JSON write."""
        if self.cache:
            return self.cache.write_json(file_path, data, immediate)
        else:
            return safe_json_write(file_path, data)
    
    def get_git_status(self):
        """Get simplified git status (cached version)."""
        try:
            # Use cached results for git status to avoid repeated subprocess calls
            cache_file = self.memory_dir / "git-status-cache.json"
            cache_ttl = 30  # 30 seconds cache for git status
            
            # Check if cache is valid
            if cache_file.exists():
                try:
                    cache_data = self._json_read(str(cache_file), {})
                    if (datetime.now().timestamp() - cache_data.get('timestamp', 0)) < cache_ttl:
                        return cache_data.get('git_status', {})
                except:
                    pass
            
            # Get fresh git status
            workspace_dir = str(self.workspace_dir)
            
            # Check if we're in a git repository
            try:
                subprocess.run(['git', 'rev-parse', '--git-dir'], 
                              capture_output=True, check=True, cwd=workspace_dir)
            except subprocess.CalledProcessError:
                return {"is_git_repo": False}
            
            # Get current branch
            try:
                branch_result = subprocess.run(['git', 'branch', '--show-current'], 
                                             capture_output=True, text=True, cwd=workspace_dir)
                current_branch = branch_result.stdout.strip() if branch_result.returncode == 0 else "unknown"
            except:
                current_branch = "unknown"
            
            # Check for changes
            try:
                status_result = subprocess.run(['git', 'status', '--porcelain'], 
                                             capture_output=True, text=True, cwd=workspace_dir)
                
                if status_result.returncode == 0:
                    dirty_files = [line for line in status_result.stdout.strip().split('\n') if line]
                    has_changes = len(dirty_files) > 0
                    dirty_files_count = len(dirty_files)
                else:
                    has_changes = False
                    dirty_files_count = 0
                    dirty_files = []
            except:
                has_changes = False
                dirty_files_count = 0
                dirty_files = []
            
            # Get last commit info
            try:
                commit_result = subprocess.run(['git', 'log', '-1', '--oneline'], 
                                             capture_output=True, text=True, cwd=workspace_dir)
                last_commit = commit_result.stdout.strip() if commit_result.returncode == 0 else "No commits"
            except:
                last_commit = "No commits"
            
            git_status = {
                "branch": current_branch,
                "has_changes": has_changes,
                "dirty_files_count": dirty_files_count,
                "dirty_files": dirty_files,
                "last_commit": last_commit,
                "is_git_repo": True
            }
            
            # Cache the result
            cache_data = {
                "git_status": git_status,
                "timestamp": datetime.now().timestamp()
            }
            self._json_write(str(cache_file), cache_data, immediate=False)
            
            return git_status
            
        except Exception as e:
            return {"error": str(e), "is_git_repo": False}
    
    def get_project_info(self):
        """Get current project information."""
        try:
            project_file = self.workspace_dir / ".claude" / "auto-projects" / "current.json"
            project_data = self._json_read(str(project_file), {})
            return project_data.get('current_project', {})
        except:
            return {}
    
    def save_context(self, save_reason="manual", conversation_summary="", 
                    open_issues=None, next_actions=None):
        """Save enhanced context with optimized operations."""
        try:
            # Get all required data
            git_status = self.get_git_status()
            project_info = self.get_project_info()
            
            # Create context data
            context_data = {
                "context_version": "enhanced-v1",
                "timestamp": datetime.now().isoformat(),
                "save_reason": save_reason,
                "device": os.environ.get('HOSTNAME', 'unknown'),
                "working_directory": str(self.workspace_dir),
                "git_status": git_status,
                "current_project": project_info,
                "conversation_summary": conversation_summary,
                "open_issues": open_issues or [],
                "next_actions": next_actions or []
            }
            
            # Write context (use immediate write for important data)
            success = self._json_write(str(self.context_file), context_data, immediate=True)
            
            # Flush any pending cache writes
            if self.cache:
                self.cache.flush_writes()
            
            return success
            
        except Exception as e:
            print(f"Error saving context: {e}", file=sys.stderr)
            return False
    
    def load_context(self):
        """Load enhanced context with optimized operations."""
        try:
            context = self._json_read(str(self.context_file), {})
            
            if not context:
                return {"error": "No context found"}
            
            # Add current git status if context is old
            if context.get('timestamp'):
                try:
                    context_time = datetime.fromisoformat(context['timestamp'])
                    if (datetime.now() - context_time).total_seconds() > 300:  # 5 minutes
                        context['current_git_status'] = self.get_git_status()
                except:
                    pass
            
            return context
            
        except Exception as e:
            return {"error": str(e)}
    
    def get_cache_stats(self):
        """Get performance statistics."""
        if self.cache:
            return self.cache.get_stats()
        else:
            return {"cache": "not_available"}


def main():
    """Main CLI interface."""
    if len(sys.argv) < 2:
        print("Usage: memory-operations.py <command> [args...]")
        sys.exit(1)
    
    workspace_dir = os.environ.get('WORKSPACE_DIR', os.path.expanduser('~/claude-workspace'))
    memory_ops = MemoryOperations(workspace_dir)
    
    command = sys.argv[1]
    
    if command == "git_status":
        result = memory_ops.get_git_status()
        print(json.dumps(result, indent=2))
    
    elif command == "project_info":
        result = memory_ops.get_project_info()
        print(json.dumps(result, indent=2))
    
    elif command == "save_context":
        save_reason = sys.argv[2] if len(sys.argv) > 2 else "manual"
        conversation_summary = sys.argv[3] if len(sys.argv) > 3 else ""
        open_issues = sys.argv[4].split('|') if len(sys.argv) > 4 and sys.argv[4] else []
        next_actions = sys.argv[5].split('|') if len(sys.argv) > 5 and sys.argv[5] else []
        
        success = memory_ops.save_context(save_reason, conversation_summary, open_issues, next_actions)
        print(json.dumps({"success": success}))
    
    elif command == "load_context":
        result = memory_ops.load_context()
        print(json.dumps(result, indent=2))
    
    elif command == "stats":
        result = memory_ops.get_cache_stats()
        print(json.dumps(result, indent=2))
    
    else:
        print(f"Unknown command: {command}")
        sys.exit(1)


if __name__ == "__main__":
    main()