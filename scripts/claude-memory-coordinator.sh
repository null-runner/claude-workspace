#!/bin/bash
# Claude Memory Coordinator - Unified Memory System
# Consolidates simplified-memory, enhanced-save, and intelligent-auto-sync
# Eliminates race conditions and provides centralized coordination

WORKSPACE_DIR="$HOME/claude-workspace"
COORD_DIR="$WORKSPACE_DIR/.claude/memory-coordination"
MEMORY_DIR="$WORKSPACE_DIR/.claude/memory"
COORD_LOCK="$COORD_DIR/memory-coordinator.lock"
OPERATION_QUEUE="$COORD_DIR/operation-queue.json"
COORD_LOG="$COORD_DIR/coordinator.log"
HEALTH_STATUS="$COORD_DIR/health-status.json"
UNIFIED_CONTEXT="$MEMORY_DIR/unified-context.json"
SESSION_HISTORY="$MEMORY_DIR/session-history.json"
INTELLIGENCE_CACHE="$MEMORY_DIR/intelligence-cache.json"
SYNC_METADATA="$MEMORY_DIR/sync-metadata.json"

# Timeout configurations
LOCK_TIMEOUT=30  # 30 seconds max lock time
QUEUE_TIMEOUT=60 # 60 seconds max queue wait time

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Setup
mkdir -p "$COORD_DIR"
mkdir -p "$MEMORY_DIR"

# Logging function
coord_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$COORD_LOG"
    
    # Echo to stderr for debugging (will be hidden in production)
    echo -e "${CYAN}[COORD]${NC} [$level] $message" >&2
}

# Initialize coordinator queue if not exists
init_queue() {
    if [[ ! -f "$OPERATION_QUEUE" ]]; then
        echo '{"operations": [], "last_cleanup": null}' > "$OPERATION_QUEUE"
    fi
}

# Acquire coordination lock with timeout
acquire_lock() {
    local caller="$1"
    local max_attempts=$((LOCK_TIMEOUT * 2))  # Check every 0.5 seconds
    local attempts=0
    
    while [[ $attempts -lt $max_attempts ]]; do
        if (set -C; echo "$caller:$$:$(date +%s)" > "$COORD_LOCK") 2>/dev/null; then
            coord_log "LOCK" "Lock acquired by $caller (PID: $$)"
            return 0
        fi
        
        # Check if lock is stale (older than LOCK_TIMEOUT)
        if [[ -f "$COORD_LOCK" ]]; then
            local lock_info=$(cat "$COORD_LOCK" 2>/dev/null || echo "")
            if [[ -n "$lock_info" ]]; then
                local lock_timestamp=$(echo "$lock_info" | cut -d: -f3)
                local current_time=$(date +%s)
                local lock_age=$((current_time - lock_timestamp))
                
                if [[ $lock_age -gt $LOCK_TIMEOUT ]]; then
                    coord_log "WARN" "Removing stale lock from $lock_info (age: ${lock_age}s)"
                    rm -f "$COORD_LOCK"
                    continue
                fi
            fi
        fi
        
        attempts=$((attempts + 1))
        sleep 0.5
    done
    
    coord_log "ERROR" "Failed to acquire lock after ${LOCK_TIMEOUT}s (caller: $caller)"
    return 1
}

# Release coordination lock
release_lock() {
    local caller="$1"
    
    if [[ -f "$COORD_LOCK" ]]; then
        local lock_info=$(cat "$COORD_LOCK" 2>/dev/null || echo "")
        local lock_caller=$(echo "$lock_info" | cut -d: -f1)
        local lock_pid=$(echo "$lock_info" | cut -d: -f2)
        
        # Only release if we own the lock
        if [[ "$lock_caller" == "$caller" && "$lock_pid" == "$$" ]]; then
            rm -f "$COORD_LOCK"
            coord_log "LOCK" "Lock released by $caller (PID: $$)"
            return 0
        else
            coord_log "WARN" "Lock not owned by $caller:$$ (current: $lock_info)"
            return 1
        fi
    else
        coord_log "WARN" "No lock file found for release by $caller"
        return 1
    fi
}

# Cleanup function
cleanup_on_exit() {
    release_lock "${BASH_SOURCE[1]##*/}"
}
trap cleanup_on_exit EXIT

# Queue operation for coordination
queue_operation() {
    local operation="$1"
    local caller="$2"
    local priority="${3:-normal}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    init_queue
    
    python3 << EOF
import json
import sys
from datetime import datetime, timedelta

try:
    # Load current queue
    with open("$OPERATION_QUEUE", "r") as f:
        queue_data = json.load(f)
    
    # Add new operation
    new_operation = {
        "id": "${timestamp}-${caller}",
        "operation": "$operation",
        "caller": "$caller",
        "priority": "$priority",
        "timestamp": "$timestamp",
        "status": "pending"
    }
    
    queue_data["operations"].append(new_operation)
    
    # Sort by priority (high first) and timestamp
    priority_order = {"high": 0, "normal": 1, "low": 2}
    queue_data["operations"].sort(
        key=lambda x: (priority_order.get(x["priority"], 1), x["timestamp"])
    )
    
    # Keep only last 50 operations
    queue_data["operations"] = queue_data["operations"][-50:]
    
    # Save updated queue
    with open("$OPERATION_QUEUE", "w") as f:
        json.dump(queue_data, f, indent=2)
    
    print(f"✅ Operation queued: {new_operation['id']}")
    
except Exception as e:
    print(f"❌ Failed to queue operation: {e}")
    sys.exit(1)
EOF
}

