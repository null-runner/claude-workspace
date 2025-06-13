#!/bin/bash
# Claude Sync Coordinator - Unified coordination for all sync operations
# Prevents race conditions between intelligent-auto-sync, smart-sync, robust-sync, and sync-now
# Implements queue system and conflict resolution

WORKSPACE_DIR="$HOME/claude-workspace"
COORD_DIR="$WORKSPACE_DIR/.claude/sync-coordination"
SYNC_DIR="$WORKSPACE_DIR/.claude/sync"
COORD_LOCK="$COORD_DIR/sync-coordinator.lock"
OPERATION_QUEUE="$COORD_DIR/sync-queue.json"
COORD_LOG="$COORD_DIR/coordinator.log"
STATE_FILE="$COORD_DIR/coordinator-state.json"
CONFLICT_LOG="$COORD_DIR/conflicts.log"

# Timeout configurations
LOCK_TIMEOUT=60      # 60 seconds max lock time for sync operations
QUEUE_TIMEOUT=120    # 120 seconds max queue wait time
GIT_TIMEOUT=90       # 90 seconds for git operations
MAX_RETRIES=3        # Maximum retry attempts for failed operations

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Setup
mkdir -p "$COORD_DIR" "$SYNC_DIR"

# Logging function with levels and rotation
coord_log() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" >> "$COORD_LOG"
    
    # Rotate log if too large (keep last 500 lines)
    if [[ $(wc -l < "$COORD_LOG" 2>/dev/null || echo 0) -gt 1000 ]]; then
        tail -n 500 "$COORD_LOG" > "$COORD_LOG.tmp" && mv "$COORD_LOG.tmp" "$COORD_LOG"
    fi
    
    # Echo to stderr with colors for monitoring
    case "$level" in
        "SYNC") echo -e "${GREEN}[SYNC-COORD]${NC} $message" >&2 ;;
        "QUEUE") echo -e "${BLUE}[SYNC-QUEUE]${NC} $message" >&2 ;;
        "CONFLICT") echo -e "${MAGENTA}[SYNC-CONFLICT]${NC} $message" >&2 ;;
        "ERROR") echo -e "${RED}[SYNC-ERROR]${NC} $message" >&2 ;;
        "WARN") echo -e "${YELLOW}[SYNC-WARN]${NC} $message" >&2 ;;
        *) echo -e "${CYAN}[SYNC-INFO]${NC} $message" >&2 ;;
    esac
}

# Initialize coordinator state and queue
init_coordinator() {
    if [[ ! -f "$OPERATION_QUEUE" ]]; then
        cat > "$OPERATION_QUEUE" << 'EOF'
{
  "operations": [],
  "last_cleanup": null,
  "statistics": {
    "total_processed": 0,
    "successful": 0,
    "failed": 0,
    "conflicts_resolved": 0
  }
}
EOF
    fi
    
    if [[ ! -f "$STATE_FILE" ]]; then
        cat > "$STATE_FILE" << 'EOF'
{
  "active_sync_type": null,
  "last_sync_timestamp": null,
  "environment_state": {},
  "conflict_resolution_enabled": true,
  "rate_limiting": {
    "enabled": true,
    "max_syncs_per_hour": 12,
    "current_hour_count": 0,
    "hour_reset_time": null
  }
}
EOF
    fi
}

