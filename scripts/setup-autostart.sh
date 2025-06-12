#!/bin/bash
# Claude Workspace - Setup Auto-start
# Configura l'avvio automatico di auto-sync su WSL

BASHRC_FILE="$HOME/.bashrc"
WORKSPACE_DIR="$HOME/claude-workspace"

echo "🔧 SETUP AUTO-START CLAUDE WORKSPACE"
echo "====================================="

# Verifica che claude-workspace esista
if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "❌ Claude Workspace non trovato in $WORKSPACE_DIR"
    echo "💡 Prima esegui setup del workspace"
    exit 1
fi

# Controlla se auto-start è già configurato
if grep -q "Claude Workspace Auto-start" "$BASHRC_FILE" 2>/dev/null; then
    echo "✅ Auto-start già configurato in .bashrc"
    echo ""
    echo "🔍 Vuoi riconfigurare? (y/n)"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "⏩ Mantengo configurazione esistente"
        exit 0
    fi
    
    # Rimuovi configurazione esistente
    echo "🧹 Rimuovo configurazione esistente..."
    sed -i '/# Claude Workspace Auto-start/,/^$/d' "$BASHRC_FILE"
fi

# Aggiungi configurazione auto-start
echo "📝 Aggiungo auto-start a .bashrc..."

cat >> "$BASHRC_FILE" << 'EOF'

# Claude Workspace Auto-start
# Avvia automaticamente auto-sync se Claude è attivo
if [[ -f ~/claude-workspace/scripts/claude-autostart.sh ]]; then
    # Esegui in background per non rallentare l'apertura del terminale
    (~/claude-workspace/scripts/claude-autostart.sh auto &) 2>/dev/null
fi

# Alias per comandi Claude Workspace
if [[ -d ~/claude-workspace/scripts ]]; then
    alias claude-enable='~/claude-workspace/scripts/claude-enable.sh'
    alias claude-disable='~/claude-workspace/scripts/claude-disable.sh'
    alias claude-save='~/claude-workspace/scripts/claude-save.sh'
    alias claude-resume='~/claude-workspace/scripts/claude-resume.sh'
    alias claude-project-memory='~/claude-workspace/scripts/claude-project-memory.sh'
    alias claude-memory-cleaner='~/claude-workspace/scripts/claude-memory-cleaner.sh'
    alias claude-autostart='~/claude-workspace/scripts/claude-autostart.sh'
    alias claude-status='~/claude-workspace/scripts/claude-autostart.sh status'
fi
EOF

echo "✅ Auto-start configurato!"
echo ""
echo "📋 COSA SUCCEDE ORA:"
echo "  🔄 Ogni volta che apri WSL, se Claude è attivo:"
echo "     • Auto-sync si avvia automaticamente in background"
echo "     • Monitora i file e sincronizza su GitHub"
echo "     • Salva automaticamente la memoria"
echo ""
echo "🎮 COMANDI DISPONIBILI:"
echo "  claude-status      # Controlla se auto-sync è attivo"
echo "  claude-autostart   # Gestisci manualmente auto-sync"
echo "  claude-enable      # Attiva Claude (se non attivo)"
echo ""
echo "🔄 Per attivare subito i nuovi alias:"
echo "  source ~/.bashrc"
echo ""
echo "🧪 TESTA ORA:"
echo "  1. source ~/.bashrc"
echo "  2. claude-status"
echo "  3. Se Claude non è attivo: claude-enable"

# Rendi eseguibile claude-autostart se non lo è già
chmod +x "$WORKSPACE_DIR/scripts/claude-autostart.sh" 2>/dev/null

echo ""
echo "✅ Setup auto-start completato!"