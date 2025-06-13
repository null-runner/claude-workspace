# Smart Sync System

## Overview
Il sistema Smart Sync sincronizza automaticamente il workspace Claude tra laptop e desktop basandosi sui "natural checkpoints" del tuo workflow.

## Natural Checkpoints
Il sistema rileva 4 tipi di checkpoint naturali:

### 1. Milestone Commits
- **Trigger**: Commit con pattern `add|implement|fix|complete|update|create|build`
- **Soglia**: >20 righe modificate OR file script/config modificati OR file nuovi
- **Esempio**: `"implement user authentication"` → sync automatico

### 2. Context Switches  
- **Trigger**: Cambio directory di lavoro stabile (>10 minuti)
- **Esempio**: `scripts/` → `docs/` → sync automatico

### 3. Natural Breaks
- **Trigger**: Pausa >15 minuti dopo sessione intensa (>2 commit in 1h)
- **Logica**: "Ho finito per ora, buon momento per sync"

### 4. Exit Checkpoints
- **Trigger**: `claude-smart-exit.sh` → sync sempre

## File Sincronizzati
### ✅ Sempre Sincronizzati
```bash
# File di lavoro utente
scripts/*
docs/*  
CLAUDE.md
projects/*

# Context e memoria
.claude/memory/enhanced-context.json
.claude/memory/workspace-memory.json  
.claude/memory/current-session-context.json

# Intelligence e decisioni
.claude/intelligence/auto-learnings.json
.claude/intelligence/auto-decisions.json
.claude/decisions/*

# Configurazioni
.claude/settings.local.json
```

### ❌ Mai Sincronizzati
```bash
# Stati runtime locali
.claude/autonomous/service-status.json
.claude/autonomous/*.pid

# Log verbosi  
.claude/activity/activity.log
.claude/intelligence/extraction.log
logs/*.log

# File di stato sistema
.claude/sync/
```

## Comandi
```bash
# Avvia smart sync
./scripts/claude-smart-sync.sh start

# Stato sistema
./scripts/claude-smart-sync.sh status

# Sync manuale
./scripts/claude-smart-sync.sh sync "Reason"

# Log real-time
./scripts/claude-smart-sync.sh logs

# Ferma sistema
./scripts/claude-smart-sync.sh stop
```

## Configurazione
File: `.claude/sync/config.json`
```json
{
  "milestone_commit_threshold": 20,
  "context_switch_stability": 600,
  "natural_break_inactivity": 900,
  "intense_session_threshold": 2,
  "max_syncs_per_hour": 6
}
```

## Protezioni
- **Rate Limiting**: Max 6 sync/ora
- **Loop Prevention**: Ignora propri commit "Smart sync:"
- **Git Protection**: File sistema esclusi da tracking
- **Failure Recovery**: Retry automatico con backoff

## Workflow Tipico
1. Lavori su script → modifiche auto-rilevate
2. Fai commit significativo → **trigger sync**
3. Cambi a documentazione → **trigger sync** 
4. Pausa lavoro >15min → **trigger sync**
5. Esci con `claude-smart-exit.sh` → **trigger sync**

Il sistema garantisce che laptop e desktop siano sempre sincronizzati sui tuoi checkpoint naturali di lavoro!