# Acquire coordination lock with stale lock detection
acquire_coord_lock() {
    local caller="$1"
    local timeout="${2:-$LOCK_TIMEOUT}"
    local max_attempts=$((timeout * 2))  # Check every 0.5 seconds
    local attempts=0
    
    while [[ $attempts -lt $max_attempts ]]; do
        if (set -C; echo "$caller:$$:$(date +%s)" > "$COORD_LOCK") 2>/dev/null; then
            coord_log "LOCK" "Coordination lock acquired by $caller (PID: $$)"
            return 0
        fi
        
        # Check if lock is stale (older than timeout + 30 seconds grace period)
        if [[ -f "$COORD_LOCK" ]]; then
            local lock_info=$(cat "$COORD_LOCK" 2>/dev/null || echo "")
            if [[ -n "$lock_info" ]]; then
                local lock_timestamp=$(echo "$lock_info" | cut -d: -f3)
                local lock_pid=$(echo "$lock_info" | cut -d: -f2)
                local current_time=$(date +%s)
                local lock_age=$((current_time - lock_timestamp))
                
                # Check if process is still alive
                if ! kill -0 "$lock_pid" 2>/dev/null || [[ $lock_age -gt $((timeout + 30)) ]]; then
                    coord_log "WARN" "Removing stale/dead lock from $lock_info (age: ${lock_age}s)"
                    rm -f "$COORD_LOCK"
                    continue
                fi
            fi
        fi
        
        attempts=$((attempts + 1))
        sleep 0.5
    done
    
    coord_log "ERROR" "Failed to acquire coordination lock after ${timeout}s (caller: $caller)"
    return 1
}

# Release coordination lock
release_coord_lock() {
    local caller="$1"
    
    if [[ -f "$COORD_LOCK" ]]; then
        local lock_info=$(cat "$COORD_LOCK" 2>/dev/null || echo "")
        local lock_caller=$(echo "$lock_info" | cut -d: -f1)
        local lock_pid=$(echo "$lock_info" | cut -d: -f2)
        
        # Only release if we own the lock
        if [[ "$lock_caller" == "$caller" && "$lock_pid" == "$$" ]]; then
            rm -f "$COORD_LOCK"
            coord_log "LOCK" "Coordination lock released by $caller (PID: $$)"
            return 0
        else
            coord_log "WARN" "Lock not owned by $caller:$$ (current: $lock_info)"
            return 1
        fi
    else
        coord_log "WARN" "No coordination lock file found for release by $caller"
        return 1
    fi
}

# Cleanup function
cleanup_on_exit() {
    local caller="${1:-${BASH_SOURCE[1]##*/}}"
    release_coord_lock "$caller"
}

# Environment state management to prevent conflicts
save_env_state() {
    local sync_type="$1"
    
    python3 << EOF
import json
import os
from datetime import datetime

try:
    with open("$STATE_FILE", "r") as f:
        state = json.load(f)
    
    # Save current environment variables that affect sync
    env_state = {
        "CLAUDE_SYNC_ACTIVE": os.environ.get("CLAUDE_SYNC_ACTIVE"),
        "AUTOMATED_SYNC": os.environ.get("AUTOMATED_SYNC"),
        "MEMORY_COORD_MODE": os.environ.get("MEMORY_COORD_MODE"),
        "GIT_SSH_COMMAND": os.environ.get("GIT_SSH_COMMAND")
    }
    
    state["active_sync_type"] = "$sync_type"
    state["environment_state"] = env_state
    state["last_sync_timestamp"] = datetime.now().isoformat() + "Z"
    
    with open("$STATE_FILE", "w") as f:
        json.dump(state, f, indent=2)
    
    print("Environment state saved for $sync_type")
        
except Exception as e:
    print(f"Error saving environment state: {e}")
EOF
}

# Restore environment state after sync
restore_env_state() {
    python3 << EOF
import json
import os

try:
    with open("$STATE_FILE", "r") as f:
        state = json.load(f)
    
    # Clear active sync state
    state["active_sync_type"] = None
    
    # We don't restore environment variables as they should be managed
    # by individual sync scripts, but we clear our tracking
    state["environment_state"] = {}
    
    with open("$STATE_FILE", "w") as f:
        json.dump(state, f, indent=2)
    
    print("Environment state cleared")
        
except Exception as e:
    print(f"Error restoring environment state: {e}")
EOF
}

