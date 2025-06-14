#!/bin/bash
# Claude Workspace - Status Script
# Mostra lo stato corrente del sistema Claude

echo "╔══════════════════════════════════════╗"
echo "║      CLAUDE WORKSPACE STATUS         ║"
echo "╚══════════════════════════════════════╝"
echo ""

# Status Bar compatta
~/claude-workspace/scripts/claude-status-bar.sh
echo ""

# Verifica stato attivazione
if [[ -f ~/.claude-access/ACTIVE ]]; then
    echo "🟢 STATO: ATTIVO"
    echo ""
    
    # Mostra info chiavi
    if [[ -f ~/.claude-access/keys/claude_deploy ]]; then
        echo "🔑 Deploy Key: Presente"
        FINGERPRINT=$(ssh-keygen -lf ~/.claude-access/keys/claude_deploy.pub | awk '{print $2}')
        echo "   Fingerprint: ${FINGERPRINT:0:16}..."
    else
        echo "⚠️  Deploy Key: MANCANTE!"
    fi
    
    # Verifica configurazione Git
    cd ~/claude-workspace
    SSH_CMD=$(git config --get core.sshCommand 2>/dev/null)
    if [[ -n "$SSH_CMD" ]]; then
        echo "✅ Git configurato per deploy key"
    else
        echo "⚠️  Git non configurato!"
    fi
    
    # Verifica auto-sync
    if pgrep -f "auto-sync.sh" > /dev/null; then
        SYNC_PID=$(pgrep -f "auto-sync.sh")
        echo "🔄 Auto-sync: Attivo (PID: $SYNC_PID)"
    else
        echo "⏸️  Auto-sync: Non attivo"
    fi
else
    echo "🔴 STATO: DISATTIVATO"
    echo ""
    echo "💡 Per attivare: claude-enable"
fi

echo ""
echo "📊 STATISTICHE WORKSPACE:"
echo "─────────────────────────"

# Conta progetti
SANDBOX_COUNT=$(ls ~/claude-workspace/projects/sandbox 2>/dev/null | wc -l || echo "0")
ACTIVE_COUNT=$(ls ~/claude-workspace/projects/active 2>/dev/null | wc -l || echo "0")
PROD_COUNT=$(ls ~/claude-workspace/projects/production 2>/dev/null | wc -l || echo "0")

echo "📁 Progetti Sandbox:    $SANDBOX_COUNT"
echo "📁 Progetti Attivi:     $ACTIVE_COUNT"
echo "📁 Progetti Production: $PROD_COUNT"

# Ultimo sync
if [[ -f ~/claude-workspace/logs/sync.log ]]; then
    LAST_SYNC=$(tail -n 1 ~/claude-workspace/logs/sync.log | grep "Sync completato" | awk '{print $1, $2}' | tr -d '[]')
    if [[ -n "$LAST_SYNC" ]]; then
        echo ""
        echo "🕐 Ultimo sync: $LAST_SYNC"
    fi
fi

# Ultimi commit
echo ""
echo "📝 ULTIMI COMMIT:"
echo "─────────────────"
cd ~/claude-workspace
git log --oneline -5 2>/dev/null || echo "Nessun commit trovato"

# Audit log recenti
if [[ -f ~/.claude-access/audit.log ]]; then
    echo ""
    echo "🔍 ATTIVITÀ RECENTI:"
    echo "───────────────────"
    tail -n 3 ~/.claude-access/audit.log
fi