# Process operation queue
process_queue() {
    init_queue
    
    python3 << 'EOF'
import json
import subprocess
import sys
import os
from datetime import datetime, timedelta

def process_operations():
    try:
        with open(os.environ.get("OPERATION_QUEUE", "/home/nullrunner/claude-workspace/.claude/memory-coordination/operation-queue.json"), "r") as f:
            queue_data = json.load(f)
        
        pending_ops = [op for op in queue_data["operations"] if op["status"] == "pending"]
        
        if not pending_ops:
            print("No pending operations")
            return
        
        processed_count = 0
        
        for operation in pending_ops[:5]:  # Process max 5 at once
            op_id = operation["id"]
            op_type = operation["operation"]
            caller = operation["caller"]
            
            print(f"Processing: {op_id} ({op_type} from {caller})")
            
            # Mark as processing
            operation["status"] = "processing"
            operation["processed_at"] = datetime.now().isoformat() + "Z"
            
            # Save intermediate state
            with open(os.environ.get("OPERATION_QUEUE", "/home/nullrunner/claude-workspace/.claude/memory-coordination/operation-queue.json"), "w") as f:
                json.dump(queue_data, f, indent=2)
            
            # Execute operation based on type
            success = execute_operation(operation)
            
            # Update status
            operation["status"] = "completed" if success else "failed"
            operation["completed_at"] = datetime.now().isoformat() + "Z"
            
            processed_count += 1
        
        # Clean up old operations (older than 24 hours)
        cutoff_time = datetime.now() - timedelta(hours=24)
        queue_data["operations"] = [
            op for op in queue_data["operations"]
            if datetime.fromisoformat(op["timestamp"].replace('Z', '')) > cutoff_time
        ]
        
        queue_data["last_cleanup"] = datetime.now().isoformat() + "Z"
        
        # Save final state
        with open(os.environ.get("OPERATION_QUEUE", "/home/nullrunner/claude-workspace/.claude/memory-coordination/operation-queue.json"), "w") as f:
            json.dump(queue_data, f, indent=2)
        
        print(f"Processed {processed_count} operations")
        
    except Exception as e:
        print(f"Error processing queue: {e}")

def execute_operation(operation):
    """Execute specific operation type"""
    op_type = operation["operation"]
    caller = operation["caller"]
    
    try:
        if op_type == "simplified_save":
            # Execute simplified memory save
            return execute_simplified_save(operation)
        elif op_type == "enhanced_save":
            # Execute enhanced memory save
            return execute_enhanced_save(operation)
        elif op_type == "auto_save":
            # Execute auto memory save
            return execute_auto_save(operation)
        else:
            print(f"Unknown operation type: {op_type}")
            return False
    except Exception as e:
        print(f"Error executing {op_type}: {e}")
        return False

def execute_simplified_save(operation):
    """Execute simplified memory save"""
    try:
        # Call simplified memory save directly
        script_path = os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts", "claude-simplified-memory.sh")
        
        # Extract parameters from operation if available
        params = operation.get("params", {})
        cmd = [script_path, "save"]
        
        if params.get("reason"):
            cmd.append(params["reason"])
        if params.get("summary"):
            cmd.append(params["summary"])
        if params.get("issues"):
            cmd.append(params["issues"])
        if params.get("actions"):
            cmd.append(params["actions"])
        
        result = subprocess.run(cmd, capture_output=True, text=True, 
                              env=dict(os.environ, MEMORY_COORD_MODE="true"))
        
        return result.returncode == 0
    except Exception as e:
        print(f"Error in simplified save: {e}")
        return False

def execute_enhanced_save(operation):
    """Execute enhanced memory save"""
    try:
        script_path = os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts", "claude-enhanced-save.sh")
        
        params = operation.get("params", {})
        cmd = [script_path]
        
        if params.get("note"):
            cmd.append(params["note"])
        if params.get("summary"):
            cmd.append(params["summary"])
        if params.get("tasks"):
            cmd.append(params["tasks"])
        if params.get("next_steps"):
            cmd.append(params["next_steps"])
        
        result = subprocess.run(cmd, capture_output=True, text=True,
                              env=dict(os.environ, MEMORY_COORD_MODE="true"))
        
        return result.returncode == 0
    except Exception as e:
        print(f"Error in enhanced save: {e}")
        return False

def execute_auto_save(operation):
    """Execute auto memory save"""
    try:
        # Auto save is handled by calling enhanced save internally
        params = operation.get("params", {})
        auto_note = params.get("note", "Auto-save coordinated")
        
        script_path = os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts", "claude-enhanced-save.sh")
        result = subprocess.run([script_path, auto_note], capture_output=True, text=True,
                              env=dict(os.environ, MEMORY_COORD_MODE="true"))
        
        return result.returncode == 0
    except Exception as e:
        print(f"Error in auto save: {e}")
        return False

process_operations()
EOF
}

