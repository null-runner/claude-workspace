#!/bin/bash
# setup.sh - Script di setup unificato per Claude Code Multi-Device
# Uso: curl -fsSL https://raw.githubusercontent.com/nullrunner/claude-workspace/main/setup.sh | bash

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configurazione
WORKSPACE_DIR="$HOME/claude-workspace"
GITHUB_REPO="${GITHUB_REPO:-nullrunner/claude-workspace}"
SETUP_VERSION="1.0.0"

# Logging functions
log() { echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"; }
error() { echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"; exit 1; }
info() { echo -e "${CYAN}[$(date '+%H:%M:%S')] ℹ️  $1${NC}"; }
header() { 
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║$(printf "%-68s" " $1")║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Banner
show_banner() {
    clear
    echo -e "${BLUE}${BOLD}"
    cat << 'EOF'
    ██████╗██╗      ██████╗ ██╗   ██╗██████╗ ███████╗     ██████╗ ██████╗ ██████╗ ███████╗
   ██╔════╝██║     ██╔══██╗██║   ██║██╔══██╗██╔════╝    ██╔════╝██╔═══██╗██╔══██╗██╔════╝
   ██║     ██║     ██████╔╝██║   ██║██║  ██║█████╗      ██║     ██║   ██║██║  ██║█████╗  
   ██║     ██║     ██╔══██╗██║   ██║██║  ██║██╔══╝      ██║     ██║   ██║██║  ██║██╔══╝  
   ╚██████╗███████╗██║  ██║╚██████╔╝██████╔╝███████╗    ╚██████╗╚██████╔╝██████╔╝███████╗
    ╚═════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝ ╚══════╝     ╚═════╝ ╚═════╝ ╚═════╝ ╚══════╝
EOF
    echo -e "${NC}"
    echo -e "${CYAN}                      Multi-Device Autonomous Development Setup${NC}"
    echo -e "${YELLOW}                              Version $SETUP_VERSION${NC}"
    echo
}

# Pre-flight checks
preflight_checks() {
    header "🔍 PRE-FLIGHT CHECKS"
    
    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root"
    fi
    
    # Check internet connectivity
    if ! ping -c 1 google.com >/dev/null 2>&1; then
        error "Internet connection required"
    fi
    
    # Check basic tools
    for tool in curl git; do
        if ! command -v $tool >/dev/null 2>&1; then
            error "$tool is required but not installed"
        fi
    done
    
    log "Pre-flight checks passed"
}

# System detection
detect_system() {
    header "🖥️ SYSTEM DETECTION"
    
    # OS Detection
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if grep -q Microsoft /proc/version 2>/dev/null; then
            OS="wsl"
            info "Detected: Windows WSL"
        else
            OS="linux"
            info "Detected: Linux"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        info "Detected: macOS"
    else
        error "Unsupported operating system: $OSTYPE"
    fi
    
    # Architecture
    ARCH=$(uname -m)
    info "Architecture: $ARCH"
    
    # Package manager
    if command -v apt >/dev/null 2>&1; then
        PKG_MANAGER="apt"
        PKG_INSTALL="sudo apt update && sudo apt install -y"
        PKG_UPDATE="sudo apt update"
    elif command -v brew >/dev/null 2>&1; then
        PKG_MANAGER="brew"
        PKG_INSTALL="brew install"
        PKG_UPDATE="brew update"
    elif command -v yum >/dev/null 2>&1; then
        PKG_MANAGER="yum"
        PKG_INSTALL="sudo yum install -y"
        PKG_UPDATE="sudo yum update -y"
    elif command -v pacman >/dev/null 2>&1; then
        PKG_MANAGER="pacman"
        PKG_INSTALL="sudo pacman -S --noconfirm"
        PKG_UPDATE="sudo pacman -Sy"
    else
        PKG_MANAGER="manual"
        warn "No package manager detected - manual installation required"
    fi
    
    info "Package manager: $PKG_MANAGER"
    
    # Service manager
    if systemctl --user status >/dev/null 2>&1; then
        SERVICE_MANAGER="systemd"
    elif [[ "$OS" == "macos" ]]; then
        SERVICE_MANAGER="launchd"
    else
        SERVICE_MANAGER="cron"
    fi
    
    info "Service manager: $SERVICE_MANAGER"
}

# Device role detection
detect_device_role() {
    header "🎯 DEVICE ROLE DETECTION"
    
    # Try to determine from hostname
    HOSTNAME_LOWER=$(hostname | tr '[:upper:]' '[:lower:]')
    
    if [[ "$HOSTNAME_LOWER" =~ (desktop|fisso|neural|wsl|primary|main) ]]; then
        DEVICE_ROLE="primary"
        info "Auto-detected role: PRIMARY (desktop/main device)"
        AUTO_DETECTED=true
    elif [[ "$HOSTNAME_LOWER" =~ (laptop|mobile|macbook|secondary|portable) ]]; then
        DEVICE_ROLE="secondary"
        info "Auto-detected role: SECONDARY (laptop/mobile device)"
        AUTO_DETECTED=true
    else
        AUTO_DETECTED=false
        echo
        info "Could not auto-detect device role from hostname: $(hostname)"
        echo
        echo "Device roles:"
        echo "  PRIMARY   - Main development machine (desktop, workstation)"
        echo "  SECONDARY - Mobile/laptop device for on-the-go development"
        echo
        while true; do
            read -p "Is this the PRIMARY device? [y/N]: " -n 1 -r
            echo
            case $REPLY in
                [Yy]* ) DEVICE_ROLE="primary"; break;;
                [Nn]* ) DEVICE_ROLE="secondary"; break;;
                * ) DEVICE_ROLE="secondary"; break;;
            esac
        done
    fi
    
    log "Device role set: ${DEVICE_ROLE^^}"
    
    # Check if workspace already exists
    if [[ -d "$WORKSPACE_DIR" ]] && [[ -d "$WORKSPACE_DIR/.git" ]]; then
        warn "Existing workspace detected at $WORKSPACE_DIR"
        echo
        read -p "Continue and update existing workspace? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            error "Setup cancelled by user"
        fi
        WORKSPACE_EXISTS=true
    else
        WORKSPACE_EXISTS=false
    fi
}

