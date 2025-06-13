#!/bin/bash
# Claude Workspace - Shared Sync Lock Mechanism
# Provides consistent locking for all sync scripts to prevent conflicts

WORKSPACE_DIR="$HOME/claude-workspace"
SYNC_STATE_DIR="$WORKSPACE_DIR/.claude/sync"
LOCK_FILE="$SYNC_STATE_DIR/sync.lock"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Ensure sync directory exists
mkdir -p "$SYNC_STATE_DIR"

# Acquire exclusive lock with timeout
acquire_sync_lock() {
    local timeout=${1:-30}
    local caller=${2:-"unknown"}
    local count=0
    
    while [[ -f "$LOCK_FILE" ]] && [[ $count -lt $timeout ]]; do
        # Check if the process holding the lock is still alive
        if ! kill -0 "$(cat "$LOCK_FILE" 2>/dev/null)" 2>/dev/null; then
            echo -e "${YELLOW}[SYNC-LOCK] Removing stale lock file${NC}" >&2
            rm -f "$LOCK_FILE"
            break
        fi
        sleep 1
        ((count++))
    done
    
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        echo -e "${RED}[SYNC-LOCK] Could not acquire sync lock after ${timeout}s${NC}" >&2
        echo -e "${RED}[SYNC-LOCK] Lock held by PID: $lock_pid (caller: $caller)${NC}" >&2
        return 1
    fi
    
    # Acquire lock
    echo $$ > "$LOCK_FILE"
    echo -e "${GREEN}[SYNC-LOCK] Lock acquired by $caller (PID: $$)${NC}" >&2
    return 0
}

# Release lock
release_sync_lock() {
    local caller=${1:-"unknown"}
    
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        
        # Only release if we own the lock
        if [[ "$lock_pid" == "$$" ]]; then
            rm -f "$LOCK_FILE"
            echo -e "${GREEN}[SYNC-LOCK] Lock released by $caller (PID: $$)${NC}" >&2
        else
            echo -e "${YELLOW}[SYNC-LOCK] Cannot release lock owned by PID: $lock_pid${NC}" >&2
        fi
    fi
}

# Check if sync is currently locked
is_sync_locked() {
    if [[ -f "$LOCK_FILE" ]]; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        if kill -0 "$lock_pid" 2>/dev/null; then
            return 0  # Locked
        else
            # Stale lock
            rm -f "$LOCK_FILE"
            return 1  # Not locked
        fi
    else
        return 1  # Not locked
    fi
}

# Show lock status
show_lock_status() {
    if is_sync_locked; then
        local lock_pid=$(cat "$LOCK_FILE" 2>/dev/null)
        echo -e "${RED}LOCKED${NC} (PID: $lock_pid)"
        return 0
    else
        echo -e "${GREEN}FREE${NC}"
        return 1
    fi
}

# Wait for lock to be released
wait_for_lock_release() {
    local timeout=${1:-60}
    local count=0
    
    while is_sync_locked && [[ $count -lt $timeout ]]; do
        sleep 1
        ((count++))
    done
    
    if is_sync_locked; then
        echo -e "${RED}[SYNC-LOCK] Timeout waiting for lock release${NC}" >&2
        return 1
    fi
    
    return 0
}

# Function to set up lock cleanup trap
setup_lock_cleanup() {
    local caller=${1:-"unknown"}
    trap "release_sync_lock '$caller'; exit" EXIT INT TERM
}

# Only execute CLI if not being sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]] || [[ "${1:-}" != "source-mode" ]]; then
    # Command line interface
    case "${1:-}" in
    "acquire")
        acquire_sync_lock "${2:-30}" "${3:-CLI}"
        ;;
    "release")
        release_sync_lock "${2:-CLI}"
        ;;
    "status")
        echo -n "Sync lock status: "
        show_lock_status
        ;;
    "wait")
        wait_for_lock_release "${2:-60}"
        ;;
    "test")
        echo "Testing sync lock mechanism..."
        if acquire_sync_lock 5 "test"; then
            echo -e "${GREEN}✓ Lock acquired successfully${NC}"
            sleep 2
            release_sync_lock "test"
            echo -e "${GREEN}✓ Lock released successfully${NC}"
        else
            echo -e "${RED}✗ Failed to acquire lock${NC}"
            exit 1
        fi
        ;;
    *)
        echo "Usage: $0 {acquire|release|status|wait|test}"
        echo
        echo "  acquire [timeout] [caller] - Acquire sync lock with timeout"
        echo "  release [caller]           - Release sync lock"
        echo "  status                     - Show lock status"
        echo "  wait [timeout]             - Wait for lock to be released"
        echo "  test                       - Test lock mechanism"
        echo
        echo "Note: This script is primarily intended to be sourced by other sync scripts."
        echo "Use 'source $0' to import locking functions into another script."
        exit 1
        ;;
esac