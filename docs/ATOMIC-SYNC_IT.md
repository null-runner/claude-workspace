# Sincronizzazione Atomica Workspace - Design Tecnico

## Panoramica

Il sistema di Sincronizzazione Atomica del Workspace risolve il problema critico dei **loop infiniti** che si verificano quando si tenta di sincronizzare un workspace dove un sistema autonomo aggiorna continuamente i file ogni 30 secondi.

## Definizione del Problema

- **Sistema Autonomo**: Aggiorna file ogni 30s (detection progetti), 5min (context), 15min (intelligence)
- **Requisiti Sync**: Sincronizzazione bi-direzionale completa tra dispositivi
- **Conflitto Principale**: Operazioni di sync e sistema autonomo modificano simultaneamente lo stato del workspace
- **Risultato**: Loop infiniti, corruzione dati, fallimenti sync

## Architettura della Soluzione

### **Strategia di Coordinamento Atomico**

La soluzione implementa **Snapshot Basati su Lockfile** con **Coordinamento Code Eventi**:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Sistema        │    │   Coordinatore  │    │   Repo Remoto   │
│  Autonomo       │    │   Sync Atomico  │    │                 │
│                 │    │                 │    │                 │
│ • Context (5m)  │◄──►│ • Lock Manager  │◄──►│ • Git Remote    │
│ • Progetti (30s)│    │ • Snapshots     │    │ • Deploy Keys   │
│ • Intel (15m)   │    │ • Rollback      │    │ • Audit Trail   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Componenti Chiave**

1. **`claude-atomic-sync.sh`** - Operazioni atomiche core
2. **`claude-full-workspace-sync.sh`** - Orchestrazione sync intelligente  
3. **`claude-autonomous-system.sh` Modificato** - Awareness lockfile
4. **Sistema Snapshot** - Cattura stato atomico con rollback

## Flusso Operazioni Atomiche

### **Fase 1: Acquisizione Lock**
```bash
1. Verifica lock sync esistente → Esci se bloccato
2. Crea file lock sync con PID
3. Segnala al sistema autonomo di pausare
4. Attendi conferma sistema autonomo
```

### **Fase 2: Creazione Snapshot**
```bash
1. Crea git bundle dello stato corrente
2. Cattura modifiche non committate (diff)
3. Registra metadata (timestamp, commit hash, conteggio file)
4. Memorizza in directory snapshot atomica
```

### **Fase 3: Operazione Sync**
```bash
1. Stash modifiche non committate
2. Esegui git pull con risoluzione conflitti
3. Ripristina modifiche stashed con merge
4. Add/commit/push se esistono modifiche
```

### **Fase 4: Cleanup & Resume**
```bash
1. Rimuovi segnale pausa per sistema autonomo
2. Rilascia lock sync
3. Logga risultati operazione
4. Pulisci snapshot vecchi
```

## Meccanismi Prevenzione Conflitti

### **1. Coordinamento Lockfile**
- **Sync Lock**: `/.claude/sync/sync.lock` previene operazioni sync concorrenti
- **Segnale Pausa**: `/.claude/autonomous/sync-pause.lock` segnala al sistema autonomo di pausare
- **Protezione Timeout**: Durata pausa massima 5 minuti

### **2. Integrazione Sistema Autonomo**
Il sistema autonomo ora verifica la pausa sync prima delle operazioni sui file:

```bash
# Verifica pausa sync prima operazioni file
if check_sync_pause; then
    wait_for_sync_completion "NOME_SERVIZIO"
fi
```

### **3. Engine Decisioni Sync Intelligente**
```bash
# Decisioni sync intelligenti basate su:
- Soglia modifiche file (default: 50 file)
- Tempo dall'ultimo sync (default: 5 minuti minimo)  
- Motivo sync (startup, scheduled, manual, threshold)
- Impostazioni configurazione
```

## Esempi d'Uso

### **Operazioni Sync Manuali**
```bash
# Sync atomico base (pull + push)
./scripts/claude-atomic-sync.sh sync

# Solo pull
./scripts/claude-atomic-sync.sh pull

# Solo push  
./scripts/claude-atomic-sync.sh push

# Verifica stato
./scripts/claude-atomic-sync.sh status
```

### **Sync Intelligente con Engine Decisioni**
```bash
# Sync intelligente con motivo
./scripts/claude-full-workspace-sync.sh sync startup

# Forza sync (bypassa vincoli temporali)
./scripts/claude-full-workspace-sync.sh force-sync

# Abilita auto-sync ogni 60 minuti
./scripts/claude-full-workspace-sync.sh config enable
./scripts/claude-full-workspace-sync.sh config interval 60
./scripts/claude-full-workspace-sync.sh start-scheduler
```

### **Gestione Configurazione**
```bash
# Visualizza configurazione corrente
./scripts/claude-full-workspace-sync.sh config show

# Configura comportamento sync
./scripts/claude-full-workspace-sync.sh config enable
./scripts/claude-full-workspace-sync.sh config interval 30

# Avvia/ferma scheduler sync automatico
./scripts/claude-full-workspace-sync.sh start-scheduler
./scripts/claude-full-workspace-sync.sh stop-scheduler
```