# Install dependencies
install_dependencies() {
    header "📦 INSTALLING DEPENDENCIES"
    
    # Update package list
    if [[ "$PKG_MANAGER" != "manual" ]] && [[ "$PKG_MANAGER" != "brew" ]]; then
        info "Updating package lists..."
        eval $PKG_UPDATE >/dev/null 2>&1 || warn "Failed to update package lists"
    fi
    
    # Install system dependencies
    case "$OS" in
        "linux"|"wsl")
            DEPS="git ssh-client curl jq inotify-tools wget unzip fontconfig"
            ;;
        "macos")
            DEPS="git curl jq fswatch"
            ;;
    esac
    
    for dep in $DEPS; do
        if ! command -v ${dep%%-*} >/dev/null 2>&1; then
            info "Installing $dep..."
            if [[ "$PKG_MANAGER" != "manual" ]]; then
                eval "$PKG_INSTALL $dep" >/dev/null 2>&1 || warn "Failed to install $dep"
            else
                warn "$dep not found - manual installation required"
            fi
        else
            log "$dep already installed"
        fi
    done
    
    # Install Claude Code if not present
    if ! command -v claude >/dev/null 2>&1; then
        info "Installing Claude Code..."
        if command -v npm >/dev/null 2>&1; then
            npm install -g @anthropic-ai/claude-cli >/dev/null 2>&1 || {
                warn "NPM installation failed, trying direct download..."
                curl -fsSL https://claude.ai/cli/install.sh | sh
            }
        else
            curl -fsSL https://claude.ai/cli/install.sh | sh
        fi
        
        if command -v claude >/dev/null 2>&1; then
            log "Claude Code installed successfully"
        else
            error "Failed to install Claude Code"
        fi
    else
        log "Claude Code already installed: $(claude --version 2>/dev/null || echo 'Unknown version')"
    fi
}

