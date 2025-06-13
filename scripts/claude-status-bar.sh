#!/bin/bash
# Claude Workspace Status Bar
# Compact, informative status display in IDE style

# Colors for status indicators
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get workspace root
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Projects count
ACTIVE_PROJECTS=$(find "$WORKSPACE_ROOT/projects/active" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
SANDBOX_PROJECTS=$(find "$WORKSPACE_ROOT/projects/sandbox" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
TOTAL_PROJECTS=$((ACTIVE_PROJECTS + SANDBOX_PROJECTS))

# Modified files count
MODIFIED_FILES=$(git -C "$WORKSPACE_ROOT" status --porcelain 2>/dev/null | wc -l)

# Memory files count
MEMORY_FILES=$(find "$WORKSPACE_ROOT/configs/memory" -name "*.md" 2>/dev/null | wc -l)

# Last sync status
SYNC_LOG="$WORKSPACE_ROOT/logs/sync.log"
if [[ -f "$SYNC_LOG" ]]; then
    LAST_SYNC=$(tail -1 "$SYNC_LOG" | grep -o '\[.*\]' | head -1)
    if tail -5 "$SYNC_LOG" | grep -q "fatal\|error\|Error"; then
        SYNC_STATUS="${RED}✗${NC}"
    else
        SYNC_STATUS="${GREEN}✓${NC}"
    fi
else
    SYNC_STATUS="${YELLOW}?${NC}"
    LAST_SYNC="[No sync log]"
fi

# Git branch
GIT_BRANCH=$(git -C "$WORKSPACE_ROOT" branch --show-current 2>/dev/null || echo "no-git")

# Build status bar
STATUS_BAR=""
STATUS_BAR+="${CYAN}Projects${NC} [${BLUE}${TOTAL_PROJECTS}${NC}] | "
STATUS_BAR+="${CYAN}Memory${NC} [${BLUE}${MEMORY_FILES}${NC}] | "
STATUS_BAR+="${CYAN}Modified${NC} [${YELLOW}${MODIFIED_FILES}${NC}] | "
STATUS_BAR+="${CYAN}Sync${NC} ${SYNC_STATUS} | "
STATUS_BAR+="${CYAN}Branch${NC} ${GREEN}${GIT_BRANCH}${NC}"

# Output
echo -e "$STATUS_BAR"

# Optional: Show breakdown if verbose flag
if [[ "$1" == "-v" || "$1" == "--verbose" ]]; then
    echo ""
    echo -e "${CYAN}Breakdown:${NC}"
    echo -e "  Active: ${ACTIVE_PROJECTS} | Sandbox: ${SANDBOX_PROJECTS}"
    if [[ $MODIFIED_FILES -gt 0 ]]; then
        echo -e "  ${YELLOW}Modified files:${NC}"
        git -C "$WORKSPACE_ROOT" status --porcelain 2>/dev/null | sed 's/^/    /'
    fi
    echo -e "  Last sync: ${LAST_SYNC}"
fi