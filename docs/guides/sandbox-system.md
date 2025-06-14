# Sistema Sandbox Claude Workspace Enterprise

Sistema completo enterprise di gestione progetti sandbox con auto-cleanup, template predefiniti e coordinatori avanzati.

## Overview

Il sistema sandbox enterprise fornisce:
- **Auto-cleanup**: Rimozione automatica progetti sandbox vecchi
- **Template**: Template pronti per Python, Node.js, React
- **Gestione progetti**: Creazione, archiviazione, monitoraggio
- **Automazione**: Cron job per cleanup e backup automatici
- **🆕 Coordinatori Enterprise**: Gestione intelligente cross-dispositivi
- **🆕 Project Mode**: Modalità progetto enterprise con protezione
- **🆕 Lock System**: Sistema di lock distribuito per operazioni sicure
- **🆕 Performance Monitoring**: Monitoraggio avanzato performance
- **🆕 Recovery Automatico**: Auto-recovery da crash e errori

## Script Principali

### 🆕 Script Enterprise

#### 🎯 claude-project-mode.sh
Modalità progetto enterprise con protezione e monitoraggio.

```bash
# Avvia modalità progetto enterprise
./scripts/claude-project-mode.sh start mio-progetto

# Status modalità progetto
./scripts/claude-project-mode.sh status

# Stop sicuro modalità progetto
./scripts/claude-project-mode.sh stop mio-progetto
```

#### 🔒 claude-sync-lock.sh
Sistema di lock distribuito enterprise per operazioni sicure.

```bash
# Acquisisce lock per operazione
./scripts/claude-sync-lock.sh acquire "cleanup-operation"

# Rilascia lock
./scripts/claude-sync-lock.sh release "cleanup-operation"

# Status di tutti i lock
./scripts/claude-sync-lock.sh status
```

#### 🧹 claude-backup-cleaner.sh
Pulizia enterprise dei backup con retention policy.

```bash
# Cleanup automatico backup vecchi
./scripts/claude-backup-cleaner.sh --auto

# Cleanup forzato con retention policy
./scripts/claude-backup-cleaner.sh --cleanup-old --days 30
```

#### 📋 claude-log-rotator.sh
Rotazione log enterprise con compressione.

```bash
# Rotazione automatica log
./scripts/claude-log-rotator.sh --auto

# Rotazione forzata
./scripts/claude-log-rotator.sh --force-rotate
```

### Script Classici Potenziati

### 🧹 cleanup-sandbox.sh
Rimuove progetti sandbox più vecchi del periodo di retention configurato.

```bash
# Cleanup con retention 24 ore (default)
./scripts/cleanup-sandbox.sh

# Dry run per vedere cosa verrebbe rimosso
./scripts/cleanup-sandbox.sh --dry-run

# Cleanup con retention personalizzato
./scripts/cleanup-sandbox.sh -r 12  # 12 ore

# Lista progetti sandbox
./scripts/cleanup-sandbox.sh --list
```

**Caratteristiche:**
- ✅ Backup automatico metadata prima della rimozione
- ✅ Lock file per evitare esecuzioni multiple
- ✅ Logging dettagliato delle operazioni
- ✅ Validazione sicurezza (solo progetti sandbox-*)
- ✅ Gestione robusta degli errori

### 🎯 claude-new.sh
Crea nuovi progetti usando template predefiniti.

```bash
# Modalità interattiva (default)
./scripts/claude-new.sh

# Crea progetto con parametri specifici
./scripts/claude-new.sh mio-progetto python-basic active

# Lista template disponibili
./scripts/claude-new.sh --list

# Crea progetto sandbox
./scripts/claude-new.sh esperimento react-app sandbox
```

**Template Disponibili:**
- **python-basic**: Progetto Python con venv, requirements, tests
- **nodejs-api**: API REST completa con Express e middleware
- **react-app**: Applicazione React moderna con Vite e routing
- **empty**: Struttura base minima

### 📦 claude-archive.sh
Archivia progetti completati con metadata completi.

```bash
# Modalità interattiva
./scripts/claude-archive.sh

# Archivia progetto specifico
./scripts/claude-archive.sh archive mio-progetto

# Archivia con copia compressa
./scripts/claude-archive.sh archive mio-progetto copy

# Lista progetti archiviati
./scripts/claude-archive.sh list archived

# Ripristina dall'archivio
./scripts/claude-archive.sh restore progetto-20240601-120000
```

### 📋 claude-list.sh
Lista progetti con informazioni dettagliate e statistiche.

```bash
# Riepilogo generale
./scripts/claude-list.sh --summary

# Lista progetti per categoria
./scripts/claude-list.sh active
./scripts/claude-list.sh sandbox
./scripts/claude-list.sh all

# Vista dettagliata
./scripts/claude-list.sh sandbox --detailed

# Cerca progetti
./scripts/claude-list.sh --find "react"

# Export dati
./scripts/claude-list.sh --export csv
./scripts/claude-list.sh --export json
```

### ⏰ setup-cron.sh
Configura automazione con cron job.

```bash
# Configurazione interattiva
./scripts/setup-cron.sh

# Setup cleanup ogni 6 ore
./scripts/setup-cron.sh cleanup every6h

# Setup backup settimanale
./scripts/setup-cron.sh backup weekly

# Status job configurati
./scripts/setup-cron.sh status

# Rimuovi tutti i job
./scripts/setup-cron.sh remove
```

## Template Dettagliati

### Python Basic Template

Struttura completa per progetti Python:

```
project/
├── src/
│   ├── __init__.py
│   └── main.py
├── tests/
│   └── test_main.py
├── requirements.txt
├── Makefile
├── .env.example
└── setup.py
```

**Funzionalità:**
- Virtual environment setup
- Testing con pytest
- Linting con flake8 e mypy
- Formatting con black
- Dependency management
- Environment variables

### Node.js API Template

API REST completa con Express:

```
project/
├── src/
│   ├── controllers/
│   ├── routes/
│   ├── middleware/
│   └── index.js
├── tests/
├── package.json
└── .env.example
```

**Funzionalità:**
- Express server configurato
- Middleware di sicurezza (helmet, cors)
- Rate limiting
- Logging con morgan
- Error handling robusto
- Testing con Jest + Supertest
- Hot reload con nodemon

### React App Template

Applicazione React moderna:

```
project/
├── src/
│   ├── components/
│   ├── pages/
│   ├── hooks/
│   └── App.jsx
├── public/
├── package.json
└── vite.config.js
```

**Funzionalità:**
- React 18 con hooks
- Vite per build veloce
- React Router per navigazione
- CSS modulare responsive
- Testing setup
- Hot Module Replacement

## Automazione e Monitoring

### Cron Jobs Configurabili

1. **Cleanup Sandbox** (configurabile):
   - Frequenza: hourly, every6h, daily, weekly
   - Retention personalizzabile
   - Logging automatico

2. **Backup Progetti** (opzionale):
   - Backup automatico progetti active/production
   - Rimozione backup vecchi (30 giorni)
   - Compressione tar.gz

3. **Monitoraggio Spazio** (opzionale):
   - Controllo uso disco workspace
   - Alert configurabili
   - Cleanup automatico critico (>90%)

### Logging e Audit

Tutti gli script mantengono log dettagliati:

```
logs/
├── cleanup/
│   └── cleanup-YYYYMMDD-HHMMSS.log
├── project-creation.log
├── project-archive.log
├── cron-setup.log
└── disk-monitor.log
```

## Sicurezza e Robustezza

### Misure di Sicurezza
- ✅ Lock files per evitare esecuzioni multiple
- ✅ Validazione pattern nomi sandbox (sandbox-*)
- ✅ Backup metadata prima di rimozioni
- ✅ Dry-run mode per testing
- ✅ Validazione parametri input

### Gestione Errori
- ✅ Rollback automatico su errori critici
- ✅ Logging dettagliato per debugging
- ✅ Graceful handling fallimenti rete/disco
- ✅ Timeout configurabili per operazioni

### Recovery
- ✅ Backup automatico in logs/cleanup/backups/
- ✅ Metadata JSON per ogni operazione
- ✅ Git integration per tracking modifiche
- ✅ Archivio progetti con recovery info

## Configurazione

### Variabili d'Ambiente

```bash
# Directory principale workspace
WORKSPACE_DIR="$HOME/claude-workspace"

# Ore di retention per cleanup sandbox
RETENTION_HOURS=24

# Modalità dry-run per testing
DRY_RUN=false

# Soglia monitoraggio disco
DISK_THRESHOLD=85
```

### Personalizzazione Template

Per aggiungere template custom:

1. Crea directory in `templates/custom-template/`
2. Aggiungi file `.template-info` con descrizione
3. Il template sarà automaticamente disponibile

### Best Practices

1. **Progetti Sandbox**: Usa per esperimenti temporanei
2. **Progetti Active**: Per sviluppo in corso
3. **Progetti Production**: Solo per codice rilasciato
4. **Cleanup Frequente**: Configura cleanup ogni 6-24 ore
5. **Backup Regolari**: Abilita backup automatico
6. **Monitoraggio**: Attiva alerts spazio disco

## Troubleshooting

### Problemi Comuni

1. **Cleanup non funziona**:
   ```bash
   # Verifica permessi
   chmod +x scripts/cleanup-sandbox.sh
   
   # Test dry-run
   ./scripts/cleanup-sandbox.sh --dry-run
   ```

2. **Template non trovato**:
   ```bash
   # Lista template disponibili
   ./scripts/claude-new.sh --list
   
   # Verifica directory templates
   ls -la templates/
   ```

3. **Cron job non eseguiti**:
   ```bash
   # Verifica configurazione
   crontab -l
   
   # Check log cron
   tail -f /var/log/cron
   ```

### Debug Mode

Attiva debug per output dettagliato:

```bash
# Debug cleanup
VERBOSE=true ./scripts/cleanup-sandbox.sh

# Debug con bash -x
bash -x ./scripts/claude-new.sh
```

## Esempi di Workflow

### Sviluppo Rapido

```bash
# 1. Crea progetto sandbox per esperimento
./scripts/claude-new.sh test-api nodejs-api sandbox

# 2. Sviluppa...
cd projects/sandbox/sandbox-test-api
npm install && npm run dev

# 3. Se buono, promuovi ad active
./scripts/claude-archive.sh restore sandbox-test-api-TIMESTAMP active

# 4. Cleanup automatico sandbox vecchi ogni 6 ore
./scripts/setup-cron.sh cleanup every6h
```

### Gestione Produzione

```bash
# 1. Sviluppo in active
./scripts/claude-new.sh my-app react-app active

# 2. Test e sviluppo...

# 3. Release in production
./scripts/claude-archive.sh archive my-app
# Poi deploy manuale in production

# 4. Backup automatico settimanale
./scripts/setup-cron.sh backup weekly
```

---

## 🎯 Sistema Sandbox Completo

Il sistema sandbox è ora completamente configurato con:

✅ **Auto-cleanup** progetti sandbox vecchi  
✅ **Template pronti** Python, Node.js, React  
✅ **Gestione completa** progetti (new/archive/list)  
✅ **Automazione** cron job configurabili  
✅ **Logging e monitoring** dettagliato  
✅ **Sicurezza** e robustezza integrate  

Usa `./scripts/setup-cron.sh` per configurare l'automazione completa!