# Public API: Request coordinated save
request_save() {
    local save_type="$1"  # simplified, enhanced, auto
    local caller="$2"
    local priority="${3:-normal}"
    shift 3
    local params="$*"
    
    coord_log "API" "Save request: $save_type from $caller (priority: $priority)"
    
    # Parse parameters into JSON format
    local param_json='{"raw_params": "'"$params"'"}'
    
    # Add specific parameter parsing based on save type
    if [[ "$save_type" == "simplified" ]]; then
        param_json=$(echo "$params" | python3 -c "
import sys
import json
params = sys.stdin.read().strip().split()
result = {'raw_params': ' '.join(params)}
if len(params) > 0: result['reason'] = params[0]
if len(params) > 1: result['summary'] = params[1]
if len(params) > 2: result['issues'] = params[2]
if len(params) > 3: result['actions'] = params[3]
print(json.dumps(result))
")
    elif [[ "$save_type" == "enhanced" ]]; then
        param_json=$(echo "$params" | python3 -c "
import sys
import json
params = sys.stdin.read().strip().split()
result = {'raw_params': ' '.join(params)}
if len(params) > 0: result['note'] = params[0]
if len(params) > 1: result['summary'] = params[1]  
if len(params) > 2: result['tasks'] = params[2]
if len(params) > 3: result['next_steps'] = params[3]
print(json.dumps(result))
")
    elif [[ "$save_type" == "auto" ]]; then
        param_json=$(echo "$params" | python3 -c "
import sys
import json
params = sys.stdin.read().strip()
result = {'note': params if params else 'Auto-save coordinated'}
print(json.dumps(result))
")
    fi
    
    # Check if we can execute immediately or need to queue
    if acquire_lock "$caller"; then
        coord_log "EXEC" "Executing $save_type save immediately"
        
        # Create temporary operation for immediate execution
        local temp_op=$(python3 -c "
import json
op = {
    'operation': '${save_type}_save',
    'caller': '$caller',
    'params': $param_json
}
print(json.dumps(op))
")
        
        # Execute immediately
        python3 << EOF
import json
import os
operation = json.loads('$temp_op')
exec(open(os.path.join(os.path.dirname(__file__), 'process_queue_functions.py')).read()) if os.path.exists(os.path.join(os.path.dirname(__file__), 'process_queue_functions.py')) else None

# Inline execution functions
def execute_operation(operation):
    op_type = operation["operation"]
    try:
        if op_type == "simplified_save":
            return execute_simplified_save(operation)
        elif op_type == "enhanced_save":
            return execute_enhanced_save(operation)
        elif op_type == "auto_save":
            return execute_auto_save(operation)
        else:
            return False
    except Exception as e:
        print(f"Error executing {op_type}: {e}")
        return False

def execute_simplified_save(operation):
    import subprocess
    try:
        script_path = os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts", "claude-simplified-memory.sh")
        params = operation.get("params", {})
        cmd = [script_path, "save"]
        
        if params.get("reason"):
            cmd.append(params["reason"])
        if params.get("summary"):
            cmd.append(params["summary"])
        if params.get("issues"):
            cmd.append(params["issues"])
        if params.get("actions"):
            cmd.append(params["actions"])
        
        result = subprocess.run(cmd, capture_output=True, text=True, 
                              env=dict(os.environ, MEMORY_COORD_MODE="true"))
        
        if result.returncode == 0:
            print("✅ Simplified save completed")
        else:
            print(f"❌ Simplified save failed: {result.stderr}")
        
        return result.returncode == 0
    except Exception as e:
        print(f"Error in simplified save: {e}")
        return False

def execute_enhanced_save(operation):
    import subprocess
    try:
        script_path = os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts", "claude-enhanced-save.sh")
        params = operation.get("params", {})
        cmd = [script_path]
        
        if params.get("note"):
            cmd.append(params["note"])
        if params.get("summary"):
            cmd.append(params["summary"])
        if params.get("tasks"):
            cmd.append(params["tasks"])
        if params.get("next_steps"):
            cmd.append(params["next_steps"])
        
        result = subprocess.run(cmd, capture_output=True, text=True,
                              env=dict(os.environ, MEMORY_COORD_MODE="true"))
        
        if result.returncode == 0:
            print("✅ Enhanced save completed")
        else:
            print(f"❌ Enhanced save failed: {result.stderr}")
        
        return result.returncode == 0
    except Exception as e:
        print(f"Error in enhanced save: {e}")
        return False

def execute_auto_save(operation):
    import subprocess
    try:
        params = operation.get("params", {})
        auto_note = params.get("note", "Auto-save coordinated")
        
        script_path = os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts", "claude-enhanced-save.sh")
        result = subprocess.run([script_path, auto_note], capture_output=True, text=True,
                              env=dict(os.environ, MEMORY_COORD_MODE="true"))
        
        if result.returncode == 0:
            print("✅ Auto save completed")
        else:
            print(f"❌ Auto save failed: {result.stderr}")
        
        return result.returncode == 0
    except Exception as e:
        print(f"Error in auto save: {e}")
        return False

# Execute the operation
success = execute_operation(operation)
print(f"Operation result: {'SUCCESS' if success else 'FAILED'}")
EOF
        
        release_lock "$caller"
    else
        coord_log "QUEUE" "Queueing $save_type save from $caller (lock unavailable)"
        
        # Queue the operation
        python3 << EOF
import json
import sys

operation_data = {
    "operation": "${save_type}_save",
    "caller": "$caller",
    "priority": "$priority",
    "params": $param_json
}

try:
    # Load current queue
    with open("$OPERATION_QUEUE", "r") as f:
        queue_data = json.load(f)
    
    # Add new operation
    import datetime
    timestamp = datetime.datetime.now().isoformat() + "Z"
    new_operation = {
        "id": f"{timestamp}-$caller",
        "timestamp": timestamp,
        "status": "pending",
        **operation_data
    }
    
    queue_data["operations"].append(new_operation)
    
    # Sort by priority and timestamp
    priority_order = {"high": 0, "normal": 1, "low": 2}
    queue_data["operations"].sort(
        key=lambda x: (priority_order.get(x["priority"], 1), x["timestamp"])
    )
    
    # Save updated queue
    with open("$OPERATION_QUEUE", "w") as f:
        json.dump(queue_data, f, indent=2)
    
    print(f"✅ Operation queued: {new_operation['id']}")
    
except Exception as e:
    print(f"❌ Failed to queue operation: {e}")
    sys.exit(1)
EOF
        
        echo "Operation queued. Use 'claude-memory-coordinator process' to execute queued operations."
    fi
}

# Status check
show_status() {
    init_queue
    
    echo -e "${CYAN}🧠 Memory Coordinator Status${NC}"
    echo ""
    
    if [[ -f "$COORD_LOCK" ]]; then
        local lock_info=$(cat "$COORD_LOCK")
        echo -e "${YELLOW}🔒 Coordinator Lock: ACTIVE${NC}"
        echo "   Lock info: $lock_info"
    else
        echo -e "${GREEN}🔓 Coordinator Lock: FREE${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}📋 Operation Queue:${NC}"
    
    export OPERATION_QUEUE
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

try:
    with open(os.environ.get("OPERATION_QUEUE", "/home/nullrunner/claude-workspace/.claude/memory-coordination/operation-queue.json"), "r") as f:
        queue_data = json.load(f)
    
    operations = queue_data.get("operations", [])
    
    if not operations:
        print("   No operations in queue")
    else:
        # Group by status
        pending = [op for op in operations if op["status"] == "pending"]
        processing = [op for op in operations if op["status"] == "processing"]
        completed = [op for op in operations if op["status"] == "completed"]
        failed = [op for op in operations if op["status"] == "failed"]
        
        print(f"   Pending: {len(pending)}")
        print(f"   Processing: {len(processing)}")
        print(f"   Completed: {len(completed)}")
        print(f"   Failed: {len(failed)}")
        
        if pending:
            print("\n   Next pending operations:")
            for op in pending[:3]:
                timestamp = op["timestamp"][:19].replace('T', ' ')
                print(f"     • {op['operation']} from {op['caller']} ({timestamp})")
    
    last_cleanup = queue_data.get("last_cleanup")
    if last_cleanup:
        print(f"\n   Last cleanup: {last_cleanup[:19].replace('T', ' ')}")
    
except Exception as e:
    print(f"   Error reading queue: {e}")
EOF
}

# Help
show_help() {
    echo "Claude Memory Coordinator - Unified Memory System"
    echo ""
    echo "Usage: claude-memory-coordinator [command] [options]"
    echo ""
    echo "Main Commands:"
    echo "  save <type> [params...]      Direct unified save"
    echo "  load                         Load unified context"
    echo "  status                       Show system status"
    echo ""
    echo "Save Types:"
    echo "  simplified [reason] [summary] [issues] [actions]"
    echo "  enhanced [note] [summary] [tasks] [next_steps]"
    echo "  auto [note]"
    echo ""
    echo "Advanced Commands:"
    echo "  request-save <type> <caller> [priority] [params...]"
    echo "  process                      Process queued operations"
    echo "  clear-queue                  Clear operation queue"
    echo "  logs                         Show coordinator logs"
    echo "  health                       Show health status"
    echo ""
    echo "Examples:"
    echo "  claude-memory-coordinator save simplified manual 'Working on auth'"
    echo "  claude-memory-coordinator save enhanced 'Session end' 'Bug fixes completed'"
    echo "  claude-memory-coordinator load"
    echo "  claude-memory-coordinator status"
}

# Health monitoring
update_health_status() {
    local component="$1"
    local status="$2"
    local message="$3"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    python3 << EOF
import json
import sys
import os
from datetime import datetime

# Import safe JSON operations
sys.path.insert(0, os.path.dirname(os.path.abspath('$WORKSPACE_DIR/scripts/safe_json_operations.py')))
from safe_json_operations import safe_json_read, safe_json_write, SafeJSONError

try:
    health_data = safe_json_read("$HEALTH_STATUS", {
        "system_status": "unknown",
        "last_update": None,
        "components": {},
        "issues": []
    })
    
    # Update component status
    health_data["components"]["$component"] = {
        "status": "$status",
        "message": "$message",
        "last_update": "$timestamp"
    }
    
    # Update overall system status
    component_statuses = [comp["status"] for comp in health_data["components"].values()]
    if "error" in component_statuses:
        health_data["system_status"] = "error"
    elif "warning" in component_statuses:
        health_data["system_status"] = "warning"
    elif all(status == "healthy" for status in component_statuses):
        health_data["system_status"] = "healthy"
    else:
        health_data["system_status"] = "unknown"
    
    health_data["last_update"] = "$timestamp"
    
    safe_json_write("$HEALTH_STATUS", health_data, indent=2)
    
except Exception as e:
    print(f"Error updating health status: {e}", file=sys.stderr)
EOF
}

# Unified context operations
unified_context_save() {
    local save_type="$1"
    local caller="$2"
    local priority="$3"
    shift 3
    local params="$*"
    
    coord_log "SAVE" "Unified context save: $save_type from $caller"
    update_health_status "context_save" "active" "Processing $save_type save"
    
    # Export environment for safe operations
    export WORKSPACE_DIR MEMORY_DIR UNIFIED_CONTEXT SESSION_HISTORY INTELLIGENCE_CACHE
    
    python3 << 'EOF'
import json
import sys
import os
import subprocess
from datetime import datetime
from pathlib import Path

# Import safe JSON operations
sys.path.insert(0, os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts"))
from safe_json_operations import safe_json_read, safe_json_write, SafeJSONError

def get_git_status():
    """Get comprehensive git status"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR', '/home/nullrunner/claude-workspace')
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True, cwd=workspace_dir)
        
        branch_result = subprocess.run(['git', 'branch', '--show-current'], 
                                     capture_output=True, text=True, cwd=workspace_dir)
        current_branch = branch_result.stdout.strip() if branch_result.returncode == 0 else "unknown"
        
        commit_result = subprocess.run(['git', 'log', '-1', '--oneline'], 
                                     capture_output=True, text=True, cwd=workspace_dir)
        last_commit = commit_result.stdout.strip() if commit_result.returncode == 0 else "No commits"
        
        if result.returncode == 0:
            dirty_files = [line for line in result.stdout.strip().split('\n') if line]
            return {
                "branch": current_branch,
                "has_changes": len(dirty_files) > 0,
                "dirty_files_count": len(dirty_files),
                "dirty_files": dirty_files[:10],  # Limit to first 10
                "last_commit": last_commit,
                "is_git_repo": True
            }
    except Exception as e:
        pass
    
    return {
        "branch": "unknown",
        "has_changes": False,
        "dirty_files_count": 0,
        "dirty_files": [],
        "last_commit": "Unknown",
        "is_git_repo": False
    }

def get_current_project():
    """Detect current project using multiple strategies"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR', '/home/nullrunner/claude-workspace')
        cwd = os.getcwd()
        
        # Strategy 1: Advanced project detector
        detector_script = os.path.join(workspace_dir, 'scripts', 'claude-auto-project-detector.sh')
        if os.path.exists(detector_script):
            result = subprocess.run([detector_script, 'detect'], 
                                  capture_output=True, text=True, cwd=workspace_dir)
            if result.returncode == 0 and result.stdout.strip() != "null":
                return json.loads(result.stdout.strip())
        
        # Strategy 2: Path-based detection
        if cwd.startswith(workspace_dir):
            relative_path = os.path.relpath(cwd, workspace_dir)
            path_parts = relative_path.split(os.sep)
            
            if len(path_parts) >= 3 and path_parts[0] == "projects":
                return {
                    "name": path_parts[2],
                    "type": path_parts[1],
                    "path": relative_path,
                    "detection_method": "path_based"
                }
        
        # Strategy 3: Meta context (workspace development)
        if "scripts" in cwd or "docs" in cwd or cwd == workspace_dir:
            return {
                "name": "claude-workspace",
                "type": "meta",
                "path": ".",
                "meta_context": "workspace_development",
                "detection_method": "meta_detection"
            }
        
        return None
    except Exception as e:
        return None

def extract_intelligence_insights():
    """Extract and cache intelligence insights"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR', '/home/nullrunner/claude-workspace')
        intelligence_dir = os.path.join(workspace_dir, '.claude', 'intelligence')
        
        insights = {
            "recent_learnings": [],
            "recent_decisions": [],
            "current_focus": None,
            "extraction_timestamp": datetime.now().isoformat() + "Z"
        }
        
        # Load auto-learnings
        learnings_file = os.path.join(intelligence_dir, 'auto-learnings.json')
        if os.path.exists(learnings_file):
            learnings_data = safe_json_read(learnings_file, {})
            if learnings_data:
                recent_learnings = learnings_data.get('auto_learnings', [])[-5:]
                insights["recent_learnings"] = [
                    {
                        "title": learning.get("title"),
                        "lesson": learning.get("lesson"),
                        "category": learning.get("category"),
                        "severity": learning.get("severity"),
                        "timestamp": learning.get("timestamp")
                    }
                    for learning in recent_learnings
                ]
        
        # Load auto-decisions
        decisions_file = os.path.join(intelligence_dir, 'auto-decisions.json')
        if os.path.exists(decisions_file):
            decisions_data = safe_json_read(decisions_file, {})
            if decisions_data:
                recent_decisions = decisions_data.get('auto_decisions', [])[-8:]
                insights["recent_decisions"] = [
                    {
                        "title": decision.get("title"),
                        "category": decision.get("category"),
                        "impact": decision.get("impact"),
                        "source": decision.get("source"),
                        "timestamp": decision.get("timestamp")
                    }
                    for decision in recent_decisions
                ]
        
        # Determine current focus
        if insights["recent_decisions"]:
            categories = [d.get("category") for d in insights["recent_decisions"]]
            category_counts = {}
            for cat in categories:
                if cat:
                    category_counts[cat] = category_counts.get(cat, 0) + 1
            
            if category_counts:
                most_common = max(category_counts, key=category_counts.get)
                insights["current_focus"] = f"{most_common}_focused_development"
        
        # Cache insights
        intelligence_cache_file = os.environ.get('INTELLIGENCE_CACHE')
        safe_json_write(intelligence_cache_file, insights, indent=2)
        
        return insights
    except Exception as e:
        return {}

def generate_next_actions():
    """Generate intelligent next actions"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR', '/home/nullrunner/claude-workspace')
        next_actions = []
        
        # Analyze recent commits
        try:
            result = subprocess.run(['git', 'log', '--oneline', '-5'], 
                                  capture_output=True, text=True, cwd=workspace_dir)
            if result.returncode == 0:
                commits = result.stdout.strip().split('\n')
                
                has_fixes = any('fix' in commit.lower() or 'bug' in commit.lower() for commit in commits)
                has_features = any('feat' in commit.lower() or 'add' in commit.lower() for commit in commits)
                has_wip = any('wip' in commit.lower() or 'progress' in commit.lower() for commit in commits)
                
                if has_fixes:
                    next_actions.append("Verify recent fixes are working correctly")
                if has_features:
                    next_actions.append("Test new features and update documentation")
                if has_wip:
                    wip_commit = next((c for c in commits if 'wip' in c.lower()), "")
                    if wip_commit:
                        next_actions.append(f"Continue work on: {wip_commit.split(' ', 1)[1][:50]}")
        except:
            pass
        
        # Check git status for pending work
        git_status = get_git_status()
        if git_status['has_changes']:
            next_actions.append(f"Commit current changes ({git_status['dirty_files_count']} files modified)")
        
        # Project-specific actions
        current_project = get_current_project()
        if current_project:
            project_type = current_project.get("type")
            if project_type == "meta":
                next_actions.append("Test workspace script changes")
                next_actions.append("Update documentation if needed")
        
        return next_actions[:5]  # Limit to 5 actions
    except Exception as e:
        return []

def extract_todo_comments():
    """Extract TODO comments from project files"""
    try:
        workspace_dir = os.environ.get('WORKSPACE_DIR', '/home/nullrunner/claude-workspace')
        current_project = get_current_project()
        
        if not current_project:
            return []
        
        todos = []
        todo_patterns = ["TODO", "FIXME", "BUG", "HACK", "NOTE", "IMPORTANT"]
        
        # Determine search paths
        if current_project.get("type") == "meta":
            search_paths = [
                os.path.join(workspace_dir, "scripts"),
                os.path.join(workspace_dir, "docs")
            ]
        else:
            project_path = current_project.get("path", "")
            if project_path:
                full_path = os.path.join(workspace_dir, project_path)
                if os.path.exists(full_path):
                    search_paths = [full_path]
                else:
                    return []
            else:
                return []
        
        for search_path in search_paths:
            if not os.path.exists(search_path):
                continue
            
            for root, dirs, files in os.walk(search_path):
                # Skip hidden directories
                dirs[:] = [d for d in dirs if not d.startswith('.')]
                
                for file in files:
                    if file.endswith(('.sh', '.py', '.js', '.md', '.txt')):
                        file_path = os.path.join(root, file)
                        try:
                            with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                                lines = f.readlines()
                            
                            for i, line in enumerate(lines):
                                line = line.strip()
                                for pattern in todo_patterns:
                                    if pattern.lower() in line.lower():
                                        todo_text = line.replace('#', '').replace('//', '').strip()
                                        if len(todo_text) > 80:
                                            todo_text = todo_text[:80] + "..."
                                        
                                        relative_path = os.path.relpath(file_path, workspace_dir)
                                        
                                        todos.append({
                                            "text": todo_text,
                                            "file": relative_path,
                                            "line": i + 1,
                                            "type": pattern.lower()
                                        })
                                        break
                        except:
                            continue
        
        return todos[:5]  # Limit to 5 TODOs
    except Exception as e:
        return []

# Main unified context creation
def create_unified_context(save_type, caller, params_str):
    """Create unified context combining all systems"""
    timestamp = datetime.now().isoformat() + "Z"
    
    # Parse parameters based on save type
    params = {}
    if params_str:
        param_parts = params_str.split()
        if save_type == "simplified":
            if len(param_parts) > 0: params['reason'] = param_parts[0]
            if len(param_parts) > 1: params['summary'] = ' '.join(param_parts[1:2])
            if len(param_parts) > 2: params['issues'] = param_parts[2]
            if len(param_parts) > 3: params['actions'] = param_parts[3]
        elif save_type == "enhanced":
            if len(param_parts) > 0: params['note'] = param_parts[0]
            if len(param_parts) > 1: params['summary'] = ' '.join(param_parts[1:2])
            if len(param_parts) > 2: params['tasks'] = param_parts[2]
            if len(param_parts) > 3: params['next_steps'] = param_parts[3]
        elif save_type == "auto":
            params['note'] = params_str if params_str else "Auto-save coordinated"
    
    # Gather all context data
    git_status = get_git_status()
    current_project = get_current_project()
    intelligence_insights = extract_intelligence_insights()
    next_actions = generate_next_actions()
    todo_comments = extract_todo_comments()
    
    # Create unified context
    unified_context = {
        "context_version": "unified-v1",
        "timestamp": timestamp,
        "save_type": save_type,
        "caller": caller,
        "device": os.uname().nodename,
        "working_directory": os.getcwd(),
        
        # Core context data
        "current_project": current_project,
        "git_status": git_status,
        "intelligence_insights": intelligence_insights,
        
        # User-provided context
        "conversation_summary": params.get('summary') or params.get('note'),
        "session_note": params.get('note'),
        "save_reason": params.get('reason', 'manual'),
        
        # Intelligent extraction
        "open_issues": [
            f"{todo['type'].upper()}: {todo['text']} ({todo['file']}:{todo['line']})"
            for todo in todo_comments
        ] if todo_comments else [],
        "next_actions": next_actions,
        
        # Legacy compatibility
        "incomplete_tasks": params.get('tasks', '').split('|||') if params.get('tasks') else [],
        "next_steps": params.get('next_steps', '').split('|||') if params.get('next_steps') else []
    }
    
    return unified_context

# Execute the unified save
save_type = os.environ.get('SAVE_TYPE', 'auto')
caller = os.environ.get('CALLER', 'unknown')
params_str = os.environ.get('PARAMS', '')

try:
    # Create unified context
    context = create_unified_context(save_type, caller, params_str)
    
    # Save unified context
    unified_context_file = os.environ.get('UNIFIED_CONTEXT')
    safe_json_write(unified_context_file, context, indent=2)
    
    # Update session history
    session_history_file = os.environ.get('SESSION_HISTORY')
    session_history = safe_json_read(session_history_file, {"sessions": [], "version": "unified-v1"})
    
    # Add to session history
    session_entry = {
        "id": f"{context['timestamp']}-{context['caller']}",
        "timestamp": context['timestamp'],
        "save_type": context['save_type'],
        "caller": context['caller'],
        "project": context['current_project'],
        "summary": context['conversation_summary'],
        "changes_count": context['git_status']['dirty_files_count']
    }
    
    session_history["sessions"].insert(0, session_entry)
    session_history["sessions"] = session_history["sessions"][:100]  # Keep last 100 sessions
    session_history["last_update"] = context['timestamp']
    
    safe_json_write(session_history_file, session_history, indent=2)
    
    print(f"✅ Unified context saved successfully")
    print(f"📁 Project: {context['current_project']['name'] if context['current_project'] else 'None'}")
    print(f"🌿 Branch: {context['git_status']['branch']}")
    print(f"📝 Changes: {context['git_status']['dirty_files_count']} files")
    print(f"💡 Type: {save_type} from {caller}")
    
except Exception as e:
    print(f"❌ Error in unified context save: {e}")
    sys.exit(1)

EOF
    
    local result=$?
    if [[ $result -eq 0 ]]; then
        update_health_status "context_save" "healthy" "Successful $save_type save"
        coord_log "SUCCESS" "Unified context save completed: $save_type from $caller"
    else
        update_health_status "context_save" "error" "Failed $save_type save"
        coord_log "ERROR" "Unified context save failed: $save_type from $caller"
    fi
    
    return $result
}

# Unified context load
unified_context_load() {
    coord_log "LOAD" "Loading unified context"
    
    if [[ ! -f "$UNIFIED_CONTEXT" ]]; then
        echo -e "${YELLOW}⚠️  No unified context found${NC}"
        return 1
    fi
    
    export UNIFIED_CONTEXT WORKSPACE_DIR
    
    python3 << 'EOF'
import json
import sys
import os
from datetime import datetime

# Import safe JSON operations
sys.path.insert(0, os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts"))
from safe_json_operations import safe_json_read, SafeJSONError

try:
    context = safe_json_read(os.environ.get('UNIFIED_CONTEXT', '/home/nullrunner/claude-workspace/.claude/memory/unified-context.json'))
    if not context:
        raise SafeJSONError("Context file is empty")
    
    print(f"📅 Last session: {context.get('timestamp', 'Unknown')[:19].replace('T', ' ')}")
    print(f"💻 Device: {context.get('device', 'Unknown')}")
    print(f"🎯 Type: {context.get('save_type', 'unknown')} from {context.get('caller', 'unknown')}")
    
    if context.get('current_project'):
        proj = context['current_project']
        print(f"📁 Project: {proj.get('name', 'Unknown')} ({proj.get('type', 'unknown')})")
    
    git_status = context.get('git_status', {})
    print(f"🌿 Branch: {git_status.get('branch', 'unknown')}")
    
    if git_status.get('has_changes'):
        print(f"📝 Uncommitted changes: {git_status.get('dirty_files_count', 0)} files")
    else:
        print("✅ Working directory clean")
    
    if context.get('conversation_summary'):
        print(f"💬 Summary: {context['conversation_summary']}")
    
    if context.get('open_issues'):
        print("🚨 Open issues:")
        for issue in context['open_issues'][:3]:
            print(f"   • {issue}")
    
    if context.get('next_actions'):
        print("🎯 Next actions:")
        for action in context['next_actions'][:3]:
            print(f"   • {action}")
    
    # Intelligence insights summary
    insights = context.get('intelligence_insights', {})
    if insights.get('current_focus'):
        focus = insights['current_focus'].replace('_', ' ').title()
        print(f"🧠 Current focus: {focus}")
    
except Exception as e:
    print(f"❌ Error loading unified context: {e}")
    sys.exit(1)
EOF
}

# Main command handling
case "${1:-}" in
    "request-save")
        if [[ $# -lt 3 ]]; then
            echo "Usage: request-save <type> <caller> [priority] [params...]"
            exit 1
        fi
        save_type="$2"
        caller="$3"
        priority="${4:-normal}"
        shift 4
        
        # Execute unified save directly
        export SAVE_TYPE="$save_type" CALLER="$caller" PARAMS="$*"
        if acquire_lock "$caller"; then
            unified_context_save "$save_type" "$caller" "$priority" "$@"
            release_lock "$caller"
        else
            echo "Could not acquire lock for $save_type save"
            exit 1
        fi
        ;;
    "process")
        if acquire_lock "process-command"; then
            process_queue
            release_lock "process-command"
        else
            echo "Could not acquire lock for processing"
            exit 1
        fi
        ;;
    "status")
        show_status
        ;;
    "load")
        unified_context_load
        ;;
    "save")
        if [[ $# -lt 2 ]]; then
            echo "Usage: save <type> [params...]"
            exit 1
        fi
        save_type="$2"
        shift 2
        
        export SAVE_TYPE="$save_type" CALLER="claude-memory-coordinator" PARAMS="$*"
        if acquire_lock "manual-save"; then
            unified_context_save "$save_type" "manual-save" "normal" "$@"
            release_lock "manual-save"
        else
            echo "Could not acquire lock for manual save"
            exit 1
        fi
        ;;
    "acquire-lock")
        if [[ -z "$2" ]]; then
            echo "Usage: acquire-lock <caller>"
            exit 1
        fi
        acquire_lock "$2"
        ;;
    "release-lock")
        if [[ -z "$2" ]]; then
            echo "Usage: release-lock <caller>"
            exit 1
        fi
        release_lock "$2"
        ;;
    "clear-queue")
        init_queue
        echo '{"operations": [], "last_cleanup": null}' > "$OPERATION_QUEUE"
        echo "Queue cleared"
        ;;
    "logs")
        if [[ -f "$COORD_LOG" ]]; then
            tail -f "$COORD_LOG"
        else
            echo "No log file found"
        fi
        ;;
    "health")
        if [[ -f "$HEALTH_STATUS" ]]; then
            echo -e "${CYAN}🏥 Memory System Health${NC}"
            python3 << 'EOF'
