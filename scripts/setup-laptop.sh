#!/bin/bash
# Claude Workspace - Setup Laptop Script
# Configura automaticamente il laptop come client del workspace

echo "🚀 CLAUDE WORKSPACE - SETUP LAPTOP"
echo "=================================="
echo ""

# Colori per output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Funzione per verificare prerequisiti
check_prerequisites() {
    echo "📋 Verifica prerequisiti..."
    
    # Git
    if ! command -v git &> /dev/null; then
        echo -e "${RED}❌ Git non installato${NC}"
        echo "   Installa con: sudo apt install git"
        exit 1
    fi
    
    # inotify-tools
    if ! command -v inotifywait &> /dev/null; then
        echo -e "${YELLOW}⚠️  inotify-tools non installato${NC}"
        echo "   Installazione automatica..."
        sudo apt update && sudo apt install -y inotify-tools
    fi
    
    echo -e "${GREEN}✅ Prerequisiti OK${NC}"
}

# Setup principale
main_setup() {
    # 1. Clona repository se non esiste
    if [[ ! -d ~/claude-workspace ]]; then
        echo ""
        echo "📥 Clonazione repository..."
        cd ~
        git clone git@github.com:nullrunner/claude-workspace.git
        
        if [[ $? -ne 0 ]]; then
            echo -e "${RED}❌ Errore clonazione. Verifica di avere accesso al repository.${NC}"
            echo "   Aggiungi la tua chiave SSH su GitHub prima di procedere."
            exit 1
        fi
    else
        echo -e "${YELLOW}📁 Directory claude-workspace già esistente${NC}"
        cd ~/claude-workspace
        git pull origin main
    fi
    
    # 2. Crea sistema di controllo locale
    echo ""
    echo "🔐 Creazione sistema di controllo..."
    mkdir -p ~/.claude-access/keys
    
    # 3. Genera chiave deploy per laptop
    if [[ ! -f ~/.claude-access/keys/claude_deploy ]]; then
        ssh-keygen -t ed25519 -f ~/.claude-access/keys/claude_deploy -N "" -C "claude-workspace-$(hostname)"
        
        echo ""
        echo -e "${YELLOW}📋 IMPORTANTE: Aggiungi questa deploy key su GitHub:${NC}"
        echo "   URL: https://github.com/nullrunner/claude-workspace/settings/keys"
        echo "   Nome: Claude-Laptop-$(hostname)-$(date +%Y%m%d)"
        echo ""
        echo "🔑 CHIAVE:"
        cat ~/.claude-access/keys/claude_deploy.pub
        echo ""
        echo -e "${YELLOW}Premi ENTER dopo aver aggiunto la chiave...${NC}"
        read
    fi
    
    # 4. Copia configurazioni
    cp ~/.claude-access/permissions.json ~/.claude-access/permissions.json.bak 2>/dev/null
    
    # 5. Setup alias
    if ! grep -q "claude-enable" ~/.bashrc; then
        echo ""
        echo "🔧 Aggiunta alias..."
        cat >> ~/.bashrc << 'EOF'

# Claude Workspace Commands
alias claude-enable="~/claude-workspace/scripts/claude-enable.sh"
alias claude-disable="~/claude-workspace/scripts/claude-disable.sh"
alias claude-status="~/claude-workspace/scripts/claude-status.sh"
alias claude-sync="cd ~/claude-workspace && git pull && git push"
alias claude-log="tail -f ~/claude-workspace/logs/sync.log"
EOF
    fi
    
    # 6. Rendi eseguibili gli script
    chmod +x ~/claude-workspace/scripts/*.sh
    
    # 7. Configura sync bidirezionale
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
    echo "🔄 Il laptop ora si sincronizzerà automaticamente con il fisso!"
}

# Setup tramite SSH dal fisso (opzionale)
remote_setup() {
    echo ""
    echo "🌐 SETUP REMOTO LAPTOP"
    echo "====================="
    echo ""
    echo "Inserisci l'hostname o IP del laptop:"
    read -p "> " LAPTOP_HOST
    
    echo "Inserisci username sul laptop (default: $USER):"
    read -p "> " LAPTOP_USER
    LAPTOP_USER=${LAPTOP_USER:-$USER}
    
    # Copia script sul laptop
    echo "📤 Copia script sul laptop..."
    scp $0 ${LAPTOP_USER}@${LAPTOP_HOST}:/tmp/setup-laptop.sh
    
    # Esegui setup remoto
    echo "🚀 Esecuzione setup remoto..."
    ssh ${LAPTOP_USER}@${LAPTOP_HOST} "bash /tmp/setup-laptop.sh --local"
}

# Gestione parametri
if [[ "$1" == "--remote" ]]; then
    remote_setup
elif [[ "$1" == "--local" ]] || [[ -z "$1" ]]; then
    check_prerequisites
    main_setup
else
    echo "Uso: $0 [--local|--remote]"
    echo "  --local   Setup locale (default)"
    echo "  --remote  Setup remoto via SSH"
fi