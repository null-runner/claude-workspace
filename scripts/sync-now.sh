#!/bin/bash
# Claude Workspace - Sync Now Script
# Forza una sincronizzazione immediata

WORKSPACE_DIR="$HOME/claude-workspace"
LOCK_SCRIPT="$WORKSPACE_DIR/scripts/claude-sync-lock.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Source shared locking mechanism with detection
if [[ -f "$LOCK_SCRIPT" ]]; then
    # Temporarily override arguments to prevent lock script from executing its CLI
    ORIGINAL_ARGS=("$@")
    set -- "source-mode"
    source "$LOCK_SCRIPT" >/dev/null 2>&1 || true
    set -- "${ORIGINAL_ARGS[@]}"
else
    echo -e "${RED}ERROR: Sync lock script not found: $LOCK_SCRIPT${NC}" >&2
    exit 1
fi

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

# Check if sync coordinator is available
COORDINATOR_SCRIPT="$WORKSPACE_DIR/scripts/claude-sync-coordinator.sh"

if [[ -x "$COORDINATOR_SCRIPT" ]]; then
    echo "🔄 Utilizzando coordinatore sync per sincronizzazione sicura..."
    
    # Request immediate sync through coordinator
    if "$COORDINATOR_SCRIPT" request-sync manual "sync-now" "high" "Manual sync request"; then
        echo ""
        echo "✅ Sincronizzazione coordinata completata!"
        
        # Show recent commits
        echo ""
        echo "📝 Ultimi 5 commit:"
        git log --oneline -5
        exit 0
    else
        echo -e "${RED}❌ Sincronizzazione coordinata fallita${NC}"
        echo "Ritorno alla modalità tradizionale..."
        echo ""
    fi
fi

# Fallback to traditional sync if coordinator not available or failed
echo "⚠️  Usando modalità sync tradizionale..."

# Check if sync is already running
if is_sync_locked; then
    echo -e "${YELLOW}⚠️  Sync già in corso da altro processo...${NC}"
    echo "Attendo il completamento (massimo 60 secondi)..."
    
    if wait_for_lock_release 60; then
        echo -e "${GREEN}✅ Sync precedente completato, procedo...${NC}"
    else
        echo -e "${RED}❌ Timeout - sync precedente non completato${NC}"
        echo "Vuoi forzare la sincronizzazione? (ATTENZIONE: potrebbe causare conflitti)"
        read -p "Continua comunque? (s/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            echo "Operazione annullata"
            exit 1
        fi
        echo -e "${YELLOW}⚠️  Forzando sincronizzazione...${NC}"
    fi
fi

# Acquire sync lock
echo "🔒 Acquisizione lock di sincronizzazione..."
if ! acquire_sync_lock 30 "sync-now"; then
    echo -e "${RED}❌ Impossibile acquisire lock di sincronizzazione${NC}"
    exit 1
fi

# Setup cleanup trap
setup_lock_cleanup "sync-now"

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
        
        # Commit (set env var to skip auto-push hook)
        export AUTOMATED_SYNC=1
        git commit -m "$COMMIT_MSG"
        unset AUTOMATED_SYNC
        
        # Push
        echo ""
        echo "📤 Push su remoto..."
        if [[ "$USE_DEPLOY_KEY" == true ]]; then
            if GIT_SSH_COMMAND="ssh -i ~/.claude-access/keys/claude_deploy" git push origin main; then
                echo ""
                echo "✅ Sincronizzazione completata!"
                release_sync_lock "sync-now"
            else
                echo -e "${RED}❌ Errore durante il push${NC}"
                release_sync_lock "sync-now"
                exit 1
            fi
        else
            if git push origin main; then
                echo ""
                echo "✅ Sincronizzazione completata!"
                release_sync_lock "sync-now"
            else
                echo -e "${RED}❌ Errore durante il push${NC}"
                release_sync_lock "sync-now"
                exit 1
            fi
        fi
    else
        echo ""
        echo "❌ Sincronizzazione annullata"
        release_sync_lock "sync-now"
    fi
else
    echo ""
    echo "✅ Nessuna modifica locale da sincronizzare"
    release_sync_lock "sync-now"
fi

# Mostra ultimi commit
echo ""
echo "📝 Ultimi 5 commit:"
git log --oneline -5