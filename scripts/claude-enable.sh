#!/bin/bash
# Claude Workspace - Enable Script
# Attiva l'accesso di Claude Code al workspace

echo "🟢 ATTIVAZIONE CLAUDE CODE..."
echo "================================"

# Crea flag attivazione
touch ~/.claude-access/ACTIVE

# Configura Git per usare deploy key
cd ~/claude-workspace
git config core.sshCommand "ssh -i ~/.claude-access/keys/claude_deploy"
git config user.name "Claude Code"
git config user.email "claude@nullrunner.local"

# Mostra deploy key
echo ""
echo "📋 AGGIUNGI QUESTA DEPLOY KEY SU GITHUB:"
echo "   URL: https://github.com/nullrunner/claude-workspace/settings/keys"
echo "   Nome: Claude-$(hostname)-$(date +%Y%m%d)"
echo "   Permessi: ✅ Allow write access"
echo ""
echo "🔑 CHIAVE PUBBLICA:"
echo "-------------------"
cat ~/.claude-access/keys/claude_deploy.pub
echo "-------------------"

# Log attivazione
echo "[$(date)] Claude attivato su $(hostname) da $(whoami)" >> ~/.claude-access/audit.log

# Verifica se auto-sync è già in esecuzione
if pgrep -f "auto-sync.sh" > /dev/null; then
    echo ""
    echo "🔄 Auto-sync già attivo"
else
    echo ""
    echo "🚀 Avvio auto-sync in background..."
    nohup ~/claude-workspace/scripts/auto-sync.sh >> ~/claude-workspace/logs/sync.log 2>&1 &
    echo "✅ Auto-sync avviato (PID: $!)"
fi

echo ""
echo "✅ CLAUDE CODE ATTIVATO!"
echo ""
echo "📌 Comandi disponibili:"
echo "   claude-disable  → Disattiva accessi"
echo "   claude-status   → Verifica stato"
echo "   claude-sync     → Forza sincronizzazione"
echo "   claude-log      → Visualizza log sync"