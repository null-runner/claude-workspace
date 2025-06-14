#!/bin/bash
# 🚀 Claude Workspace All-in-One Installer
# Universal installer per Linux, macOS, Windows (WSL)
# Un comando solo: bash <(curl -sSL https://raw.githubusercontent.com/YOUR-USERNAME/claude-workspace/main/install.sh)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global variables
WORKSPACE_DIR="$HOME/claude-workspace"
PYTHON_MIN_VERSION="3.8"
NODE_MIN_VERSION="18"

echo -e "${CYAN}🚀 Claude Workspace Universal Installer${NC}"
echo -e "${BLUE}Installing enterprise-grade autonomous system...${NC}"
echo ""

# Function to detect OS
detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q Microsoft /proc/version 2>/dev/null; then
            echo "wsl"
        else
            echo "linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "cygwin" ]] || [[ "$OSTYPE" == "msys" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check Python version
check_python() {
    local python_cmd=""
    
    if command_exists python3; then
        python_cmd="python3"
    elif command_exists python; then
        python_cmd="python"
    else
        return 1
    fi
    
    local version=$($python_cmd --version 2>&1 | awk '{print $2}' | cut -d. -f1,2)
    local major=$(echo "$version" | cut -d. -f1)
    local minor=$(echo "$version" | cut -d. -f2)
    
    if [[ $major -gt 3 ]] || [[ $major -eq 3 && $minor -ge 8 ]]; then
        echo "$python_cmd"
        return 0
    else
        return 1
    fi
}

# Function to check Node.js version
check_node() {
    if ! command_exists node; then
        return 1
    fi
    
    local version=$(node --version | sed 's/v//' | cut -d. -f1)
    if [[ $version -ge $NODE_MIN_VERSION ]]; then
        return 0
    else
        return 1
    fi
}

# Function to install dependencies
install_dependencies() {
    local os=$(detect_os)
    echo -e "${YELLOW}📦 Installing dependencies for $os...${NC}"
    
    case $os in
        "linux"|"wsl")
            # Update package list
            sudo apt-get update -qq
            
            # Install Python if needed
            if ! check_python >/dev/null; then
                echo -e "${BLUE}Installing Python 3...${NC}"
                sudo apt-get install -y python3 python3-pip
            fi
            
            # Install Node.js if needed
            if ! check_node; then
                echo -e "${BLUE}Installing Node.js...${NC}"
                curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
                sudo apt-get install -y nodejs
            fi
            
            # Install Git if needed
            if ! command_exists git; then
                echo -e "${BLUE}Installing Git...${NC}"
                sudo apt-get install -y git
            fi
            
            # Install other dependencies
            sudo apt-get install -y curl wget jq
            ;;
            
        "macos")
            # Install Homebrew if needed
            if ! command_exists brew; then
                echo -e "${BLUE}Installing Homebrew...${NC}"
                /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            fi
            
            # Install Python if needed
            if ! check_python >/dev/null; then
                echo -e "${BLUE}Installing Python 3...${NC}"
                brew install python@3.11
            fi
            
            # Install Node.js if needed
            if ! check_node; then
                echo -e "${BLUE}Installing Node.js...${NC}"
                brew install node
            fi
            
            # Install Git if needed
            if ! command_exists git; then
                echo -e "${BLUE}Installing Git...${NC}"
                brew install git
            fi
            
            # Install other dependencies
            brew install jq
            ;;
            
        *)
            echo -e "${RED}❌ Unsupported OS: $os${NC}"
            echo -e "${YELLOW}Please install manually: Python 3.8+, Node.js 18+, Git${NC}"
            exit 1
            ;;
    esac
}

# Function to install Claude Code
install_claude_code() {
    echo -e "${YELLOW}📱 Installing Claude Code...${NC}"
    
    if command_exists npm; then
        npm install -g @anthropic-ai/claude-code
        echo -e "${GREEN}✅ Claude Code installed globally${NC}"
    else
        echo -e "${RED}❌ npm not found. Installing Node.js first...${NC}"
        install_dependencies
        npm install -g @anthropic-ai/claude-code
    fi
    
    # Verify installation
    if command_exists claude; then
        echo -e "${GREEN}✅ Claude Code successfully installed${NC}"
        claude --version
    else
        echo -e "${YELLOW}⚠️  Claude Code installed but not in PATH. Adding to shell profile...${NC}"
        
        # Add to shell profile
        local shell_profile=""
        if [[ -f "$HOME/.bashrc" ]]; then
            shell_profile="$HOME/.bashrc"
        elif [[ -f "$HOME/.zshrc" ]]; then
            shell_profile="$HOME/.zshrc"
        elif [[ -f "$HOME/.profile" ]]; then
            shell_profile="$HOME/.profile"
        fi
        
        if [[ -n "$shell_profile" ]]; then
            echo 'export PATH="$(npm root -g)/@anthropic-ai/claude-code/bin:$PATH"' >> "$shell_profile"
            echo -e "${BLUE}Added Claude Code to $shell_profile${NC}"
            echo -e "${YELLOW}Run: source $shell_profile${NC}"
        fi
    fi
}

