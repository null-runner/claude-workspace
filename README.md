# Claude Workspace

Un sistema di sincronizzazione intelligente per gestire progetti tra PC fisso e laptop, ottimizzato per l'uso con Claude AI.

## Cos'è Claude Workspace

Claude Workspace è un sistema che permette di:
- Sincronizzare automaticamente i progetti tra computer diversi
- Mantenere una struttura organizzata per diversi tipi di progetti
- Facilitare il lavoro con Claude AI su più dispositivi
- Gestire backup e versionamento automaticamente

## Come funziona l'architettura

Il sistema si basa su tre componenti principali:

### 1. Struttura delle directory
```
~/claude-workspace/
├── projects/
│   ├── active/      # Progetti in sviluppo attivo
│   ├── sandbox/     # Progetti sperimentali
│   └── production/  # Progetti completati/stabili
├── scripts/         # Script di gestione
├── configs/         # Configurazioni
├── logs/           # Log di sistema
└── docs/           # Documentazione
```

### 2. Sistema di sincronizzazione
- **Sync automatico**: Ogni 5 minuti tramite cron
- **Sync manuale**: Disponibile tramite script
- **Controllo accessi**: Solo dal laptop autorizzato

### 3. Script di gestione
- Script per setup iniziale
- Script per controllo stato
- Script per sincronizzazione
- Script per gestione sicurezza

## Quick Start Guide

### Setup iniziale sul PC fisso
```bash
cd ~/claude-workspace
./setup.sh
```

### Setup sul laptop
```bash
# Scarica e esegui lo script di setup
curl -o laptop-setup.sh http://192.168.1.106:8000/scripts/setup-laptop.sh
chmod +x laptop-setup.sh
./laptop-setup.sh
```

### Verificare lo stato del sistema
```bash
# Sul PC fisso
~/claude-workspace/scripts/claude-status.sh

# Sul laptop
~/claude-workspace/scripts/sync-status.sh
```

## Comandi principali

### Sincronizzazione
```bash
# Sync manuale immediato (dal laptop)
~/claude-workspace/scripts/sync-now.sh

# Abilitare sync automatico (dal laptop)
~/claude-workspace/scripts/auto-sync.sh enable

# Disabilitare sync automatico (dal laptop)
~/claude-workspace/scripts/auto-sync.sh disable
```

### Gestione progetti
```bash
# Creare un nuovo progetto
cd ~/claude-workspace/projects/active
mkdir my-new-project

# Spostare un progetto in produzione
mv ~/claude-workspace/projects/active/my-project ~/claude-workspace/projects/production/
```

### Controllo accessi
```bash
# Verificare accesso (dal PC fisso)
~/claude-workspace/scripts/claude-status.sh

# Abilitare accesso temporaneo (dal PC fisso)
~/claude-workspace/scripts/claude-enable.sh

# Disabilitare accesso (dal PC fisso)
~/claude-workspace/scripts/claude-disable.sh
```

## Workflow tipico

1. **Iniziare un nuovo progetto sul laptop**:
   ```bash
   cd ~/claude-workspace/projects/active
   mkdir nuovo-progetto
   cd nuovo-progetto
   # ... sviluppo ...
   ```

2. **Sincronizzare con il PC fisso**:
   ```bash
   ~/claude-workspace/scripts/sync-now.sh
   ```

3. **Continuare sul PC fisso**:
   ```bash
   cd ~/claude-workspace/projects/active/nuovo-progetto
   # ... continua sviluppo ...
   ```

## Struttura dei progetti

Ogni progetto dovrebbe seguire questa struttura consigliata:
```
my-project/
├── src/           # Codice sorgente
├── docs/          # Documentazione specifica
├── tests/         # Test
├── data/          # Dati del progetto
└── README.md      # Descrizione progetto
```

## Troubleshooting rapido

- **Sync non funziona**: Verifica connessione SSH con `ssh nullrunner@192.168.1.106`
- **Permessi negati**: Controlla stato con `claude-status.sh` sul PC fisso
- **File mancanti**: Verifica i log in `~/claude-workspace/logs/`

Per maggiori dettagli, consulta la documentazione completa in `docs/`.