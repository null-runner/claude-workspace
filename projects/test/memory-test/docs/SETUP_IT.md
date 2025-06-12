# Guida al Setup

**Lingua:** [🇺🇸 English](SETUP.md) | [🇮🇹 Italiano](SETUP_IT.md)

## Prerequisiti

Prima di configurare Claude Workspace, assicurati di avere installato:

- **Node.js** (versione 16 o superiore)
- **npm** o **yarn** package manager
- **Git** sistema di controllo versione
- **Accesso API Claude** (account Anthropic richiesto)
- **Terminal/Shell** con privilegi di amministratore

## Passaggi di Installazione

### 1. Clona il Repository

```bash
git clone https://github.com/your-username/claude-workspace.git
cd claude-workspace
```

### 2. Installa le Dipendenze

Usando npm:
```bash
npm install
```

Usando yarn:
```bash
yarn install
```

### 3. Configurazione dell'Ambiente

1. Copia il template delle variabili d'ambiente:
   ```bash
   cp .env.example .env
   ```

2. Modifica il file `.env` con le tue impostazioni:
   ```bash
   # Configurazione API Claude
   CLAUDE_API_KEY=la_tua_chiave_api_qui
   CLAUDE_MODEL=claude-3-sonnet-20240229
   
   # Configurazione Workspace
   WORKSPACE_PATH=/percorso/al/tuo/workspace
   MEMORY_STORAGE_PATH=./data/memory
   
   # Impostazioni di Sicurezza
   ENCRYPTION_KEY=la_tua_chiave_crittografia_sicura
   SESSION_TIMEOUT=3600
   ```

### 4. Setup Chiave API

1. **Ottieni la tua chiave API Claude:**
   - Visita [console.anthropic.com](https://console.anthropic.com)
   - Crea un account o effettua il login
   - Naviga nella sezione API Keys
   - Genera una nuova chiave API

2. **Configura la chiave API:**
   - Aggiungi la tua chiave API al file `.env`
   - Verifica l'accesso con il comando di test:
     ```bash
     npm run test-api
     ```

### 5. Inizializza il Sistema di Memoria

```bash
npm run init-memory
```

Questo comando:
- Creerà le directory necessarie
- Configurerà il database della memoria
- Imposterà le configurazioni iniziali
- Eseguirà la diagnostica del sistema

### 6. Esegui lo Script di Setup

Esegui lo script di setup automatizzato:

```bash
chmod +x setup.sh
./setup.sh
```

Lo script:
- Verificherà tutte le dipendenze
- Configurerà i percorsi di sistema
- Imposterà il logging
- Inizializzerà il workspace
- Eseguirà test di base

## Verifica

### Testa l'Installazione

1. **Test di funzionalità di base:**
   ```bash
   npm run test
   ```

2. **Test di connettività API:**
   ```bash
   npm run test-connection
   ```

3. **Test del sistema di memoria:**
   ```bash
   npm run test-memory
   ```

### Output Atteso

Se tutto è configurato correttamente, dovresti vedere:
```
✅ Tutte le dipendenze installate
✅ Variabili d'ambiente configurate
✅ Connessione API Claude stabilita
✅ Sistema di memoria inizializzato
✅ Workspace pronto per l'uso
```

## Opzioni di Configurazione

### Impostazioni Avanzate

Modifica `config/workspace.json` per la configurazione avanzata:

```json
{
  "memory": {
    "maxContextLength": 100000,
    "persistenceEnabled": true,
    "compressionLevel": "medium"
  },
  "workflow": {
    "autoSave": true,
    "backupInterval": 300,
    "maxRetries": 3
  },
  "security": {
    "encryptionEnabled": true,
    "auditLogging": true,
    "sessionManagement": true
  }
}
```

### Workflow Personalizzati

Per configurare workflow personalizzati:

1. Crea file workflow nella directory `workflows/`
2. Definisci i passaggi del workflow in formato YAML
3. Registra i workflow in `config/workflows.json`

Esempio di struttura workflow:
```yaml
name: "Workflow di Sviluppo"
steps:
  - name: "Code Review"
    action: "analyze"
    parameters:
      files: ["src/**/*.js"]
  - name: "Genera Documentazione"
    action: "document"
    parameters:
      output: "docs/api.md"
```

## Risoluzione Problemi

### Problemi Comuni

**1. Chiave API Non Funziona**
- Verifica che la chiave sia corretta e attiva
- Controlla i limiti di utilizzo dell'API
- Assicurati della corretta configurazione delle variabili d'ambiente

**2. Errori del Sistema di Memoria**
- Controlla i permessi file nella directory data
- Verifica la disponibilità di spazio su disco
- Rivedi le impostazioni di configurazione della memoria

**3. Fallimenti di Installazione**
- Aggiorna Node.js all'ultima versione stabile
- Pulisci la cache npm: `npm cache clean --force`
- Elimina `node_modules` e reinstalla

**4. Problemi di Permessi**
- Esegui con i permessi appropriati
- Controlla la proprietà delle directory
- Verifica la variabile d'ambiente PATH

### Ottenere Aiuto

Se incontri problemi:

1. Controlla i log nella directory `logs/`
2. Rivedi la [guida risoluzione problemi](TROUBLESHOOTING_IT.md)
3. Cerca tra le [issue GitHub esistenti](https://github.com/your-username/claude-workspace/issues)
4. Crea una nuova issue con informazioni dettagliate sull'errore

## Prossimi Passi

Dopo l'installazione riuscita:

1. Leggi la [Documentazione Workflow](WORKFLOW_IT.md)
2. Rivedi le [Linee Guida di Sicurezza](SECURITY_IT.md)
3. Esplora il [Sistema di Memoria](MEMORY-SYSTEM_IT.md)
4. Prova i workflow di esempio in `examples/`

## Aggiornamento

Per aggiornare Claude Workspace:

```bash
git pull origin main
npm update
npm run update-config
```

Esegui sempre il backup della configurazione e dei dati prima di aggiornare.

---

**Hai bisogno di più aiuto?** Controlla la nostra [documentazione](../README_IT.md) o [crea un'issue](https://github.com/your-username/claude-workspace/issues/new).