## Meccanismi di Sicurezza

### **1. Capacità Rollback**
Ogni operazione sync crea uno snapshot atomico utilizzabile per il rollback:
```bash
# Snapshot memorizzati in /.claude/sync/snapshots/
# Formato: sync_YYYYMMDD_HHMMSS_PID.{bundle,meta,diff}
```

### **2. Recupero Errori**
- Ripristino automatico stash su fallimenti pull
- Gestione elegante timeout rete
- Preservazione modifiche non committate
- Pulizia file lock obsoleti

### **3. Audit Trail**
Logging completo di tutte le operazioni sync:
```bash
# Log sync atomico
tail -f /.claude/sync/sync.log

# Log sistema autonomo
tail -f /.claude/autonomous/autonomous-system.log
```

## Caratteristiche Performance

### **Vincoli Temporali**
- **Timeout Sync Lock**: 10 minuti massimo
- **Pausa Autonomo**: 5 minuti massimo
- **Intervallo Sync Minimo**: 5 minuti (configurabile)
- **Pulizia Snapshot**: Mantieni 10 più recenti (configurabile)

### **Uso Risorse**
- **Disco**: ~50MB per snapshot (varia per dimensione workspace)
- **Memoria**: Minima (processi background)
- **Rete**: Solo durante operazioni sync effettive
- **CPU**: Impatto basso (coordinamento pause/resume)

## Funzionalità Avanzate

### **1. Strategie Risoluzione Conflitti**
```json
{
    "conflict_resolution": {
        "strategy": "manual",           // manual, auto-ours, auto-theirs
        "auto_commit_threshold": 10     // max file per auto-commit
    }
}
```

### **2. Filtri Sync**
```json
{
    "filters": {
        "exclude_patterns": [
            "*.tmp", "*.log", ".DS_Store",
            "node_modules/", ".git/hooks/",
            ".claude/autonomous/*.pid"
        ]
    }
}
```

### **3. Monitoraggio & Alerting**
```json
{
    "monitoring": {
        "max_file_changes_before_sync": 50,
        "min_time_between_syncs": 300,
        "alert_on_sync_failure": true
    }
}
```

## Risoluzione Problemi

### **Problemi Comuni**

1. **Sync Lock Bloccato**
   ```bash
   # Stop emergenza tutte operazioni sync
   ./scripts/claude-full-workspace-sync.sh emergency-stop
   ```

2. **Sistema Autonomo Non Pausa**
   ```bash
   # Verifica stato sistema autonomo
   ./scripts/claude-autonomous-system.sh status
   
   # Riavvia sistema autonomo
   ./scripts/claude-autonomous-system.sh restart
   ```

3. **Uso Disco Snapshot**
   ```bash
   # Pulisci snapshot vecchi (mantieni ultimi 5)
   ./scripts/claude-atomic-sync.sh cleanup 5
   ```

4. **Problemi Rete/Autenticazione**
   ```bash
   # Verifica configurazione chiave SSH
   ls -la ~/.claude-access/keys/
   
   # Testa operazioni git manuali
   git pull origin main
   ```

## Punti di Integrazione

### **Sequenza Startup**
1. `claude-startup.sh` → Avvia sistema autonomo
2. `claude-full-workspace-sync.sh sync startup` → Sync iniziale
3. `claude-full-workspace-sync.sh start-scheduler` → Scheduling auto-sync

### **Sequenza Exit**  
1. `claude-autonomous-exit.sh` → Trigger sync exit
2. `claude-full-workspace-sync.sh sync exit` → Sync finale
3. `claude-full-workspace-sync.sh stop-scheduler` → Stop auto-sync

## Specifiche Tecniche

### **Struttura File**
```
/.claude/sync/
├── sync-config.json          # Configurazione
├── sync.lock                 # Lock sync attivo  
├── schedule.pid              # PID Scheduler
├── last-sync-timestamp       # Controllo timing
├── sync.log                  # Log operazioni
└── snapshots/                # Snapshot atomici
    ├── sync_20250613_195805_1234.bundle
    ├── sync_20250613_195805_1234.meta
    ├── sync_20250613_195805_1234.diff
    └── sync_20250613_195805_1234.result
```

### **Formato File Lock**
```bash
# Lock sync: /.claude/sync/sync.lock
<PID>

# Segnale pausa: /.claude/autonomous/sync-pause.lock  
<SYNC_PID>
<TIMESTAMP>
<MOTIVO>
```

### **Metadata Snapshot**
```json
{
    "snapshot_id": "sync_20250613_195805_1234",
    "timestamp": "2025-06-13T19:58:05Z",
    "git_commit": "9e015b5a1...",
    "git_status_files": 16,
    "autonomous_status": "paused"
}
```

Questo sistema di sync atomico fornisce **zero perdita dati**, **continuità sistema**, e **performance** mantenendo **semplicità** e **recuperabilità** - risolvendo il problema del loop infinito attraverso un coordinamento attento tra operazioni autonome e di sync.