# Function to clone workspace
clone_workspace() {
    echo -e "${YELLOW}📂 Setting up Claude Workspace...${NC}"
    
    if [[ -d "$WORKSPACE_DIR" ]]; then
        echo -e "${YELLOW}⚠️  Directory $WORKSPACE_DIR already exists${NC}"
        read -p "Remove and reinstall? [y/N]: " -r
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$WORKSPACE_DIR"
        else
            echo -e "${BLUE}Using existing directory${NC}"
            cd "$WORKSPACE_DIR"
            git pull origin main 2>/dev/null || true
            return 0
        fi
    fi
    
    echo -e "${BLUE}Cloning repository...${NC}"
    git clone https://github.com/null-runner/claude-workspace.git "$WORKSPACE_DIR"
    cd "$WORKSPACE_DIR"
    
    # Make scripts executable
    chmod +x scripts/*.sh
    
    echo -e "${GREEN}✅ Workspace cloned successfully${NC}"
}

# Function to setup workspace
setup_workspace() {
    echo -e "${YELLOW}⚙️  Setting up workspace...${NC}"
    
    cd "$WORKSPACE_DIR"
    
    # Run the setup script
    if [[ -f "scripts/claude-setup-profile.sh" ]]; then
        echo -e "${BLUE}Running initial setup...${NC}"
        ./scripts/claude-setup-profile.sh setup
    fi
    
    # Start the autonomous system
    if [[ -f "scripts/claude-startup.sh" ]]; then
        echo -e "${BLUE}Starting autonomous system...${NC}"
        ./scripts/claude-startup.sh
    fi
    
    echo -e "${GREEN}✅ Workspace setup completed${NC}"
}

# Function to create convenient aliases
create_aliases() {
    echo -e "${YELLOW}🔗 Creating convenience aliases...${NC}"
    
    local shell_profile=""
    if [[ -f "$HOME/.bashrc" ]]; then
        shell_profile="$HOME/.bashrc"
    elif [[ -f "$HOME/.zshrc" ]]; then
        shell_profile="$HOME/.zshrc"
    elif [[ -f "$HOME/.profile" ]]; then
        shell_profile="$HOME/.profile"
    fi
    
    if [[ -n "$shell_profile" ]]; then
        # Add aliases if not already present
        if ! grep -q "# Claude Workspace aliases" "$shell_profile"; then
            cat >> "$shell_profile" << 'EOF'

# Claude Workspace aliases
alias cw='cd ~/claude-workspace && ./scripts/claude-startup.sh'
alias cws='cd ~/claude-workspace && ./scripts/claude-autonomous-system.sh status'
alias cwm='cd ~/claude-workspace && ./scripts/claude-simplified-memory.sh'
alias cexit='~/claude-workspace/scripts/cexit'
EOF
            echo -e "${GREEN}✅ Aliases added to $shell_profile${NC}"
        fi
    fi
}

# Function to display completion message
show_completion() {
    echo ""
    echo -e "${GREEN}🎉 Claude Workspace Installation Complete!${NC}"
    echo ""
    echo -e "${CYAN}📋 What was installed:${NC}"
    echo -e "  ✅ Python $(python3 --version 2>/dev/null | awk '{print $2}' || echo 'N/A')"
    echo -e "  ✅ Node.js $(node --version 2>/dev/null || echo 'N/A')"
    echo -e "  ✅ Claude Code $(claude --version 2>/dev/null || echo 'installed but not in PATH')"
    echo -e "  ✅ Claude Workspace Enterprise System"
    echo ""
    echo -e "${CYAN}🚀 Quick Start:${NC}"
    echo -e "  ${YELLOW}1.${NC} Open a new terminal (to load new PATH)"
    echo -e "  ${YELLOW}2.${NC} Run: ${BLUE}claude${NC}"
    echo -e "  ${YELLOW}3.${NC} When Claude starts, run: ${BLUE}cw${NC}"
    echo ""
    echo -e "${CYAN}💡 Useful commands:${NC}"
    echo -e "  ${BLUE}cw${NC}      - Go to workspace and start system"
    echo -e "  ${BLUE}cws${NC}     - Check autonomous system status"
    echo -e "  ${BLUE}cwm${NC}     - Memory management"
    echo -e "  ${BLUE}cexit${NC}   - Graceful exit from Claude"
    echo ""
    echo -e "${YELLOW}📖 Documentation: ~/claude-workspace/README.md${NC}"
    echo -e "${YELLOW}🆘 Issues: https://github.com/null-runner/claude-workspace/issues${NC}"
}

# Main installation flow
main() {
    local os=$(detect_os)
    echo -e "${BLUE}Detected OS: $os${NC}"
    echo ""
    
    # Check if running as root (not recommended)
    if [[ $EUID -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  Running as root is not recommended${NC}"
        read -p "Continue anyway? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Install dependencies
    install_dependencies
    
    # Install Claude Code
    install_claude_code
    
    # Clone and setup workspace
    clone_workspace
    setup_workspace
    
    # Create aliases
    create_aliases
    
    # Show completion message
    show_completion
}

# Error handler
error_handler() {
    echo ""
    echo -e "${RED}❌ Installation failed at line $1${NC}"
    echo -e "${YELLOW}💡 Please check the error above and try again${NC}"
    echo -e "${YELLOW}🆘 Report issues: https://github.com/null-runner/claude-workspace/issues${NC}"
    exit 1
}

trap 'error_handler $LINENO' ERR

# Run main installation
main "$@"