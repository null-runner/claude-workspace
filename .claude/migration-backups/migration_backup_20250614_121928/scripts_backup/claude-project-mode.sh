#!/bin/bash
# Claude Project Mode - Gestione compartimentalizzata progetti
# Configura comportamento Claude per workspace vs progetti esterni

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

show_help() {
    echo "Claude Project Mode - Gestione Progetti Compartimentalizzata"
    echo ""
    echo "Usage: $0 [comando]"
    echo ""
    echo "Comandi:"
    echo "  detect           Rileva tipo progetto corrente"
    echo "  workspace        Abilita modalità workspace (auto-push, sync completo)"
    echo "  external         Abilita modalità progetto esterno (controllo manuale)"
    echo "  status           Mostra configurazione corrente"
    echo "  install-hook     Installa git hook sicuro in progetto corrente"
    echo ""
    echo "Modalità:"
    echo "  🏠 WORKSPACE     Auto-push, sync automatico, memory completo"
    echo "  🌍 EXTERNAL      No auto-push, sync limitato, controllo manuale"
}

detect_project_type() {
    local remote_url=$(git remote get-url origin 2>/dev/null || echo "no-remote")
    local is_workspace=false
    local has_claude_dir=false
    local auto_push_status="unknown"
    
    # Check if it's claude-workspace
    if [[ "$remote_url" == *"claude-workspace"* ]]; then
        is_workspace=true
    fi
    
    # Check for .claude directory
    if [[ -d ".claude" ]]; then
        has_claude_dir=true
    fi
    
    # Check auto-push configuration
    if [[ -f ".no-auto-push" ]]; then
        auto_push_status="disabled"
    elif [[ -f ".auto-push-enabled" ]]; then
        auto_push_status="enabled"
    elif [[ "$is_workspace" == true ]]; then
        auto_push_status="whitelisted"
    else
        auto_push_status="default-disabled"
    fi
    
    echo -e "${CYAN}🔍 Project Detection Results:${NC}"
    echo -e "  Repository: $remote_url"
    echo -e "  Claude Workspace: $([ "$is_workspace" = true ] && echo "✅ Yes" || echo "❌ No")"
    echo -e "  Claude Directory: $([ "$has_claude_dir" = true ] && echo "✅ Present" || echo "❌ Missing")"
    echo -e "  Auto-Push: $auto_push_status"
    echo ""
    
    if [[ "$is_workspace" == true ]]; then
        echo -e "${GREEN}🏠 MODE: WORKSPACE${NC}"
        echo -e "  - Auto-push enabled"
        echo -e "  - Full autonomous operations"
        echo -e "  - Complete memory system"
    else
        echo -e "${BLUE}🌍 MODE: EXTERNAL PROJECT${NC}"
        echo -e "  - Manual push control"
        echo -e "  - Limited autonomous operations"
        echo -e "  - Project-specific memory"
    fi
}

configure_workspace_mode() {
    echo -e "${GREEN}🏠 Configuring Workspace Mode...${NC}"
    
    # Remove disable marker if present
    rm -f .no-auto-push 2>/dev/null
    
    # Create workspace indicators
    mkdir -p .claude/memory .claude/logs
    
    echo -e "${GREEN}✅ Workspace mode configured!${NC}"
    echo -e "  - Auto-push: Enabled"
    echo -e "  - Memory system: Full"
    echo -e "  - Autonomous ops: Enabled"
}

configure_external_mode() {
    echo -e "${BLUE}🌍 Configuring External Project Mode...${NC}"
    
    # Disable auto-push
    touch .no-auto-push
    echo "# Auto-push disabled for external project" > .no-auto-push
    
    # Create minimal claude directory for project memory
    mkdir -p .claude/project-memory
    
    echo -e "${BLUE}✅ External project mode configured!${NC}"
    echo -e "  - Auto-push: Disabled"
    echo -e "  - Memory system: Project-only"
    echo -e "  - Push control: Manual"
    echo ""
    echo -e "${YELLOW}💡 Use 'git add . && git commit -m \"msg\" && git push' for manual control${NC}"
}

install_safe_hook() {
    local hook_source="$HOME/claude-workspace/.git/hooks/post-commit"
    local hook_dest=".git/hooks/post-commit"
    
    if [[ ! -f "$hook_source" ]]; then
        echo -e "${RED}❌ Source hook not found at $hook_source${NC}"
        return 1
    fi
    
    if [[ ! -d ".git" ]]; then
        echo -e "${RED}❌ Not in a git repository${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📋 Installing safe git hook...${NC}"
    
    # Backup existing hook if present
    if [[ -f "$hook_dest" ]]; then
        mv "$hook_dest" "$hook_dest.backup.$(date +%s)"
        echo -e "${YELLOW}⚠️  Existing hook backed up${NC}"
    fi
    
    # Copy hook
    cp "$hook_source" "$hook_dest"
    chmod +x "$hook_dest"
    
    echo -e "${GREEN}✅ Safe git hook installed!${NC}"
    echo -e "  - Auto-push: Whitelist controlled"
    echo -e "  - Safety: Built-in"
    echo -e "  - Override: .auto-push-enabled / .no-auto-push"
}

show_status() {
    echo -e "${CYAN}📊 Claude Project Status${NC}"
    echo ""
    detect_project_type
    
    if [[ -f ".git/hooks/post-commit" ]]; then
        echo -e "${GREEN}✅ Git hook installed${NC}"
    else
        echo -e "${YELLOW}⚠️  Git hook not installed${NC}"
        echo -e "   Run: $0 install-hook"
    fi
}

# Main command handling
case "${1:-}" in
    "detect")
        detect_project_type
        ;;
    "workspace")
        configure_workspace_mode
        ;;
    "external")
        configure_external_mode
        ;;
    "install-hook")
        install_safe_hook
        ;;
    "status")
        show_status
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_status
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac