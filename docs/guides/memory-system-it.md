**Lingua:** [🇺🇸 English](memory-system-en.md) | [🇮🇹 Italiano](memory-system-it.md)

# 🧠 Sistema Memoria Intelligente Claude Workspace

## 📖 Panoramica

Il sistema di memoria di Claude Workspace fornisce continuità tra sessioni e progetti, mantenendo il contesto senza ingolfare il sistema grazie a una pulizia intelligente automatica.

## 🏗️ Architettura

### Memoria Globale Workspace
```
.claude/memory/
├── workspace-memory.json     # Memoria globale workspace
└── projects/                 # Memoria specifica per progetto
    ├── active_sito-bar.json
    ├── sandbox_test-app.json
    └── production_api.json
```

### Memoria Per-Progetto
Ogni progetto mantiene:
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

## 📱 Comandi Disponibili

### Memoria Globale
```bash
claude-save "nota sessione"           # Salva stato corrente
claude-resume                         # Riprende ultima sessione
claude-memory                         # Gestisce memoria globale
claude-memory context "obiettivo"     # Aggiorna obiettivi
```

### Memoria Progetto
```bash
claude-project-memory save "nota"     # Salva stato progetto
claude-project-memory resume          # Riprende progetto corrente
claude-project-memory todo add "task" # Aggiunge TODO
claude-project-memory todo list       # Lista TODO
claude-project-memory todo done 1     # Completa TODO
```

### Pulizia Memoria
```bash
claude-memory-cleaner auto            # Pulizia automatica
claude-memory-cleaner stats           # Statistiche memoria
claude-memory-cleaner project nome    # Pulisce progetto specifico
```

## 🤖 Automazione

### Auto-Save
- **Trigger**: ogni modifica file (via auto-sync)
- **Frequenza**: quando rileva cambiamenti
- **Scope**: sia memoria globale che per-progetto

### Auto-Cleanup
- **Frequenza**: una volta al giorno
- **Trigger**: durante auto-sync
- **Intelligenza**: preserva informazioni importanti
- **Soglie**: 
  - File > 50KB → compattazione
  - Ultima pulizia > 7 giorni → ricompattazione

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

Il sistema di memoria intelligente garantisce continuità perfetta tra sessioni mantenendo prestazioni ottimali! 🚀