import json
import sys
import os
from datetime import datetime

# Import safe JSON operations
sys.path.insert(0, os.path.join(os.environ.get("WORKSPACE_DIR", "/home/nullrunner/claude-workspace"), "scripts"))
from safe_json_operations import safe_json_read

try:
    health_data = safe_json_read(os.environ.get('HEALTH_STATUS', '/home/nullrunner/claude-workspace/.claude/memory-coordination/health-status.json'), {})
    
    system_status = health_data.get('system_status', 'unknown')
    status_color = {
        'healthy': '\033[0;32m',
        'warning': '\033[1;33m', 
        'error': '\033[0;31m',
        'unknown': '\033[0;37m'
    }.get(system_status, '\033[0;37m')
    
    print(f"Overall Status: {status_color}{system_status.upper()}\033[0m")
    print(f"Last Update: {health_data.get('last_update', 'Never')[:19].replace('T', ' ')}")
    print()
    
    components = health_data.get('components', {})
    if components:
        print("Component Status:")
        for component, info in components.items():
            comp_status = info.get('status', 'unknown')
            comp_color = {
                'healthy': '\033[0;32m',
                'active': '\033[0;34m',
                'warning': '\033[1;33m',
                'error': '\033[0;31m'
            }.get(comp_status, '\033[0;37m')
            
            print(f"  {component}: {comp_color}{comp_status}\033[0m - {info.get('message', 'No message')}")
    
    issues = health_data.get('issues', [])
    if issues:
        print("\nActive Issues:")
        for issue in issues[-5:]:
            print(f"  ⚠️  {issue}")
