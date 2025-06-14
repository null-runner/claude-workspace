#!/bin/bash
# Claude Workspace - Disable Script
# Disattiva l'accesso di Claude Code al workspace

echo "🔴 DISATTIVAZIONE CLAUDE CODE..."
echo "================================="

# Rimuovi flag attivazione
rm -f ~/.claude-access/ACTIVE

# Reset configurazione Git
cd ~/claude-workspace
git config --unset core.sshCommand
git config --unset user.name
git config --unset user.email

# Ferma auto-sync
if pgrep -f "auto-sync.sh" > /dev/null; then
    echo "🛑 Arresto auto-sync..."
    pkill -f "auto-sync.sh"
    echo "✅ Auto-sync fermato"
fi

# Ferma servizio systemd se esiste
systemctl --user stop claude-sync 2>/dev/null

# Log disattivazione
echo "[$(date)] Claude disattivato su $(hostname)" >> ~/.claude-access/audit.log

echo ""
echo "✅ ACCESSI REVOCATI"
echo ""
echo "📌 Note:"
echo "   - Deploy key ancora presente su GitHub (rimuovila manualmente se necessario)"
echo "   - Chiavi locali ancora in ~/.claude-access/keys/"
echo "   - Per rimuovere tutto: rm -rf ~/.claude-access"
echo ""
echo "🔐 Per riattivare: claude-enable"