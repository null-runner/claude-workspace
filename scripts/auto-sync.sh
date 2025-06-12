#!/bin/bash
# Claude Workspace - Auto Sync Script
# Monitora modifiche e sincronizza automaticamente con GitHub

# Verifica permessi
if [[ ! -f ~/.claude-access/ACTIVE ]]; then
    echo "❌ Claude non attivo. Usa: claude-enable"
    exit 1
fi

# Directory e file di configurazione
WATCH_DIR="$HOME/claude-workspace/projects"
LOG_FILE="$HOME/claude-workspace/logs/sync.log"
WORKSPACE_DIR="$HOME/claude-workspace"

# Crea log file se non esiste
mkdir -p "$(dirname "$LOG_FILE")"
touch "$LOG_FILE"

echo "[$(date)] Auto-sync avviato su $(hostname)" >> "$LOG_FILE"

# Funzione per sincronizzazione
do_sync() {
    cd "$WORKSPACE_DIR"
    
    # Pull prima di push per evitare conflitti
    echo "[$(date)] Pulling da remoto..." >> "$LOG_FILE"
    GIT_SSH_COMMAND="ssh -i ~/.claude-access/keys/claude_deploy" git pull origin main --no-edit >> "$LOG_FILE" 2>&1
    
    # Verifica se ci sono modifiche locali
    if [[ -n $(git status --porcelain) ]]; then
        echo "[$(date)] Modifiche rilevate, sincronizzazione in corso..." >> "$LOG_FILE"
        
        # Auto-save memoria prima del sync
        if [[ -f "$WORKSPACE_DIR/scripts/claude-save.sh" ]]; then
            "$WORKSPACE_DIR/scripts/claude-save.sh" "Auto-sync da $(hostname)" >/dev/null 2>&1
        fi
        
        # Pulizia intelligente memoria (una volta al giorno)
        local last_cleanup_file="$WORKSPACE_DIR/.claude/memory/.last_cleanup"
        local today=$(date +%Y-%m-%d)
        
        if [[ ! -f "$last_cleanup_file" ]] || [[ "$(cat "$last_cleanup_file" 2>/dev/null)" != "$today" ]]; then
            if [[ -f "$WORKSPACE_DIR/scripts/claude-memory-cleaner.sh" ]]; then
                echo "[$(date)] Esecuzione pulizia intelligente memoria..." >> "$LOG_FILE"
                "$WORKSPACE_DIR/scripts/claude-memory-cleaner.sh" auto >/dev/null 2>&1
                echo "$today" > "$last_cleanup_file"
                echo "[$(date)] Pulizia memoria completata" >> "$LOG_FILE"
            fi
        fi
        
        # Aggiungi tutto
        git add -A
        
        # Commit con messaggio descrittivo
        CHANGES=$(git status --porcelain | wc -l)
        git commit -m "Auto-sync: $CHANGES modifiche da $(hostname) - $(date +%Y-%m-%d_%H:%M:%S)" >> "$LOG_FILE" 2>&1
        
        # Push con deploy key
        GIT_SSH_COMMAND="ssh -i ~/.claude-access/keys/claude_deploy" git push origin main >> "$LOG_FILE" 2>&1
        
        if [[ $? -eq 0 ]]; then
            echo "[$(date)] ✅ Sync completato con successo" >> "$LOG_FILE"
        else
            echo "[$(date)] ❌ Errore durante il push" >> "$LOG_FILE"
        fi
    fi
}

# Sync iniziale
do_sync

# Monitora con inotify
echo "[$(date)] Monitoring attivo su $WATCH_DIR" >> "$LOG_FILE"

inotifywait -m -r -e modify,create,delete,move "$WATCH_DIR" \
    --exclude '\.git|\.swp|\.tmp|~$|\.#' \
    --format '%w%f %e' |
while read file event; do
    # Log evento
    echo "[$(date)] Evento: $event su $file" >> "$LOG_FILE"
    
    # Debounce - aspetta 2 secondi per aggregare modifiche multiple
    sleep 2
    
    # Esegui sync
    do_sync
done