# Terminal customization with Oh My Posh and AtomicBit
setup_terminal_customization() {
    header "🎨 TERMINAL CUSTOMIZATION"
    
    # Install Fira Code font
    case "$OS" in
        "linux"|"wsl")
            info "Installing Fira Code font..."
            if [[ "$PKG_MANAGER" == "apt" ]]; then
                $PKG_INSTALL fonts-firacode >/dev/null 2>&1 || {
                    # Manual installation if package not available
                    mkdir -p ~/.local/share/fonts
                    cd /tmp
                    wget -q https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip
                    unzip -q Fira_Code_v6.2.zip -d FiraCode
                    cp FiraCode/ttf/*.ttf ~/.local/share/fonts/
                    fc-cache -f -v >/dev/null 2>&1
                    cd "$WORKSPACE_DIR"
                }
            fi
            log "Fira Code font installed"
            ;;
        "macos")
            info "Installing Fira Code font..."
            if [[ "$PKG_MANAGER" == "brew" ]]; then
                brew tap homebrew/cask-fonts >/dev/null 2>&1
                brew install font-fira-code >/dev/null 2>&1
            else
                # Manual installation
                cd /tmp
                curl -LO https://github.com/tonsky/FiraCode/releases/download/6.2/Fira_Code_v6.2.zip
                unzip -q Fira_Code_v6.2.zip -d FiraCode
                cp FiraCode/ttf/*.ttf ~/Library/Fonts/
                cd "$WORKSPACE_DIR"
            fi
            log "Fira Code font installed"
            ;;
    esac
    
    # Install Oh My Posh
    if ! command -v oh-my-posh >/dev/null 2>&1; then
        info "Installing Oh My Posh..."
        case "$OS" in
            "linux"|"wsl")
                curl -s https://ohmyposh.dev/install.sh | bash -s >/dev/null 2>&1
                ;;
            "macos")
                if [[ "$PKG_MANAGER" == "brew" ]]; then
                    brew install jandedobbeleer/oh-my-posh/oh-my-posh >/dev/null 2>&1
                else
                    curl -s https://ohmyposh.dev/install.sh | bash -s >/dev/null 2>&1
                fi
                ;;
        esac
        log "Oh My Posh installed"
    else
        log "Oh My Posh already installed"
    fi
    
    # Download AtomicBit theme
    info "Setting up AtomicBit theme..."
    mkdir -p ~/.config/oh-my-posh/themes
    
    # Create custom AtomicBit theme for Claude development
    cat > ~/.config/oh-my-posh/themes/claude-atomicbit.omp.json << 'THEME_EOF'
{
  "$schema": "https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/schema.json",
  "version": 2,
  "final_space": true,
  "console_title_template": "{{ .Shell }} in {{ .Folder }}",
  "blocks": [
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "path",
          "style": "plain",
          "foreground": "#56B6C2",
          "background": "transparent",
          "template": "╭─[{{ .UserName }}@{{ .HostName }}]─[{{ .Path }}]",
          "properties": {
            "style": "full"
          }
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "right",
      "segments": [
        {
          "type": "text",
          "style": "plain",
          "foreground": "#E06C75",
          "background": "transparent",
          "template": "({{ if .Env.WSL_DISTRO_NAME }}WSL{{ else }}{{ .OS }}{{ end }} at {{ .CurrentDate | date \"15:04\" }})"
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "git",
          "style": "plain",
          "foreground": "#98C379",
          "background": "transparent",
          "template": "─[{{ if .UpstreamGone }}{{ .HEAD }}{{ else }}{{ .HEAD }}{{ if .BehindCount }} ⇣{{ .BehindCount }}{{ end }}{{ if .AheadCount }} ⇡{{ .AheadCount }}{{ end }}{{ end }}{{ if .Working.Changed }} ●{{ .Working.String }}{{ end }}{{ if .Staging.Changed }} ✚{{ .Staging.String }}{{ end }}]",
          "properties": {
            "fetch_status": true,
            "fetch_upstream_icon": true
          }
        }
      ]
    },
    {
      "type": "prompt",
      "alignment": "left",
      "newline": true,
      "segments": [
        {
          "type": "text",
          "style": "plain",
          "foreground": "#E5C07B",
          "background": "transparent",
          "template": "╰─[ {{ .Shell }} ]─ "
        }
      ]
    }
  ]
}
THEME_EOF
    
    # Configure shell initialization
    case "$SHELL" in
        */bash)
            SHELL_RC="$HOME/.bashrc"
            if ! grep -q "oh-my-posh init" "$SHELL_RC" 2>/dev/null; then
                echo '' >> "$SHELL_RC"
                echo '# Oh My Posh initialization' >> "$SHELL_RC"
                echo 'eval "$(oh-my-posh init bash --config ~/.config/oh-my-posh/themes/claude-atomicbit.omp.json)"' >> "$SHELL_RC"
                echo '' >> "$SHELL_RC"
                echo '# Claude workspace aliases' >> "$SHELL_RC"
                echo 'alias cws="cd ~/claude-workspace"' >> "$SHELL_RC"
                echo 'alias cstatus="~/claude-workspace/scripts/operations/ecosystem-status.sh"' >> "$SHELL_RC"
                echo 'alias csync="~/claude-workspace/scripts/sync/manual-sync-all.sh"' >> "$SHELL_RC"
                echo 'alias cprojects="cd ~/claude-workspace/projects/active"' >> "$SHELL_RC"
                log "Bash configuration updated"
            fi
            ;;
        */zsh)
            SHELL_RC="$HOME/.zshrc"
            if ! grep -q "oh-my-posh init" "$SHELL_RC" 2>/dev/null; then
                echo '' >> "$SHELL_RC"
                echo '# Oh My Posh initialization' >> "$SHELL_RC"
                echo 'eval "$(oh-my-posh init zsh --config ~/.config/oh-my-posh/themes/claude-atomicbit.omp.json)"' >> "$SHELL_RC"
                echo '' >> "$SHELL_RC"
                echo '# Claude workspace aliases' >> "$SHELL_RC"
                echo 'alias cws="cd ~/claude-workspace"' >> "$SHELL_RC"
                echo 'alias cstatus="~/claude-workspace/scripts/operations/ecosystem-status.sh"' >> "$SHELL_RC"
                echo 'alias csync="~/claude-workspace/scripts/sync/manual-sync-all.sh"' >> "$SHELL_RC"
                echo 'alias cprojects="cd ~/claude-workspace/projects/active"' >> "$SHELL_RC"
                log "Zsh configuration updated"
            fi
            ;;
    esac
    
    # Terminal configuration suggestions
    info "Terminal setup complete!"
    echo
    warn "📝 MANUAL TERMINAL CONFIGURATION NEEDED:"
    echo "   1. Set terminal font to 'Fira Code' with ligatures enabled"
    echo "   2. Restart terminal or run: source $SHELL_RC"
    echo "   3. Verify with: oh-my-posh --version"
    echo
}