except Exception as e:
    print(f"Error reading health status: {e}")
EOF
        else
            echo "No health status file found"
        fi
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_status
        ;;
    "test")
        echo -e "${BLUE}🧪 Testing Unified Memory System${NC}"
        
        # Test lock acquisition
        if acquire_lock "test"; then
            echo -e "${GREEN}✅ Lock system working${NC}"
            release_lock "test"
        else
            echo -e "${RED}❌ Lock system failed${NC}"
        fi
        
        # Test safe JSON operations
        if python3 -c "import sys; sys.path.insert(0, '$WORKSPACE_DIR/scripts'); from safe_json_operations import test_safe_json_operations; test_safe_json_operations()" 2>/dev/null; then
            echo -e "${GREEN}✅ Safe JSON operations working${NC}"
        else
            echo -e "${RED}❌ Safe JSON operations failed${NC}"
        fi
        
        # Test unified context save/load
        export SAVE_TYPE="test" CALLER="test-script" PARAMS="test-reason test-summary"
        if unified_context_save "test" "test-script" "normal" "test-reason" "test-summary" >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Unified context save working${NC}"
        else
            echo -e "${RED}❌ Unified context save failed${NC}"
        fi
        
        if unified_context_load >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Unified context load working${NC}"
        else
            echo -e "${RED}❌ Unified context load failed${NC}"
        fi
        
        echo -e "${BLUE}🧪 Test completed${NC}"
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac