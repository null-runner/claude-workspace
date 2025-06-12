#!/bin/bash
# Claude Workspace - Laptop Standalone Setup
# Script completo che non dipende da repository esterno

echo "🚀 CLAUDE WORKSPACE - LAPTOP SETUP STANDALONE"
echo "=============================================="
echo ""

# Colori
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Funzione cleanup
cleanup_previous() {
    echo "🧹 CLEANUP INSTALLAZIONE PRECEDENTE"
    echo "==================================="
    
    echo "Questo rimuoverà:"
    echo "  - ~/.claude-access/"
    echo "  - ~/claude-workspace/ (se esiste)"
    echo "  - Alias dal ~/.bashrc"
    echo ""
    read -p "Procedere con il cleanup? (s/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        pkill -f "auto-sync.sh" 2>/dev/null
        rm -rf ~/.claude-access/ 2>/dev/null
        rm -rf ~/claude-workspace/ 2>/dev/null
        
        if [[ -f ~/.bashrc ]]; then
            cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
            sed -i '/# Claude Workspace Commands/,/^$/d' ~/.bashrc
        fi
        
        echo "✅ Cleanup completato!"
        echo ""
    else
        echo "❌ Cleanup annullato"
        return 1
    fi
}

# Setup principale
main_setup() {
    echo "📋 Verifica prerequisiti..."
    
    # Git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git non installato${NC}"
        echo "Installo Git automaticamente..."
        sudo apt update && sudo apt install -y git
    fi
    
    # inotify-tools
    if ! command -v inotifywait &> /dev/null; then
        echo -e "${YELLOW}⚠️ inotify-tools non installato${NC}"
        echo "Installo inotify-tools automaticamente..."
        sudo apt update && sudo apt install -y inotify-tools
    fi
    
    echo -e "${GREEN}✅ Prerequisiti OK${NC}"
    echo ""
    
    # Setup SSH key personale prima
    echo "🔑 SETUP CHIAVE SSH PERSONALE"
    echo "=============================="
    
    if [[ ! -f ~/.ssh/id_ed25519 ]]; then
        echo "Generazione chiave SSH personale..."
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519
        
        echo ""
        echo -e "${YELLOW}📋 AGGIUNGI QUESTA CHIAVE AL TUO ACCOUNT GITHUB:${NC}"
        echo "   URL: https://github.com/settings/keys"
        echo "   Nome: Laptop-$(hostname)-$(date +%Y%m%d)"
        echo ""
        echo "🔑 CHIAVE PERSONALE:"
        cat ~/.ssh/id_ed25519.pub
        echo ""
        echo "Premi ENTER dopo aver aggiunto la chiave al tuo account..."
        read
    fi
    
    # Clona repository
    echo "📥 Clonazione repository..."
    cd ~
    
    if [[ ! -d claude-workspace ]]; then
        git clone git@github.com:null-runner/claude-workspace.git
        
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}❌ Errore clonazione${NC}"
            echo "Assicurati di aver aggiunto la chiave SSH al tuo account GitHub"
            exit 1
        fi
    else
        cd claude-workspace
        git pull
    fi
    
    # Setup controllo Claude
    echo ""
    echo "🔐 Setup sistema controllo Claude..."
    mkdir -p ~/.claude-access/keys
    
    # Genera deploy key per Claude
    if [[ ! -f ~/.claude-access/keys/claude_deploy ]]; then
        ssh-keygen -t ed25519 -f ~/.claude-access/keys/claude_deploy -N "" -C "claude-workspace-$(hostname)"
        
        echo ""
        echo -e "${YELLOW}📋 AGGIUNGI QUESTA DEPLOY KEY AL REPOSITORY:${NC}"
        echo "   URL: https://github.com/null-runner/claude-workspace/settings/keys"
        echo "   Nome: Claude-Laptop-$(hostname)-$(date +%Y%m%d)"
        echo "   ✅ Allow write access"
        echo ""
        echo "🔑 DEPLOY KEY:"
        cat ~/.claude-access/keys/claude_deploy.pub
        echo ""
        echo "Premi ENTER dopo aver aggiunto la deploy key..."
        read
    fi
    
    # Setup alias
    if ! grep -q "claude-enable" ~/.bashrc; then
        echo ""
        echo "🔧 Aggiunta alias..."
        cat >> ~/.bashrc << 'EOF'

# Claude Workspace Commands
alias claude-enable="~/claude-workspace/scripts/claude-enable.sh"
alias claude-disable="~/claude-workspace/scripts/claude-disable.sh"
alias claude-status="~/claude-workspace/scripts/claude-status.sh"
alias claude-sync="~/claude-workspace/scripts/sync-now.sh"
alias claude-log="tail -f ~/claude-workspace/logs/sync.log"
alias claude-new="~/claude-workspace/scripts/claude-new.sh"
alias claude-archive="~/claude-workspace/scripts/claude-archive.sh"
alias claude-list="~/claude-workspace/scripts/claude-list.sh"
EOF
    fi
    
    # Rendi eseguibili
    chmod +x ~/claude-workspace/scripts/*.sh
    
    # Configurazione Git
    cd ~/claude-workspace
    git config pull.rebase true
    git config push.default current
    
    echo ""
    echo -e "${GREEN}✅ SETUP COMPLETATO!${NC}"
    echo ""
    echo "📌 Prossimi passi:"
    echo "   1. source ~/.bashrc"
    echo "   2. claude-enable      # Attiva il sistema"
    echo "   3. claude-status      # Verifica lo stato"
    echo ""
    echo "🔄 Il laptop ora è pronto per la sincronizzazione!"
}

# Main
if [[ -d ~/claude-workspace ]] || [[ -d ~/.claude-access ]]; then
    echo "⚠️  INSTALLAZIONE PRECEDENTE RILEVATA"
    echo "====================================="
    echo ""
    echo "Opzioni:"
    echo "1. Cleanup completo e reinstallazione pulita (consigliato)"
    echo "2. Continua con l'installazione esistente"
    echo "3. Esci"
    echo ""
    read -p "Scegli (1/2/3): " choice
    
    case $choice in
        1)
            cleanup_previous
            if [[ $? -eq 0 ]]; then
                main_setup
            fi
            ;;
        2)
            main_setup
            ;;
        3)
            echo "Installazione annullata"
            exit 0
            ;;
        *)
            echo "Scelta non valida"
            exit 1
            ;;
    esac
else
    main_setup
fi