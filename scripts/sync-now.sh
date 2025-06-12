#!/bin/bash
# Claude Workspace - Sync Now Script
# Forza una sincronizzazione immediata

echo "🔄 SINCRONIZZAZIONE MANUALE"
echo "==========================="

# Verifica se Claude è attivo
if [[ ! -f ~/.claude-access/ACTIVE ]]; then
    echo "⚠️  Claude non attivo. Uso modalità manuale..."
    USE_DEPLOY_KEY=false
else
    USE_DEPLOY_KEY=true
fi

cd ~/claude-workspace

# Pull da remoto
echo "📥 Pull da remoto..."
if [[ "$USE_DEPLOY_KEY" == true ]]; then
    GIT_SSH_COMMAND="ssh -i ~/.claude-access/keys/claude_deploy" git pull origin main --no-edit
else
    git pull origin main --no-edit
fi

# Mostra stato
echo ""
echo "📊 Stato attuale:"
git status --short

# Se ci sono modifiche locali
if [[ -n $(git status --porcelain) ]]; then
    echo ""
    echo "📝 Modifiche locali trovate:"
    git diff --stat
    
    echo ""
    read -p "Vuoi committare e pushare queste modifiche? (s/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        # Aggiungi tutto
        git add -A
        
        # Chiedi messaggio commit
        echo ""
        echo "Inserisci messaggio di commit (ENTER per messaggio automatico):"
        read -r COMMIT_MSG
        
        if [[ -z "$COMMIT_MSG" ]]; then
            COMMIT_MSG="Manual sync da $(hostname) - $(date +%Y-%m-%d_%H:%M:%S)"
        fi
        
        # Commit
        git commit -m "$COMMIT_MSG"
        
        # Push
        echo ""
        echo "📤 Push su remoto..."
        if [[ "$USE_DEPLOY_KEY" == true ]]; then
            GIT_SSH_COMMAND="ssh -i ~/.claude-access/keys/claude_deploy" git push origin main
        else
            git push origin main
        fi
        
        echo ""
        echo "✅ Sincronizzazione completata!"
    else
        echo ""
        echo "❌ Sincronizzazione annullata"
    fi
else
    echo ""
    echo "✅ Nessuna modifica locale da sincronizzare"
fi

# Mostra ultimi commit
echo ""
echo "📝 Ultimi 5 commit:"
git log --oneline -5