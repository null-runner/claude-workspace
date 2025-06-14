**Lingua:** [🇺🇸 English](memory-system-en.md) | [🇮🇹 Italiano](memory-system-it.md)

# 🧠 Sistema Coordinatore Memoria Enterprise - Claude Workspace

## 📖 Panoramica

Il **coordinatore memoria unificato** di Claude Workspace fornisce gestione memoria enterprise-grade con continuità perfetta tra sessioni e progetti. Il sistema presenta **operazioni atomiche**, **file locking**, **caching intelligente** e **recovery automatico** - offrendo affidabilità enterprise con zero overhead di manutenzione.

## 🏗️ Architettura Enterprise

### Struttura Coordinatore Memoria Unificato
```
.claude/
├── memory-coordination/       # NUOVO: Coordinatore enterprise
│   ├── coordinator.log       # Log attività coordinamento
│   ├── health-status.json    # Monitoraggio salute sistema
│   └── locks/               # Directory file locking
├── memory/                   # Gestito dal coordinatore
│   ├── workspace-memory.json # Memoria globale workspace
│   ├── unified-context.json  # Cache context unificato
│   └── projects/             # Memoria specifica progetto
│       ├── active_sito-bar.json
│       ├── sandbox_test-app.json
│       └── production_api.json
└── backups/                  # Rotazione backup automatica
    └── memory/              # Backup memoria con retention
```

### Funzionalità Coordinatore Memoria Enterprise
Il **coordinatore unificato** gestisce tutti i tipi memoria con:
- **Operazioni Atomiche**: File locking previene corruzione durante accesso concorrente
- **Protezione Processi**: Prevenzione deadlock e coordinamento processi
- **Caching Intelligente**: Accesso memoria ottimizzato per performance con prefetching smart
- **Risoluzione Conflitti**: Gestione avanzata conflitti memoria cross-device
- **Recovery Automatico**: Rilevamento errori e capacità rollback enterprise-grade
- **Automazione Backup**: Rotazione automatica con retention policies configurabili

### Memoria Per-Progetto
Ogni progetto mantiene (gestito dal coordinatore):
- **Stato corrente**: ultima attività, file attivi, note recenti
- **Storico sessioni**: cronologia del lavoro  
- **TODO e obiettivi**: task attivi e completati
- **Note tecniche**: setup, architettura, dipendenze
- **Dati archiviati**: informazioni compattate intelligentemente

## 🔄 Sistema Pulizia Intelligente

### Cosa Mantiene SEMPRE (Core Memory)
- ✅ **Stato corrente progetto** (ultimo salvataggio)
- ✅ **Obiettivo principale** e milestone corrente
- ✅ **TODO attivi** (non completati)
- ✅ **Note tecniche** (architettura, setup)
- ✅ **File principali** esistenti

### Cosa Pulisce Gradualmente (Sliding Memory)
- 🔄 **Storico sessioni**: mantiene ultime 20 → compatta le vecchie
- 🔄 **Note temporanee**: mantiene ultime 10 → archivia quelle importanti
- 🔄 **TODO completati**: mantiene ultimi 15 → statistiche archiviate
- 🔄 **File attivi**: verifica esistenza → rimuove file eliminati

### Algoritmo Compattazione
1. **Analizza pattern**: rileva comportamenti ricorrenti
2. **Estrae informazioni chiave**: note importanti, milestone raggiunte
3. **Crea summary**: riassunti delle sessioni archiviate
4. **Mantiene metriche**: statistiche di completamento
5. **Preserva contesto**: informazioni essenziali per continuità

## 📱 Comandi Enterprise

### Coordinatore Memoria Unificato
```bash
# Controllo coordinatore principale
claude-memory-coordinator start       # Avvia coordinatore unificato
claude-memory-coordinator stop        # Ferma coordinatore
claude-memory-coordinator status      # Controlla stato coordinatore
claude-memory-coordinator health      # Controllo salute tutti i servizi
claude-memory-coordinator restart     # Riavvia con cleanup

# Performance e ottimizzazione
claude-memory-coordinator optimize    # Ottimizza cache e performance
claude-memory-coordinator cache-stats # Visualizza statistiche cache
claude-memory-coordinator cache-refresh # Aggiorna cache
```

### Gestione Memoria (Migliorata)
```bash
# Memoria globale (gestita da coordinatore)
claude-save "nota sessione"           # Salva stato corrente (atomico)
claude-resume                         # Riprende ultima sessione (cached)
claude-memory context "obiettivo"     # Aggiorna obiettivi (locked)

# Memoria progetto (enterprise-grade)
claude-project-memory save "nota"     # Salva stato progetto (atomico)
claude-project-memory resume          # Riprende progetto (cached)
claude-project-memory todo add "task" # Aggiunge TODO (coordinato)
claude-project-memory todo list       # Lista TODO (performance-ottimizzato)
claude-project-memory todo done 1     # Completa TODO (aggiornamento atomico)
```

### Gestione Enterprise
```bash
# Integrità e recovery
claude-memory-coordinator integrity-check  # Verifica integrità memoria
claude-memory-coordinator auto-recover     # Recovery automatico errori
claude-memory-coordinator manual-recover   # Recovery manuale con opzioni

# Gestione backup  
claude-backup-cleaner status               # Visualizza stato backup
claude-backup-cleaner clean                # Pulisce backup vecchi
claude-backup-cleaner set-retention 60     # Imposta retention (giorni)

# Pulizia legacy (ancora disponibile)
claude-memory-cleaner auto                 # Pulizia automatica
claude-memory-cleaner stats                # Statistiche memoria
```

## 🤖 Automazione Enterprise

### Auto-Save Coordinatore Unificato
- **Trigger**: modifiche file rilevate dal coordinatore
- **Metodo**: operazioni atomiche con file locking
- **Scope**: gestione unificata (memoria globale + progetto + sessione)
- **Performance**: caching intelligente e operazioni batch
- **Affidabilità**: risoluzione automatica conflitti e validazione integrità

### Auto-Cleanup Enterprise
- **Frequenza**: configurabile (default: giornaliera)
- **Intelligenza**: riconoscimento pattern avanzato preserva informazioni critiche
- **Coordinamento**: pulizia unificata su tutti i tipi memoria
- **Performance**: operazioni batch ottimizzate riducono overhead I/O
- **Integrazione Backup**: backup automatico prima operazioni pulizia
- **Soglie**: 
  - File > 50KB → compattazione intelligente con backup
  - Ultima pulizia > 7 giorni → ricompattazione forzata con controllo integrità
  - Corruzione memoria rilevata → recovery automatico

### Rotazione Backup Automatica
- **Pianificazione**: retention policies configurabili (default: 30 giorni)
- **Compressione**: efficiente con deduplicazione
- **Verifica**: controlli integrità automatici sui backup
- **Pulizia**: rimozione automatica backup scaduti
- **Recovery**: ripristino one-command da qualsiasi punto backup

## 💾 Formato Dati

### Memoria Progetto Esempio
```json
{
  "project_info": {
    "name": "sito-bar",
    "type": "active", 
    "created_at": "2025-06-13T01:00:00Z"
  },
  "current_context": {
    "last_activity": "2025-06-13T01:30:00Z",
    "current_task": "Implementazione menu",
    "active_files": ["index.html", "menu.css"],
    "notes": [
      {
        "content": "Completata homepage, ora faccio menu",
        "timestamp": "2025-06-13T01:30:00Z"
      }
    ],
    "todo": [
      {
        "id": 1,
        "description": "Aggiungere form contatti",
        "status": "pending"
      }
    ]
  },
  "session_history": [...],
  "archived_data": {
    "session_summaries": [...],
    "important_notes": [...],
    "completion_stats": {...}
  }
}
```

## 🎯 Workflow Tipico

### Inizio Sessione
```bash
# Sul fisso
claude-resume                     # Vede ultimo progetto
cd ~/claude-workspace/projects/active/sito-bar
claude-project-memory resume     # Context specifico progetto
```

### Durante Lavoro
```bash
# Auto-save automatico ad ogni modifica
# Oppure manuale:
claude-project-memory save "Completato header"
claude-project-memory todo add "Testare responsive"
```

### Fine Sessione
```bash
claude-save "Domani implementare carrello"
claude-project-memory save "Menu completato, manca solo footer"
```

### Ripresa su Laptop
```bash
# Sul laptop (dopo sync automatico)
claude-resume                     # Vede: "Domani implementare carrello"
cd ~/claude-workspace/projects/active/sito-bar  
claude-project-memory resume     # Vede: "Menu completato, manca solo footer"
```

## 🔧 Configurazione

### Impostazioni Pulizia
Modifica `.claude/memory/workspace-memory.json`:
```json
{
  "settings": {
    "auto_save_interval": 300,        # secondi tra auto-save
    "max_history_days": "infinite",   # ritenzione base
    "context_retention": "detailed",  # livello dettaglio
    "cleanup_frequency": "daily"      # frequenza pulizia
  }
}
```

