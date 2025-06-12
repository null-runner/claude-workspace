#!/bin/bash
# Claude Workspace - Laptop Quick Setup
# Setup rapido per laptop sulla stessa rete

echo "🚀 CLAUDE WORKSPACE - LAPTOP QUICK SETUP"
echo "========================================"
echo ""
echo "Questo script può essere eseguito in 3 modi:"
echo ""
echo "1️⃣  METODO INPUTLEAP (più semplice):"
echo "   - Muovi il mouse sul laptop con InputLeap"
echo "   - Apri terminal sul laptop"
echo "   - Esegui: curl -sSL https://raw.githubusercontent.com/nullrunner/claude-workspace/main/scripts/setup-laptop.sh | bash"
echo ""
echo "2️⃣  METODO SSH (dal fisso):"
echo "   - Da qui posso connettermi via SSH al laptop"
echo "   - Copio ed eseguo automaticamente lo script"
echo ""
echo "3️⃣  METODO USB/CONDIVISIONE:"
echo "   - Genero uno script di setup"
echo "   - Lo copi sul laptop via USB o rete"
echo ""

read -p "Quale metodo vuoi usare? (1/2/3): " METHOD

case $METHOD in
    1)
        echo ""
        echo "📋 ISTRUZIONI PER INPUTLEAP:"
        echo "=============================="
        echo ""
        echo "1. Muovi il mouse sul laptop"
        echo "2. Apri un terminal"
        echo "3. Copia e incolla questo comando:"
        echo ""
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo "curl -sSL https://raw.githubusercontent.com/nullrunner/claude-workspace/main/scripts/setup-laptop.sh | bash"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
        echo "Oppure, se preferisci scaricare prima:"
        echo ""
        echo "wget https://raw.githubusercontent.com/nullrunner/claude-workspace/main/scripts/setup-laptop.sh"
        echo "chmod +x setup-laptop.sh"
        echo "./setup-laptop.sh"
        echo ""
        ;;
        
    2)
        echo ""
        echo "🌐 SETUP VIA SSH"
        echo "================"
        echo ""
        
        # Scopri laptop sulla rete
        echo "🔍 Ricerca dispositivi sulla rete locale..."
        echo "(Potrebbero volerci alcuni secondi)"
        
        # Ottieni subnet
        SUBNET=$(ip route | grep default | awk '{print $3}' | awk -F. '{print $1"."$2"."$3".0/24"}')
        echo "Scansione subnet: $SUBNET"
        
        # Cerca host attivi
        echo ""
        echo "Host trovati:"
        nmap -sn $SUBNET 2>/dev/null | grep "report for" | awk '{print $5, $6}' | nl
        
        echo ""
        read -p "Inserisci hostname o IP del laptop: " LAPTOP_HOST
        read -p "Username sul laptop (default: $USER): " LAPTOP_USER
        LAPTOP_USER=${LAPTOP_USER:-$USER}
        
        # Test connessione
        echo ""
        echo "🔗 Test connessione..."
        if ssh -o ConnectTimeout=5 ${LAPTOP_USER}@${LAPTOP_HOST} "echo 'Connessione OK'" 2>/dev/null; then
            echo "✅ Connessione riuscita!"
            
            # Copia ed esegui script
            echo "📤 Copia script sul laptop..."
            scp ~/claude-workspace/scripts/setup-laptop.sh ${LAPTOP_USER}@${LAPTOP_HOST}:/tmp/
            
            echo "🚀 Esecuzione setup..."
            ssh ${LAPTOP_USER}@${LAPTOP_HOST} "bash /tmp/setup-laptop.sh"
            
            echo ""
            echo "✅ Setup completato!"
        else
            echo "❌ Impossibile connettersi. Verifica:"
            echo "   - SSH è abilitato sul laptop"
            echo "   - Username e hostname sono corretti"
            echo "   - Sei sulla stessa rete"
        fi
        ;;
        
    3)
        echo ""
        echo "💾 GENERAZIONE SCRIPT PORTABILE"
        echo "==============================="
        echo ""
        
        # Crea bundle setup
        BUNDLE_FILE="/tmp/claude-laptop-setup-$(date +%Y%m%d_%H%M%S).sh"
        
        cat > "$BUNDLE_FILE" << 'BUNDLE_EOF'
#!/bin/bash
# Claude Workspace - Laptop Setup Bundle
# Generato automaticamente

echo "🚀 CLAUDE WORKSPACE - LAPTOP SETUP"
echo "=================================="

# Embedded setup script
setup_laptop() {
    # Clona repository
    cd ~
    if [[ ! -d claude-workspace ]]; then
        git clone https://github.com/nullrunner/claude-workspace.git
    else
        cd claude-workspace
        git pull
    fi
    
    # Crea struttura controllo
    mkdir -p ~/.claude-access/keys
    
    # Genera chiave
    ssh-keygen -t ed25519 -f ~/.claude-access/keys/claude_deploy -N "" -C "claude-workspace-$(hostname)"
    
    # Mostra chiave
    echo ""
    echo "📋 AGGIUNGI QUESTA CHIAVE SU GITHUB:"
    echo "https://github.com/nullrunner/claude-workspace/settings/keys"
    echo ""
    cat ~/.claude-access/keys/claude_deploy.pub
    echo ""
    echo "Premi ENTER dopo aver aggiunto la chiave..."
    read
    
    # Setup alias
    if ! grep -q "claude-enable" ~/.bashrc; then
        echo '
# Claude Workspace Commands
alias claude-enable="~/claude-workspace/scripts/claude-enable.sh"
alias claude-disable="~/claude-workspace/scripts/claude-disable.sh"
alias claude-status="~/claude-workspace/scripts/claude-status.sh"
alias claude-sync="cd ~/claude-workspace && git pull && git push"
' >> ~/.bashrc
    fi
    
    # Rendi eseguibili
    chmod +x ~/claude-workspace/scripts/*.sh
    
    echo ""
    echo "✅ Setup completato!"
    echo "Esegui: source ~/.bashrc && claude-enable"
}

# Esegui setup
setup_laptop
BUNDLE_EOF
        
        chmod +x "$BUNDLE_FILE"
        
        echo "✅ Script generato: $BUNDLE_FILE"
        echo ""
        echo "📋 ISTRUZIONI:"
        echo "1. Copia questo file sul laptop (USB, email, cloud, ecc.)"
        echo "2. Sul laptop esegui:"
        echo "   chmod +x $(basename $BUNDLE_FILE)"
        echo "   ./$(basename $BUNDLE_FILE)"
        echo ""
        echo "Lo script contiene tutto il necessario per il setup!"
        ;;
        
    *)
        echo "❌ Scelta non valida"
        ;;
esac