# Rate limiting check with hourly reset
check_rate_limit() {
    python3 << EOF
import json
from datetime import datetime, timedelta

try:
    with open("$STATE_FILE", "r") as f:
        state = json.load(f)
    
    rate_config = state.get("rate_limiting", {})
    if not rate_config.get("enabled", True):
        print("ALLOW: Rate limiting disabled")
        exit(0)
    
    max_syncs = rate_config.get("max_syncs_per_hour", 12)
    current_count = rate_config.get("current_hour_count", 0)
    reset_time_str = rate_config.get("hour_reset_time")
    
    now = datetime.now()
    
    # Check if we need to reset the hourly counter
    if reset_time_str:
        reset_time = datetime.fromisoformat(reset_time_str.replace('Z', ''))
        if now >= reset_time:
            current_count = 0
            rate_config["current_hour_count"] = 0
            rate_config["hour_reset_time"] = (now + timedelta(hours=1)).isoformat() + "Z"
    else:
        # First time setup
        rate_config["hour_reset_time"] = (now + timedelta(hours=1)).isoformat() + "Z"
        current_count = 0
    
    if current_count >= max_syncs:
        print(f"DENY: Rate limit exceeded ({current_count}/{max_syncs} syncs this hour)")
        exit(1)
    
    # Increment counter
    rate_config["current_hour_count"] = current_count + 1
    
    # Save updated state
    with open("$STATE_FILE", "w") as f:
        json.dump(state, f, indent=2)
    
    print(f"ALLOW: {current_count + 1}/{max_syncs} syncs this hour")
    
except Exception as e:
    print(f"Error checking rate limit: {e}")
    exit(1)
EOF
}