### Soglie Compattazione
Modifica `scripts/claude-memory-cleaner.sh`:
```bash
# Soglie per compattazione
MAX_SESSIONS=20          # sessioni per progetto
MAX_NOTES=10            # note temporanee
MAX_COMPLETED_TODOS=15  # TODO completati
MAX_FILE_SIZE=50000     # bytes prima compattazione
```

## 🛠️ Manutenzione

### Backup Memoria
```bash
# Backup completo
cp -r .claude/memory .claude/memory.backup.$(date +%Y%m%d)

# Backup specifico progetto
cp .claude/memory/projects/active_sito-bar.json /backup/
```

### Ripristino
```bash
# Ripristina da backup
cp -r .claude/memory.backup.20250613 .claude/memory

# Ripristina progetto specifico
cp /backup/active_sito-bar.json .claude/memory/projects/
```

### Debug
```bash
# Verifica stato memoria
claude-memory-cleaner stats

# Controlla log pulizia
tail -f logs/sync.log | grep "memoria"

# Test compattazione singolo progetto
claude-memory-cleaner project active/sito-bar
```

## 🚨 Risoluzione Problemi

### Memoria Corrotta
```bash
# Reset completo (ATTENZIONE: cancella tutto)
rm -rf .claude/memory
claude-save "Reinizializzazione memoria"
```

### Progetto Non Rilevato
```bash
# Verifica path
pwd  # Deve essere in ~/claude-workspace/projects/tipo/nome

# Inizializza manualmente
claude-project-memory save "Inizializzazione manuale"
```

### Pulizia Non Funziona
```bash
# Forza pulizia
claude-memory-cleaner auto --force

# Verifica permessi
ls -la .claude/memory/
chmod 755 .claude/memory/
```

## 📊 Monitoraggio

### Metriche Chiave
- **Dimensione memoria totale**: < 10MB consigliato
- **Progetti attivi**: memoria < 100KB per progetto
- **Frequenza cleanup**: 1 volta al giorno
- **Ratio compattazione**: ~70% riduzione dopo cleanup

### Alert Automatici
Il sistema avvisa quando:
- Memoria progetto > 200KB (suggerisce pulizia)
- Memoria totale > 20MB (pulizia forzata)
- Ultima pulizia > 14 giorni (pulizia programmata)

## 🎯 Best Practices

### Per Performance
- ✅ Usa `claude-save` con note descrittive
- ✅ Completa TODO quando finiti  
- ✅ Lascia che la pulizia automatica lavori
- ❌ Non disabilitare auto-cleanup
- ❌ Non accumulare file attivi inesistenti

### Per Continuità
- ✅ Salva sempre prima di switchare progetto
- ✅ Usa note tecniche per setup complessi
- ✅ Mantieni obiettivi aggiornati
- ✅ Documenta decisioni architetturali importanti

## 🚀 Performance & Affidabilità Enterprise

Il **coordinatore memoria unificato** offre performance e affidabilità enterprise-grade:

### Funzionalità Performance
- **Caching Intelligente**: Sistema caching multi-livello con smart prefetching
- **Operazioni Atomiche**: File locking garantisce accesso concorrente sicuro
- **Elaborazione Batch**: Operazioni bulk ottimizzate riducono overhead I/O
- **Lazy Loading**: Carica solo componenti memoria richiesti on demand
- **Ottimizzazione Background**: Tuning performance continuo e gestione cache

### Funzionalità Affidabilità
- **File Locking**: Previene corruzione durante accesso concorrente
- **Protezione Processi**: Prevenzione deadlock e coordinamento processi
- **Recovery Automatico**: Rilevamento errori e rollback enterprise-grade
- **Monitoraggio Integrità**: Validazione continua consistenza memoria
- **Automazione Backup**: Rotazione automatica con retention policies configurabili

### Vantaggi Enterprise
- **Zero Perdita Dati**: Operazioni atomiche e backup automatici garantiscono sicurezza dati
- **Alta Performance**: Caching intelligente e ottimizzazioni offrono operazioni veloci
- **Scalabilità**: Gestisce progetti grandi e dispositivi concorrenti multipli
- **Affidabilità**: Meccanismi gestione errori e recovery enterprise-grade
- **Maintenance-Free**: Completamente automatizzato con auto-gestione intelligente

Perfetto per sviluppatori che richiedono **affidabilità enterprise** con **zero overhead manutenzione**!

Il **coordinatore memoria enterprise** garantisce continuità perfetta tra sessioni offrendo **performance e affidabilità enterprise-grade**! 🚀