# Setup workspace
setup_workspace() {
    header "🏗️ WORKSPACE SETUP"
    
    if [[ "$WORKSPACE_EXISTS" == true ]]; then
        info "Updating existing workspace..."
        cd "$WORKSPACE_DIR"
        
        # Backup any local changes
        if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
            warn "Backing up local changes..."
            git stash push -m "Auto-backup before setup update - $(date)" >/dev/null 2>&1 || true
        fi
        
        # Pull latest changes
        git pull origin main >/dev/null 2>&1 || warn "Failed to pull latest changes"
        
    else
        info "Creating new workspace..."
        
        if [[ "$DEVICE_ROLE" == "primary" ]]; then
            # Primary device: create new workspace
            mkdir -p "$WORKSPACE_DIR"
            cd "$WORKSPACE_DIR"
            
            # Initialize git repository
            git init >/dev/null 2>&1
            git branch -M main >/dev/null 2>&1
            
            # Create basic structure
            mkdir -p {.claude-config/{ssh-keys,git-config,audit},projects/{active,archive,sandbox},templates,logs/{claude-activity,git-operations,errors,sync},scripts/{setup,security,operations,monitoring,sync},docs}
            
            # Create initial files
            cat > README.md << EOF
# Claude Code Multi-Device Workspace

Autonomous development environment synchronized across devices.

## Setup Information
- Created: $(date)
- Primary Device: $(hostname)
- Version: $SETUP_VERSION

## Quick Start
\`\`\`bash
# Start development
claude start --workspace ~/claude-workspace/projects

# Check status
./scripts/operations/ecosystem-status.sh

# Manual sync
./scripts/sync/manual-sync-all.sh
\`\`\`

## Device Synchronization
This workspace automatically synchronizes between:
- 🖥️ Primary device ($(hostname))
- 💻 Secondary devices (configured separately)
- ☁️ GitHub repository as central hub

All changes are automatically committed and synchronized in real-time.
EOF
            
            log "Workspace structure created"
            
        else
            # Secondary device: clone existing workspace
            info "Cloning workspace from GitHub..."
            
            # Try SSH first, fallback to HTTPS
            if git clone "git@github.com:$GITHUB_REPO.git" "$WORKSPACE_DIR" >/dev/null 2>&1; then
                log "Workspace cloned via SSH"
            elif git clone "https://github.com/$GITHUB_REPO.git" "$WORKSPACE_DIR" >/dev/null 2>&1; then
                log "Workspace cloned via HTTPS"
            else
                warn "Failed to clone workspace, creating minimal structure..."
                mkdir -p "$WORKSPACE_DIR"
                cd "$WORKSPACE_DIR"
                git init >/dev/null 2>&1
                mkdir -p {.claude-config,projects,scripts,logs}
                echo "# Minimal workspace - sync required" > README.md
            fi
            
            cd "$WORKSPACE_DIR"
        fi
    fi
    
    # Create device info
    cat > .claude-config/device-info.json << EOF
{
    "device_role": "$DEVICE_ROLE",
    "hostname": "$(hostname)",
    "os": "$OS",
    "setup_version": "$SETUP_VERSION",
    "setup_date": "$(date -Iseconds)",
    "auto_detected": $AUTO_DETECTED
}
EOF
    
    log "Device information saved"
}

# Generate SSH keys
setup_ssh_keys() {
    header "🔑 SSH KEY SETUP"
    
    SSH_KEY_PATH="$WORKSPACE_DIR/.claude-config/ssh-keys/claude_sync_key"
    
    if [[ -f "$SSH_KEY_PATH" ]]; then
        info "SSH key already exists"
        KEY_EXISTS=true
    else
        info "Generating new SSH key..."
        mkdir -p "$(dirname "$SSH_KEY_PATH")"
        
        ssh-keygen -t ed25519 -f "$SSH_KEY_PATH" \
            -C "claude-sync-$(hostname)-$(date +%Y%m%d)" -N "" >/dev/null 2>&1
        
        if [[ -f "$SSH_KEY_PATH" ]]; then
            log "SSH key generated successfully"
            KEY_EXISTS=false
        else
            error "Failed to generate SSH key"
        fi
    fi
    
    # Create key metadata
    cat > "${SSH_KEY_PATH%/*}/key-info.json" << EOF
{
    "created": "$(date -Iseconds)",
    "hostname": "$(hostname)",
    "device_role": "$DEVICE_ROLE",
    "purpose": "Claude Multi-Device Sync",
    "key_type": "ed25519",
    "auto_generated": true
}
EOF
    
    # Configure SSH
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    
    # Update SSH config
    if ! grep -q "claude-sync" ~/.ssh/config 2>/dev/null; then
        cat >> ~/.ssh/config << EOF

# Claude Multi-Device Sync Configuration
Host github-claude
    HostName github.com
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes

# Default GitHub with Claude key
Host github.com
    User git
    IdentityFile $SSH_KEY_PATH
    IdentitiesOnly yes
    AddKeysToAgent yes
EOF
        chmod 600 ~/.ssh/config
        log "SSH configuration updated"
    else
        info "SSH configuration already exists"
    fi
    
    # Add key to SSH agent
    if command -v ssh-agent >/dev/null 2>&1; then
        eval "$(ssh-agent -s)" >/dev/null 2>&1
        ssh-add "$SSH_KEY_PATH" >/dev/null 2>&1 || warn "Could not add key to SSH agent"
    fi
}

# Create sync scripts
create_sync_scripts() {
    header "🔄 SYNC SYSTEM SETUP"
    
    # Main sync script
    cat > scripts/sync/claude-sync.sh << 'SYNC_EOF'
#!/bin/bash
# Main synchronization script

WORKSPACE_DIR="$HOME/claude-workspace"
LOG_FILE="$WORKSPACE_DIR/logs/sync/sync-$(date +%Y%m%d).log"
LOCK_FILE="/tmp/claude-sync-$(whoami).lock"

log_sync() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Prevent multiple instances
if [[ -f "$LOCK_FILE" ]]; then
    if kill -0 "$(cat "$LOCK_FILE")" 2>/dev/null; then
        exit 0  # Another instance running
    else
        rm -f "$LOCK_FILE"
    fi
fi
echo $$ > "$LOCK_FILE"
trap "rm -f $LOCK_FILE" EXIT

cd "$WORKSPACE_DIR" || exit 1

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"

log_sync "Starting sync from $(hostname)"

# Check for network connectivity
if ! ping -c 1 github.com >/dev/null 2>&1; then
    log_sync "No network connectivity, skipping sync"
    exit 0
fi

# Fetch latest changes
if ! git fetch origin >/dev/null 2>&1; then
    log_sync "Failed to fetch from remote"
    exit 1
fi

# Stage and commit local changes
if [[ -n "$(git status --porcelain)" ]]; then
    log_sync "Local changes detected, committing..."
    git add -A >/dev/null 2>&1
    
    # Create meaningful commit message
    CHANGED_FILES=$(git diff --cached --name-only | wc -l)
    git commit -m "Auto-sync: $CHANGED_FILES files from $(hostname) - $(date '+%H:%M')" >/dev/null 2>&1 || true
fi

# Merge remote changes
CURRENT_BRANCH=$(git branch --show-current)
if ! git merge origin/"$CURRENT_BRANCH" --no-edit >/dev/null 2>&1; then
    log_sync "Merge conflicts detected, resolving automatically..."
    
    # Simple conflict resolution: prefer local for project files, remote for config
    git status --porcelain | while read status file; do
        if [[ "$file" =~ ^projects/ ]]; then
            git checkout --ours "$file" >/dev/null 2>&1
        else
            git checkout --theirs "$file" >/dev/null 2>&1
        fi
    done
    
    git add -A >/dev/null 2>&1
    git commit -m "Auto-resolve conflicts on $(hostname)" >/dev/null 2>&1 || true
    log_sync "Conflicts resolved automatically"
fi

# Push changes
if git push origin "$CURRENT_BRANCH" >/dev/null 2>&1; then
    log_sync "Sync completed successfully"
else
    log_sync "Push failed, will retry later"
fi
SYNC_EOF
    
    chmod +x scripts/sync/claude-sync.sh
    
    # File watcher script
    case "$OS" in
        "linux"|"wsl")
            cat > scripts/sync/file-watcher.sh << 'WATCH_EOF'
#!/bin/bash
# File watcher using inotify

WORKSPACE_DIR="$HOME/claude-workspace"
cd "$WORKSPACE_DIR" || exit 1

# Create log file
LOG_FILE="logs/file-watcher.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] File watcher started on $(hostname)" >> "$LOG_FILE"

# Monitor file changes
inotifywait -m -r -e modify,create,delete,move \
    --exclude '(\.git/|logs/|\.tmp|cache/|node_modules/|__pycache__)' \
    --format '%T %w%f %e' --timefmt '%H:%M:%S' \
    "$WORKSPACE_DIR" 2>/dev/null |
while read time file event; do
    echo "[$time] Changed: $file ($event)" >> "$LOG_FILE"
    
    # Debounce - wait for file operations to complete
    sleep 3
    
    # Trigger sync
    ./scripts/sync/claude-sync.sh
done
WATCH_EOF
            ;;
            
        "macos")
            cat > scripts/sync/file-watcher.sh << 'WATCH_EOF'
#!/bin/bash
# File watcher using fswatch

WORKSPACE_DIR="$HOME/claude-workspace"
cd "$WORKSPACE_DIR" || exit 1

# Create log file
LOG_FILE="logs/file-watcher.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "[$(date)] File watcher started on $(hostname)" >> "$LOG_FILE"

# Monitor file changes
fswatch -r --exclude='\.git/' --exclude='logs/' --exclude='\.tmp' \
    --exclude='cache/' --exclude='node_modules/' \
    "$WORKSPACE_DIR" |
while read file; do
    echo "[$(date '+%H:%M:%S')] Changed: $file" >> "$LOG_FILE"
    
    # Debounce
    sleep 3
    
    # Trigger sync
    ./scripts/sync/claude-sync.sh
done
WATCH_EOF
            ;;
    esac
    
    chmod +x scripts/sync/file-watcher.sh
    log "Sync scripts created"
}

# Setup persistent services
setup_services() {
    header "🔧 PERSISTENT SERVICES SETUP"
    
    case "$SERVICE_MANAGER" in
        "systemd")
            mkdir -p ~/.config/systemd/user
            
            # File watcher service
            cat > ~/.config/systemd/user/claude-file-watcher.service << EOF
[Unit]
Description=Claude Workspace File Watcher
After=network.target graphical-session.target

[Service]
Type=simple
ExecStart=$WORKSPACE_DIR/scripts/sync/file-watcher.sh
Restart=always
RestartSec=10
Environment=HOME=$HOME
Environment=PATH=$PATH

[Install]
WantedBy=default.target
EOF
            
            # Periodic sync timer
            cat > ~/.config/systemd/user/claude-periodic-sync.timer << EOF
[Unit]
Description=Claude Periodic Sync Timer
Requires=claude-periodic-sync.service

[Timer]
OnCalendar=*:0/5
Persistent=true
RandomizedDelaySec=30

[Install]
WantedBy=timers.target
EOF
            
            cat > ~/.config/systemd/user/claude-periodic-sync.service << EOF
[Unit]
Description=Claude Periodic Sync
After=network.target

[Service]
Type=oneshot
ExecStart=$WORKSPACE_DIR/scripts/sync/claude-sync.sh
Environment=HOME=$HOME
Environment=PATH=$PATH
EOF
            
            # Enable and start services
            systemctl --user daemon-reload
            systemctl --user enable claude-file-watcher.service >/dev/null 2>&1
            systemctl --user enable claude-periodic-sync.timer >/dev/null 2>&1
            
            systemctl --user start claude-file-watcher.service >/dev/null 2>&1
            systemctl --user start claude-periodic-sync.timer >/dev/null 2>&1
            
            log "Systemd services configured and started"
            ;;
            
        "launchd")
            mkdir -p ~/Library/LaunchAgents
            
            # File watcher service
            cat > ~/Library/LaunchAgents/com.claude.filewatcher.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.filewatcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>$WORKSPACE_DIR/scripts/sync/file-watcher.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$WORKSPACE_DIR/logs/file-watcher-error.log</string>
    <key>StandardOutPath</key>
    <string>$WORKSPACE_DIR/logs/file-watcher-out.log</string>
</dict>
</plist>
EOF
            
            # Periodic sync service
            cat > ~/Library/LaunchAgents/com.claude.periodicsync.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.claude.periodicsync</string>
    <key>ProgramArguments</key>
    <array>
        <string>$WORKSPACE_DIR/scripts/sync/claude-sync.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>300</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF
            
            # Load services
            launchctl load ~/Library/LaunchAgents/com.claude.filewatcher.plist >/dev/null 2>&1
            launchctl load ~/Library/LaunchAgents/com.claude.periodicsync.plist >/dev/null 2>&1
            
            log "LaunchAgents configured and loaded"
            ;;
            
        "cron")
            # Add cron job for periodic sync
            (crontab -l 2>/dev/null; echo "*/5 * * * * $WORKSPACE_DIR/scripts/sync/claude-sync.sh >/dev/null 2>&1") | crontab -
            
            # Start file watcher in background
            nohup "$WORKSPACE_DIR/scripts/sync/file-watcher.sh" >/dev/null 2>&1 &
            echo $! > /tmp/claude-filewatcher.pid
            
            log "Cron job and background file watcher configured"
            ;;
    esac
}

# Setup Git repository
setup_git_repository() {
    header "📡 GIT REPOSITORY SETUP"
    
    cd "$WORKSPACE_DIR"
    
    # Configure Git if not already done
    if [[ -z "$(git config user.name 2>/dev/null)" ]]; then
        git config user.name "Claude Code Assistant"
        git config user.email "claude-dev@nullrunner.workspace"
        log "Git user configured"
    fi
    
    # Add remote if not exists
    if ! git remote get-url origin >/dev/null 2>&1; then
        git remote add origin "git@github.com:$GITHUB_REPO.git"
        log "Git remote added"
    fi
    
    # Create .gitignore if not exists
    if [[ ! -f ".gitignore" ]]; then
        cat > .gitignore << 'EOF'
# SSH keys and sensitive files
.claude-config/ssh-keys/*_key
.claude-config/ssh-keys/*.pem
*.key
*.pem

# Local logs and temporary files  
logs/sync/*
logs/claude-activity/*
logs/errors/*
logs/*.log
*.tmp
*.swp
*~

# OS generated files
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

# Development artifacts
node_modules/
__pycache__/
*.pyc
.pytest_cache/
.coverage
.venv/
.env
build/
dist/
*.egg-info/

# IDE files
.vscode/
.idea/
*.sublime-*
EOF
        log ".gitignore created"
    fi
    
    # Initial commit if needed
    if [[ -z "$(git log --oneline 2>/dev/null)" ]]; then
        git add .
        git commit -m "Initial workspace setup from $(hostname) ($DEVICE_ROLE)" >/dev/null 2>&1
        log "Initial commit created"
    fi
    
    # Try to push (might fail if repository doesn't exist yet)
    if git push -u origin main >/dev/null 2>&1; then
        log "Repository synchronized with GitHub"
    else
        warn "Could not push to GitHub - repository may need to be created manually"
    fi
}

# Final tests and validation
run_tests() {
    header "🧪 RUNNING VALIDATION TESTS"
    
    cd "$WORKSPACE_DIR"
    
    # Test 1: Git repository health
    if git status >/dev/null 2>&1; then
        log "✅ Git repository operational"
    else
        warn "❌ Git repository issues detected"
    fi
    
    # Test 2: SSH key exists
    if [[ -f ".claude-config/ssh-keys/claude_sync_key" ]]; then
        log "✅ SSH key present"
    else
        warn "❌ SSH key missing"
    fi
    
    # Test 3: Sync script executable
    if [[ -x "scripts/sync/claude-sync.sh" ]]; then
        log "✅ Sync script ready"
    else
        warn "❌ Sync script not executable"
    fi
    
    # Test 4: Services status
    case "$SERVICE_MANAGER" in
        "systemd")
            if systemctl --user is-active claude-file-watcher.service >/dev/null 2>&1; then
                log "✅ File watcher service active"
            else
                warn "❌ File watcher service inactive"
            fi
            ;;
        "launchd")
            if launchctl list | grep -q com.claude.filewatcher; then
                log "✅ File watcher service loaded"
            else
                warn "❌ File watcher service not loaded"
            fi
            ;;
        "cron")
            if crontab -l 2>/dev/null | grep -q claude-sync; then
                log "✅ Cron job configured"
            else
                warn "❌ Cron job not found"
            fi
            ;;
    esac
    
    # Test 5: GitHub connectivity (if key is configured)
    if ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        log "✅ GitHub SSH authentication working"
    else
        warn "❌ GitHub SSH authentication not configured"
    fi
    
    # Test 6: File watcher functionality
    TEST_FILE="test-sync-$(date +%s).tmp"
    echo "test" > "$TEST_FILE"
    sleep 2
    if [[ -f "logs/file-watcher.log" ]] && grep -q "$TEST_FILE" logs/file-watcher.log; then
        log "✅ File watcher responding to changes"
    else
        warn "❌ File watcher may not be working"
    fi
    rm -f "$TEST_FILE"
}

# Show setup results and next steps
show_results() {
    header "🎉 SETUP COMPLETE"
    
    echo -e "${GREEN}${BOLD}Claude Code Multi-Device Environment Successfully Configured!${NC}"
    echo
    
    # Show configuration summary
    echo -e "${BLUE}📋 Configuration Summary:${NC}"
    echo "   • Device: $(hostname) (${DEVICE_ROLE^^})"
    echo "   • OS: $OS"
    echo "   • Workspace: $WORKSPACE_DIR"
    echo "   • Services: $SERVICE_MANAGER"
    echo "   • Repository: $GITHUB_REPO"
    echo
    
    # Show SSH key if needed
    if [[ "$KEY_EXISTS" == false ]]; then
        echo -e "${YELLOW}🔑 ACTION REQUIRED: Add SSH Key to GitHub${NC}"
        echo "   1. Copy this SSH public key:"
        echo
        echo -e "${CYAN}$(cat "$WORKSPACE_DIR/.claude-config/ssh-keys/claude_sync_key.pub")${NC}"
        echo
        echo "   2. Add it at: https://github.com/settings/keys"
        echo "   3. Title suggestion: 'Claude-Sync-$(hostname)'"
        echo
    fi
    
    # Repository setup
    if [[ "$DEVICE_ROLE" == "primary" ]]; then
        echo -e "${YELLOW}📦 ACTION REQUIRED: Create GitHub Repository${NC}"
        echo "   1. Go to: https://github.com/new"
        echo "   2. Repository name: claude-workspace"
        echo "   3. Set as Private repository"
        echo "   4. Don't initialize with README (already exists)"
        echo
    fi
    
    # Next steps
    echo -e "${BLUE}🚀 Next Steps:${NC}"
    echo "   • Test sync: $WORKSPACE_DIR/scripts/sync/claude-sync.sh"
    echo "   • Check status: $WORKSPACE_DIR/scripts/operations/ecosystem-status.sh"
    echo "   • Start developing: claude start --workspace $WORKSPACE_DIR/projects"
    if [[ "$DEVICE_ROLE" == "primary" ]]; then
        echo "   • Setup secondary device: Run this script on your laptop"
    fi
    echo
    
    # Useful commands
    echo -e "${BLUE}🛠️ Useful Commands:${NC}"
    cat << EOF
   • Full status check:     ./scripts/operations/ecosystem-status.sh
   • Manual sync:           ./scripts/sync/manual-sync-all.sh
   • Live monitoring:       ./scripts/monitoring/live-dashboard.sh
   • Restart services:      ./scripts/operations/restart-services.sh  
   • Security audit:        ./scripts/security/audit-security.sh
   • Emergency revoke:      ./scripts/security/revoke-access.sh
EOF
    echo
    
    echo -e "${GREEN}${BOLD}🎯 Your multi-device development environment is ready!${NC}"
    echo -e "${GREEN}Claude Code can now operate autonomously across all your devices.${NC}"
    echo
}

# Main execution
main() {
    show_banner
    
    echo -e "${CYAN}This script will set up Claude Code for multi-device autonomous development.${NC}"
    echo -e "${CYAN}It will install dependencies, configure synchronization, and set up services.${NC}"
    echo
    
    read -p "Continue with setup? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Setup cancelled."
        exit 0
    fi
    
    preflight_checks
    detect_system
    detect_device_role
    install_dependencies
    setup_terminal_customization
    setup_workspace
    setup_ssh_keys
    create_sync_scripts
    setup_services
    setup_git_repository
    run_tests
    show_results
    
    echo -e "${GREEN}${BOLD}Setup completed successfully! 🚀${NC}"
}

# Run main function
main "$@"