# Git conflict resolution with automatic merge strategies
resolve_git_conflicts() {
    local operation="$1"  # pull or push
    local retry_count="${2:-0}"
    
    coord_log "CONFLICT" "Attempting to resolve git conflicts for $operation (attempt $((retry_count + 1)))"
    
    cd "$WORKSPACE_DIR" || return 1
    
    case "$operation" in
        "pull")
            # For pull conflicts, try different merge strategies
            if [[ $retry_count -eq 0 ]]; then
                # First attempt: try ours for system files, theirs for user files
                coord_log "CONFLICT" "Trying selective merge strategy"
                
                # Reset to clean state
                git reset --hard HEAD
                
                # Try pull with strategy
                if timeout $GIT_TIMEOUT git pull --no-edit --strategy-option=ours origin main; then
                    coord_log "CONFLICT" "Selective merge successful"
                    return 0
                fi
            elif [[ $retry_count -eq 1 ]]; then
                # Second attempt: fetch and manually merge
                coord_log "CONFLICT" "Trying manual fetch and merge"
                
                if timeout $GIT_TIMEOUT git fetch origin main; then
                    # Check what conflicts we'd have
                    local conflicts=$(git merge-tree $(git merge-base HEAD origin/main) HEAD origin/main | grep -c "<<<<<<< " || echo "0")
                    
                    if [[ $conflicts -eq 0 ]]; then
                        # Safe to merge
                        git merge origin/main --no-edit
                        return 0
                    else
                        coord_log "CONFLICT" "Found $conflicts conflicts, attempting auto-resolution"
                        
                        # Try merge with conflict resolution
                        git merge origin/main --no-edit || true
                        
                        # Auto-resolve conflicts in system files by preferring remote
                        git checkout --theirs .claude/memory/*.json 2>/dev/null || true
                        git checkout --theirs .claude/intelligence/*.json 2>/dev/null || true
                        git checkout --theirs .claude/autonomous/*.json 2>/dev/null || true
                        
                        # Auto-resolve conflicts in logs by preferring local
                        git checkout --ours logs/*.log 2>/dev/null || true
                        
                        # Add resolved files
                        git add -A
                        
                        # Complete merge if no remaining conflicts
                        if ! git status --porcelain | grep -q "^UU\|^AA\|^DD"; then
                            git commit --no-edit -m "Auto-resolved merge conflicts (coordinator)"
                            coord_log "CONFLICT" "Auto-resolution successful"
                            return 0
                        fi
                    fi
                fi
            fi
            ;;
        "push")
            # For push conflicts, first pull then retry push
            coord_log "CONFLICT" "Push conflict detected, attempting pull first"
            
            if resolve_git_conflicts "pull" $retry_count; then
                coord_log "CONFLICT" "Pull resolved, retrying push"
                if timeout $GIT_TIMEOUT git push origin main; then
                    coord_log "CONFLICT" "Push successful after pull"
                    return 0
                fi
            fi
            ;;
    esac
    
    echo "$operation conflict at $(date)" >> "$CONFLICT_LOG"
    coord_log "CONFLICT" "Failed to resolve $operation conflicts"
    return 1
}

# Execute git operation with retry and conflict resolution
git_operation_with_coordination() {
    local operation="$1"  # pull, push, commit
    local retry_count="${2:-0}"
    
    if [[ $retry_count -ge $MAX_RETRIES ]]; then
        coord_log "ERROR" "Max retries exceeded for git $operation"
        return 1
    fi
    
    cd "$WORKSPACE_DIR" || return 1
    
    case "$operation" in
        "pull")
            coord_log "SYNC" "Executing coordinated git pull (attempt $((retry_count + 1)))"
            
            if timeout $GIT_TIMEOUT git pull origin main --no-edit --no-rebase; then
                coord_log "SYNC" "Git pull successful"
                return 0
            else
                local exit_code=$?
                if [[ $exit_code -eq 1 ]]; then
                    # Merge conflict
                    if resolve_git_conflicts "pull" $retry_count; then
                        return 0
                    fi
                fi
                
                coord_log "WARN" "Git pull failed (attempt $((retry_count + 1))), retrying..."
                sleep $((retry_count + 1))
                return $(git_operation_with_coordination "pull" $((retry_count + 1)))
            fi
            ;;
        "push")
            coord_log "SYNC" "Executing coordinated git push (attempt $((retry_count + 1)))"
            
            if timeout $GIT_TIMEOUT git push origin main; then
                coord_log "SYNC" "Git push successful"
                return 0
            else
                local exit_code=$?
                if [[ $exit_code -eq 1 ]]; then
                    # Push conflict (probably need to pull first)
                    if resolve_git_conflicts "push" $retry_count; then
                        return 0
                    fi
                fi
                
                coord_log "WARN" "Git push failed (attempt $((retry_count + 1))), retrying..."
                sleep $((retry_count + 1))
                return $(git_operation_with_coordination "push" $((retry_count + 1)))
            fi
            ;;
        "commit")
            local commit_msg="$3"
            coord_log "SYNC" "Executing coordinated git commit"
            
            # Set environment to prevent hooks from interfering
            export CLAUDE_SYNC_ACTIVE=1
            
            if git commit -m "$commit_msg"; then
                coord_log "SYNC" "Git commit successful"
                unset CLAUDE_SYNC_ACTIVE
                return 0
            else
                coord_log "ERROR" "Git commit failed"
                unset CLAUDE_SYNC_ACTIVE
                return 1
            fi
            ;;
    esac
}

# Queue sync operation
queue_sync_operation() {
    local sync_type="$1"
    local caller="$2"
    local priority="${3:-normal}"
    local reason="${4:-Queued sync operation}"
    local files_info="${5:-}"
    
    init_coordinator
    
    coord_log "QUEUE" "Queueing $sync_type operation from $caller (priority: $priority)"
    
    python3 << EOF
import json
import sys
from datetime import datetime

try:
    # Load current queue
    with open("$OPERATION_QUEUE", "r") as f:
        queue_data = json.load(f)
    
    # Create new operation
    timestamp = datetime.now().isoformat() + "Z"
    new_operation = {
        "id": f"{timestamp}-{caller}",
        "operation": "$sync_type",
        "caller": "$caller",
        "priority": "$priority",
        "reason": "$reason",
        "files_info": "$files_info",
        "timestamp": timestamp,
        "status": "pending",
        "retry_count": 0
    }
    
    queue_data["operations"].append(new_operation)
    
    # Sort by priority (high first) and timestamp
    priority_order = {"high": 0, "normal": 1, "low": 2}
    queue_data["operations"].sort(
        key=lambda x: (priority_order.get(x["priority"], 1), x["timestamp"])
    )
    
    # Keep only last 100 operations (cleanup old ones)
    queue_data["operations"] = queue_data["operations"][-100:]
    
    # Save updated queue
    with open("$OPERATION_QUEUE", "w") as f:
        json.dump(queue_data, f, indent=2)
    
    print(f"✅ Operation queued: {new_operation['id']}")
    
except Exception as e:
    print(f"❌ Failed to queue operation: {e}")
    sys.exit(1)
EOF
}

# Execute specific sync operation
execute_sync_operation() {
    local operation_data="$1"
    
    coord_log "SYNC" "Executing sync operation: $operation_data"
    
    WORKSPACE_DIR="$WORKSPACE_DIR" python3 << 'EOF'
import json
import subprocess
import os
import sys
from datetime import datetime

operation = json.loads(os.environ.get("OPERATION_DATA", "{}"))
sync_type = operation.get("operation", "")
caller = operation.get("caller", "")
reason = operation.get("reason", "")
files_info = operation.get("files_info", "")

def execute_intelligent_auto_sync():
    """Execute intelligent auto sync operation"""
    try:
        script_path = os.path.join(os.environ["WORKSPACE_DIR"], "scripts", "claude-intelligent-auto-sync.sh")
        # Don't run in monitor mode, just trigger a sync
        result = subprocess.run([script_path, "test"], capture_output=True, text=True, timeout=120)
        return result.returncode == 0
    except Exception as e:
        print(f"Error in intelligent auto sync: {e}")
        return False

def execute_smart_sync():
    """Execute smart sync operation"""
    try:
        script_path = os.path.join(os.environ["WORKSPACE_DIR"], "scripts", "claude-smart-sync.sh")
        result = subprocess.run([script_path, "sync", reason], capture_output=True, text=True, timeout=120)
        return result.returncode == 0
    except Exception as e:
        print(f"Error in smart sync: {e}")
        return False

def execute_robust_sync():
    """Execute robust sync operation"""
    try:
        script_path = os.path.join(os.environ["WORKSPACE_DIR"], "scripts", "claude-robust-sync.sh")
        result = subprocess.run([script_path, "sync"], capture_output=True, text=True, timeout=120)
        return result.returncode == 0
    except Exception as e:
        print(f"Error in robust sync: {e}")
        return False

def execute_manual_sync():
    """Execute manual sync operation (like sync-now but automated)"""
    try:
        # This implements the core logic of sync-now.sh but without user interaction
        os.chdir(os.environ["WORKSPACE_DIR"])
        
        # Pull first
        pull_result = subprocess.run(["git", "pull", "origin", "main", "--no-edit"], 
                                   capture_output=True, text=True, timeout=90)
        if pull_result.returncode != 0:
            print(f"Pull failed: {pull_result.stderr}")
            return False
        
        # Check for changes
        status_result = subprocess.run(["git", "status", "--porcelain"], 
                                     capture_output=True, text=True)
        if not status_result.stdout.strip():
            print("No changes to sync")
            return True
        
        # Add and commit changes
        subprocess.run(["git", "add", "-A"], check=True)
        
        commit_msg = f"Coordinated sync: {reason}" if reason else f"Coordinated sync from {caller}"
        
        # Set environment variable to prevent hook interference
        env = os.environ.copy()
        env["CLAUDE_SYNC_ACTIVE"] = "1"
        
        commit_result = subprocess.run(["git", "commit", "-m", commit_msg], 
                                     capture_output=True, text=True, env=env)
        if commit_result.returncode != 0:
            print(f"Commit failed: {commit_result.stderr}")
            return False
        
        # Push changes
        push_result = subprocess.run(["git", "push", "origin", "main"], 
                                   capture_output=True, text=True, timeout=90)
        if push_result.returncode != 0:
            print(f"Push failed: {push_result.stderr}")
            return False
        
        print("Manual sync completed successfully")
        return True
        
    except Exception as e:
        print(f"Error in manual sync: {e}")
        return False

# Execute based on sync type
success = False
if sync_type == "intelligent-auto":
    success = execute_intelligent_auto_sync()
elif sync_type == "smart":
    success = execute_smart_sync()
elif sync_type == "robust":
    success = execute_robust_sync()
elif sync_type == "manual":
    success = execute_manual_sync()
else:
    print(f"Unknown sync type: {sync_type}")

print(f"RESULT: {'SUCCESS' if success else 'FAILED'}")
sys.exit(0 if success else 1)
EOF
}

# Process operation queue
process_sync_queue() {
    init_coordinator
    
    coord_log "QUEUE" "Processing sync operation queue"
    
    python3 << 'EOF'
import json
import subprocess
import sys
import os
from datetime import datetime, timedelta

def process_operations():
    try:
        with open(os.environ["OPERATION_QUEUE"], "r") as f:
            queue_data = json.load(f)
        
        pending_ops = [op for op in queue_data["operations"] if op["status"] == "pending"]
        
        if not pending_ops:
            print("No pending sync operations")
            return
        
        processed_count = 0
        successful_count = 0
        
        for operation in pending_ops[:3]:  # Process max 3 at once to prevent overload
            op_id = operation["id"]
            op_type = operation["operation"]
            caller = operation["caller"]
            
            print(f"Processing: {op_id} ({op_type} from {caller})")
            
            # Mark as processing
            operation["status"] = "processing"
            operation["processed_at"] = datetime.now().isoformat() + "Z"
            
            # Save intermediate state
            with open(os.environ["OPERATION_QUEUE"], "w") as f:
                json.dump(queue_data, f, indent=2)
            
            # Execute operation
            success = False
            try:
                # Set operation data for the execution subprocess
                env = os.environ.copy()
                env["OPERATION_DATA"] = json.dumps(operation)
                
                # Execute the sync operation through our coordinator
                result = subprocess.run([
                    os.path.join(os.environ["WORKSPACE_DIR"], "scripts", "claude-sync-coordinator.sh"),
                    "execute-operation"
                ], capture_output=True, text=True, env=env, timeout=180)
                
                success = result.returncode == 0
                
                if not success:
                    print(f"Operation failed: {result.stderr}")
                
            except subprocess.TimeoutExpired:
                print(f"Operation {op_id} timed out")
                success = False
            except Exception as e:
                print(f"Error executing operation: {e}")
                success = False
            
            # Update operation status
            operation["status"] = "completed" if success else "failed"
            operation["completed_at"] = datetime.now().isoformat() + "Z"
            
            if not success:
                operation["retry_count"] = operation.get("retry_count", 0) + 1
                # Re-queue if under retry limit
                if operation["retry_count"] < 3:
                    operation["status"] = "pending"
                    print(f"Re-queuing operation (retry {operation['retry_count']}/3)")
            
            processed_count += 1
            if success:
                successful_count += 1
        
        # Update statistics
        stats = queue_data.get("statistics", {})
        stats["total_processed"] = stats.get("total_processed", 0) + processed_count
        stats["successful"] = stats.get("successful", 0) + successful_count
        stats["failed"] = stats.get("failed", 0) + (processed_count - successful_count)
        
        # Clean up old operations (older than 48 hours)
        cutoff_time = datetime.now() - timedelta(hours=48)
        queue_data["operations"] = [
            op for op in queue_data["operations"]
            if datetime.fromisoformat(op["timestamp"].replace('Z', '')) > cutoff_time
        ]
        
        queue_data["last_cleanup"] = datetime.now().isoformat() + "Z"
        queue_data["statistics"] = stats
        
        # Save final state
        with open(os.environ["OPERATION_QUEUE"], "w") as f:
            json.dump(queue_data, f, indent=2)
        
        print(f"Processed {processed_count} operations ({successful_count} successful)")
        
    except Exception as e:
        print(f"Error processing queue: {e}")

process_operations()
EOF
}

# Public API: Request coordinated sync
request_sync() {
    local sync_type="$1"    # intelligent-auto, smart, robust, manual
    local caller="$2"       # Script requesting sync
    local priority="${3:-normal}"  # high, normal, low
    local reason="${4:-Coordinated sync request}"
    local files_info="${5:-}"
    
    init_coordinator
    
    coord_log "API" "Sync request: $sync_type from $caller (priority: $priority)"
    
    # Check rate limiting
    local rate_check=$(check_rate_limit)
    if echo "$rate_check" | grep -q "DENY:"; then
        coord_log "WARN" "Sync request denied due to rate limiting: $rate_check"
        echo "❌ $rate_check"
        return 1
    fi
    
    coord_log "INFO" "Rate limit check: $rate_check"
    
    # Try to acquire lock for immediate execution
    if acquire_coord_lock "$caller" 5; then
        coord_log "EXEC" "Executing $sync_type sync immediately"
        
        # Set up cleanup trap
        trap "cleanup_on_exit '$caller'" EXIT INT TERM
        
        # Save environment state
        save_env_state "$sync_type"
        
        # Create operation data for immediate execution
        local operation_data=$(cat << EOF
{
    "operation": "$sync_type",
    "caller": "$caller",
    "priority": "$priority",
    "reason": "$reason",
    "files_info": "$files_info",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "status": "executing"
}
EOF
)
        
        # Execute immediately
        local success=false
        OPERATION_DATA="$operation_data" execute_sync_operation "$operation_data"
        local result=$?
        
        if [[ $result -eq 0 ]]; then
            coord_log "SYNC" "$sync_type sync completed successfully"
            success=true
            echo "✅ Sync completed successfully"
        else
            coord_log "ERROR" "$sync_type sync failed"
            echo "❌ Sync failed"
        fi
        
        # Restore environment state
        restore_env_state
        
        # Release lock
        release_coord_lock "$caller"
        
        return $result
    else
        coord_log "QUEUE" "Lock unavailable, queueing $sync_type sync from $caller"
        
        # Queue the operation
        queue_sync_operation "$sync_type" "$caller" "$priority" "$reason" "$files_info"
        
        echo "⏳ Sync queued. Use 'claude-sync-coordinator process' to execute queued operations."
        return 0
    fi
}

# Status display
show_status() {
    init_coordinator
    
    echo -e "${CYAN}🔄 Sync Coordinator Status${NC}"
    echo ""
    
    # Lock status
    if [[ -f "$COORD_LOCK" ]]; then
        local lock_info=$(cat "$COORD_LOCK")
        echo -e "${YELLOW}🔒 Coordinator Lock: ACTIVE${NC}"
        echo "   Lock info: $lock_info"
    else
        echo -e "${GREEN}🔓 Coordinator Lock: FREE${NC}"
    fi
    
    echo ""
    
    # Rate limiting status
    local rate_status=$(check_rate_limit 2>&1 || echo "Rate limit check failed")
    echo -e "${BLUE}⏱️  Rate Limiting:${NC}"
    echo "   $rate_status"
    
    echo ""
    echo -e "${BLUE}📋 Operation Queue:${NC}"
    
    OPERATION_QUEUE="$OPERATION_QUEUE" python3 << 'EOF'
import json
import os
from datetime import datetime

try:
    with open(os.environ["OPERATION_QUEUE"], "r") as f:
        queue_data = json.load(f)
    
    operations = queue_data.get("operations", [])
    stats = queue_data.get("statistics", {})
    
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
        print(f"   Completed: {len(completed)} (last 48h)")
        print(f"   Failed: {len(failed)}")
        
        if pending:
            print("\n   Next pending operations:")
            for op in pending[:3]:
                timestamp = op["timestamp"][:19].replace('T', ' ')
                priority = f"[{op['priority'].upper()}]" if op['priority'] != 'normal' else ''
                print(f"     • {op['operation']} from {op['caller']} {priority} ({timestamp})")
    
    # Statistics
    if stats:
        print(f"\n   Statistics:")
        print(f"     Total processed: {stats.get('total_processed', 0)}")
        print(f"     Success rate: {stats.get('successful', 0)}/{stats.get('total_processed', 0)}")
        print(f"     Conflicts resolved: {stats.get('conflicts_resolved', 0)}")
    
    last_cleanup = queue_data.get("last_cleanup")
    if last_cleanup:
        print(f"\n   Last cleanup: {last_cleanup[:19].replace('T', ' ')}")
    
except Exception as e:
    print(f"   Error reading queue: {e}")
EOF

    # Show active sync type
    echo ""
    echo -e "${BLUE}🎯 Current State:${NC}"
    STATE_FILE="$STATE_FILE" python3 << 'EOF'
import json
import os

try:
    with open(os.environ["STATE_FILE"], "r") as f:
        state = json.load(f)
    
    active_sync = state.get("active_sync_type")
    if active_sync:
        print(f"   Active sync type: {active_sync}")
    else:
        print("   No active sync operation")
    
    last_sync = state.get("last_sync_timestamp")
    if last_sync:
        print(f"   Last sync: {last_sync[:19].replace('T', ' ')}")
    
except Exception as e:
    print(f"   Error reading state: {e}")
EOF
}

# Help
show_help() {
    echo "Claude Sync Coordinator - Unified Sync System"
    echo ""
    echo "Usage: claude-sync-coordinator [command] [options]"
    echo ""
    echo "Commands:"
    echo "  request-sync <type> <caller> [priority] [reason] [files_info]"
    echo "    type: intelligent-auto, smart, robust, manual"
    echo "    caller: script name requesting sync"
    echo "    priority: high, normal, low"
    echo "    reason: description of why sync is needed"
    echo "    files_info: information about files being synced"
    echo ""
    echo "  process        Process queued sync operations"
    echo "  status         Show coordinator status"
    echo "  clear-queue    Clear operation queue"
    echo "  logs           Show coordinator logs"
    echo "  conflicts      Show conflict resolution log"
    echo ""
    echo "Internal Commands:"
    echo "  acquire-lock <caller>        Acquire coordination lock"
    echo "  release-lock <caller>        Release coordination lock"
    echo "  execute-operation            Execute operation from queue (internal)"
    echo ""
    echo "Examples:"
    echo "  claude-sync-coordinator request-sync smart claude-startup normal 'Startup sync'"
    echo "  claude-sync-coordinator request-sync manual sync-now high 'Manual user sync'"
    echo "  claude-sync-coordinator process"
    echo "  claude-sync-coordinator status"
}

# Main command handling
case "${1:-}" in
    "request-sync")
        if [[ $# -lt 3 ]]; then
            echo "Usage: request-sync <type> <caller> [priority] [reason] [files_info]"
            exit 1
        fi
        sync_type="$2"
        caller="$3"
        priority="${4:-normal}"
        reason="${5:-Sync request}"
        files_info="${6:-}"
        request_sync "$sync_type" "$caller" "$priority" "$reason" "$files_info"
        ;;
    "process")
        if acquire_coord_lock "process-command" 30; then
            trap "cleanup_on_exit 'process-command'" EXIT INT TERM
            process_sync_queue
            release_coord_lock "process-command"
        else
            echo "Could not acquire lock for processing"
            exit 1
        fi
        ;;
    "status")
        show_status
        ;;
    "acquire-lock")
        if [[ -z "$2" ]]; then
            echo "Usage: acquire-lock <caller>"
            exit 1
        fi
        acquire_coord_lock "$2"
        ;;
    "release-lock")
        if [[ -z "$2" ]]; then
            echo "Usage: release-lock <caller>"
            exit 1
        fi
        release_coord_lock "$2"
        ;;
    "execute-operation")
        # Internal command used by process queue
        operation_data="${OPERATION_DATA:-{}}"
        execute_sync_operation "$operation_data"
        ;;
    "clear-queue")
        init_coordinator
        echo '{"operations": [], "last_cleanup": null, "statistics": {"total_processed": 0, "successful": 0, "failed": 0, "conflicts_resolved": 0}}' > "$OPERATION_QUEUE"
        echo "Queue cleared"
        ;;
    "logs")
        if [[ -f "$COORD_LOG" ]]; then
            tail -f "$COORD_LOG"
        else
            echo "No coordinator log file found"
        fi
        ;;
    "conflicts")
        if [[ -f "$CONFLICT_LOG" ]]; then
            echo "Recent conflict resolutions:"
            tail -20 "$CONFLICT_LOG"
        else
            echo "No conflicts logged"
        fi
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_status
        ;;
    *)
        echo "Unknown command: $1"
        show_help
        exit 1
        ;;
esac