# Claude Workspace

Un workspace intelligente completo che sincronizza progetti e mantiene la memoria tra diversi dispositivi, ottimizzato per l'uso con Claude AI.

## Cos'è Claude Workspace

Claude Workspace è un sistema che permette di:
- Sincronizzare automaticamente i progetti tra computer diversi
- Mantenere una struttura organizzata per diversi tipi di progetti
- Facilitare il lavoro con Claude AI su più dispositivi
- Gestire backup e versionamento automaticamente
- **Preservare continuità tra sessioni** grazie al sistema di memoria intelligente
- **Mantenere il contesto dei progetti** con auto-save e pulizia automatica
- **Sincronizzare lo stato del lavoro** tra dispositivi senza perdere informazioni

## Come funziona l'architettura

Il sistema si basa su quattro componenti principali:

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
├── docs/           # Documentazione
└── .claude/        # Sistema memoria intelligente
    └── memory/
        ├── workspace-memory.json    # Memoria globale
        └── projects/               # Memoria per-progetto
            ├── active_*.json
            ├── sandbox_*.json
            └── production_*.json
```

### 2. Sistema di sincronizzazione
- **Sync automatico**: Ogni 5 minuti tramite cron
- **Sync manuale**: Disponibile tramite script
- **Controllo accessi**: Solo dal laptop autorizzato
- **Sync memoria**: Include automaticamente `.claude/memory/`

### 3. Sistema memoria intelligente
- **Memoria globale**: Stato generale workspace e note inter-sessione
- **Memoria per-progetto**: Contesto specifico, TODO, file attivi, note tecniche
- **Auto-save**: Salvataggio automatico collegato al file monitoring
- **Pulizia intelligente**: Compattazione automatica con preservazione dati importanti
- **Cross-device**: Sincronizzazione trasparente tra dispositivi

### 4. Script di gestione
- Script per setup iniziale
- Script per controllo stato
- Script per sincronizzazione
- Script per gestione sicurezza
- **Script memoria**: `claude-save`, `claude-resume`, `claude-project-memory`, `claude-memory-cleaner`

# INSTALLAZIONE - Guida Completa per Principianti

> 🎯 **Obiettivo**: Configurare un workspace intelligente che funziona su più dispositivi (PC fisso, laptop, ecc.) mantenendo tutto sincronizzato automaticamente.

## 1. INTRODUZIONE AL SISTEMA

### Che cos'è Claude Workspace?
Claude Workspace è **molto più di un semplice strumento di sincronizzazione**. È un workspace completo che:

- **Sincronizza automaticamente** tutti i tuoi progetti tra dispositivi diversi
- **Mantiene la memoria** di quello che stavi facendo, anche quando cambi dispositivo
- **Organizza automaticamente** i tuoi progetti in categorie (sviluppo attivo, sperimentazione, produzione)
- **Ricorda il contesto** di ogni progetto, così puoi riprendere esattamente da dove avevi lasciato
- **Funziona perfettamente** con Claude AI per una continuità totale nel lavoro

### Perché è utile?
**Per sviluppatori:**
- Non perdi mai il filo del lavoro quando cambi computer
- I progetti sono sempre aggiornati ovunque
- La memoria intelligente ricorda TODO, note tecniche, stato del progetto

**Per tutti gli altri:**
- Documenti e file sempre sincronizzati
- Backup automatico di tutto il lavoro
- Interfaccia semplice ma potente

### Quali dispositivi puoi collegare?
- **PC fisso** (dispositivo principale)
- **Laptop** (dispositivo secondario)
- **Altri computer** (con configurazione aggiuntiva)
- **Potenzialmente tablet/smartphone** (in futuro)

### Panoramica delle funzionalità principali
✅ **Sincronizzazione automatica** ogni 5 minuti  
✅ **Sistema di memoria intelligente** per continuità tra sessioni  
✅ **Gestione progetti** con categorie automatiche  
✅ **Backup automatico** di tutto il workspace  
✅ **Sicurezza** con controllo accessi SSH  
✅ **Facilità d'uso** con comandi semplici  

---

## 2. PRIMA DI INIZIARE - Prerequisiti

> 📋 **Tempo stimato**: 10-15 minuti per verificare tutto

### Cosa devi avere:
- [ ] **Computer con Linux** (Ubuntu, Debian, o simili)
- [ ] **Connessione internet** stabile
- [ ] **Account GitHub** (gratuito - ti aiuteremo a crearlo)
- [ ] **Conoscenze base del terminale** (saper aprire e digitare comandi)

### Verifica prerequisiti automatica:
```bash
# Copia e incolla nel terminale per verificare tutto
echo "🔍 VERIFICA PREREQUISITI"
echo "======================="
echo "Git installato: $(command -v git >/dev/null && echo "✅ SI" || echo "❌ NO")"
echo "SSH disponibile: $(command -v ssh >/dev/null && echo "✅ SI" || echo "❌ NO")"
echo "Sistema operativo: $(uname -s)"
echo "Versione: $(lsb_release -d 2>/dev/null | cut -f2 || echo "Non rilevabile")"
```

### Se manca qualcosa:
```bash
# Installa git e ssh (se mancano)
sudo apt update
sudo apt install git openssh-client openssh-server
```

---

## 3. CREAZIONE ACCOUNT GITHUB

> 🌐 **Se hai già un account GitHub, salta questa sezione**

### Passo 1: Registrazione
1. Vai su [github.com](https://github.com)
2. Clicca "Sign up"
3. Inserisci email, password, username
4. Conferma l'email

[Screenshot: Pagina registrazione GitHub]

### Passo 2: Crea il repository per il workspace
1. Dopo il login, clicca il pulsante verde "New" o "+" in alto a destra
2. Nome repository: `claude-workspace`
3. Descrizione: `Il mio workspace intelligente per Claude AI`
4. Seleziona "Private" (consigliato per sicurezza)
5. Seleziona "Add a README file"
6. Clicca "Create repository"

[Screenshot: Creazione repository]

### Passo 3: Genera una Deploy Key
1. Nel repository appena creato, vai su "Settings" (scheda in alto)
2. Nel menu laterale, clicca "Deploy keys"
3. Tieni questa pagina aperta - la useremo dopo

[Screenshot: Pagina Deploy keys]

---

## 4. INSTALLAZIONE PRIMO DISPOSITIVO (PC Fisso)

> 🖥️ **Questo sarà il tuo dispositivo principale - il "server" del workspace**

### Passo 1: Scarica il sistema
```bash
# Vai nella directory home
cd ~

# Clona il repository (sostituisci TUOUSERNAME con il tuo username GitHub)
git clone https://github.com/TUOUSERNAME/claude-workspace.git

# Entra nella directory
cd claude-workspace
```

### Passo 2: Configura il repository
```bash
# Crea la struttura base
mkdir -p projects/{active,sandbox,production}
mkdir -p scripts configs logs docs templates
mkdir -p .claude/memory/projects

# Copia i file di configurazione
curl -o scripts/setup-laptop.sh https://raw.githubusercontent.com/null-runner/claude-workspace/main/scripts/setup-laptop.sh
curl -o scripts/claude-status.sh https://raw.githubusercontent.com/null-runner/claude-workspace/main/scripts/claude-status.sh
# ... (scarica tutti gli script necessari)
```

### Passo 3: Genera le chiavi SSH
```bash
# Genera una chiave SSH specifica per il workspace
ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key -C "claude-workspace-$(hostname)"

# Avvia l'agente SSH
eval "$(ssh-agent -s)"

# Aggiungi la chiave
ssh-add ~/.ssh/claude_workspace_key
```

### Passo 4: Aggiungi la chiave a GitHub
```bash
# Mostra la chiave pubblica
echo "🔑 COPIA QUESTA CHIAVE:"
cat ~/.ssh/claude_workspace_key.pub
```

**Ora torna su GitHub:**
1. Nella pagina "Deploy keys" che avevi lasciato aperta
2. Clicca "Add deploy key"
3. Titolo: `Claude-Desktop-$(hostname)-$(date +%Y%m%d)`
4. Incolla la chiave nel campo "Key"
5. Seleziona "Allow write access"
6. Clicca "Add key"

[Screenshot: Aggiunta deploy key]

### Passo 5: Testa la connessione
```bash
# Testa la connessione SSH con GitHub
ssh -T git@github.com -i ~/.ssh/claude_workspace_key
```

**Dovresti vedere**: `Hi TUOUSERNAME/claude-workspace! You've successfully authenticated...`

### Passo 6: Primo commit
```bash
# Configura git per questo repository
git config user.name "Il tuo nome"
git config user.email "tua@email.com"

# Fai il primo commit
git add .
git commit -m "🚀 Inizializzazione Claude Workspace"
git push origin main
```

### Passo 7: Inizializza il sistema memoria
```bash
# Rendi eseguibili gli script
chmod +x scripts/*.sh

# Inizializza la memoria
./scripts/claude-save.sh "Sistema Claude Workspace inizializzato su $(hostname)"

# Verifica che funzioni
./scripts/claude-resume.sh
```

**Dovresti vedere qualcosa come:**
```
🧠 MEMORIA WORKSPACE
====================
📍 ULTIMA SESSIONE:
   Quando: Pochi secondi fa (il-tuo-pc)
   Ultima nota: Sistema Claude Workspace inizializzato su il-tuo-pc
```

### Passo 8: Verifica installazione
```bash
# Controlla lo stato del sistema
./scripts/claude-status.sh
```

**Output atteso:**
```
🎯 CLAUDE WORKSPACE STATUS
==========================
📊 Sistema: ✅ FUNZIONANTE
🔄 Memoria: ✅ ATTIVA
📁 Progetti: 0 attivi, 0 sandbox, 0 produzione
🔐 Sicurezza: ✅ CONFIGURATA
```

---

## 5. AGGIUNTA DEL LAPTOP

> 💻 **Ora configuriamo il secondo dispositivo**

### Passo 1: Scarica lo script di setup
```bash
# Sul laptop, scarica lo script automatico
curl -o setup-laptop.sh https://raw.githubusercontent.com/TUOUSERNAME/claude-workspace/main/scripts/setup-laptop.sh
chmod +x setup-laptop.sh
```

### Passo 2: Esegui il setup automatico
```bash
# Esegui lo script - ti guiderà passo passo
./setup-laptop.sh
```

**Lo script farà:**
1. Verificherà i prerequisiti
2. Clonerà il repository
3. Genererà una nuova chiave SSH
4. Ti chiederà di aggiungerla su GitHub
5. Configurerà la sincronizzazione automatica

### Passo 3: Aggiungi la nuova chiave su GitHub
Durante l'esecuzione, lo script mostrerà una nuova chiave pubblica:

```
🔑 IMPORTANTE: Aggiungi questa deploy key su GitHub:
   URL: https://github.com/TUOUSERNAME/claude-workspace/settings/keys
   Nome: Claude-Laptop-nome_laptop-20250613

[La chiave apparirà qui]

Premi ENTER dopo aver aggiunto la chiave...
```

1. Copia la chiave mostrata
2. Vai all'URL indicato
3. Aggiungi una nuova deploy key con il nome suggerito
4. Premi ENTER per continuare

### Passo 4: Primo test di sincronizzazione
```bash
# Dovrebbe sincronizzarsi automaticamente, ma puoi forzarlo
cd ~/claude-workspace
git pull origin main

# Verifica che la memoria sia sincronizzata
./scripts/claude-resume.sh
```

**Dovresti vedere la stessa memoria del PC fisso!**

### Passo 5: Test bidirezionale
```bash
# Sul laptop, aggiungi una nota
./scripts/claude-save.sh "Test dal laptop - sincronizzazione funziona!"

# Pusha le modifiche
git add .
git commit -m "Test sincronizzazione dal laptop"
git push origin main
```

**Sul PC fisso:**
```bash
# Aggiorna
cd ~/claude-workspace
git pull origin main

# Verifica la memoria
./scripts/claude-resume.sh
```

**Dovresti vedere la nota dal laptop!**

---

## 6. CONFIGURAZIONE SISTEMA MEMORIA

> 🧠 **La memoria intelligente è già attiva, ma impariamo a usarla**

### La memoria funziona automaticamente
Non devi fare nulla di speciale - il sistema memoria:
- **Si inizializza automaticamente** alla prima installazione
- **Si sincronizza automaticamente** tra dispositivi
- **Si pulisce automaticamente** per non diventare troppo grande

### Comandi base che dovresti conoscere:

#### Memoria globale del workspace:
```bash
# Salva una nota per la prossima sessione
claude-save "Domani finisco il sito web del bar"

# Riprende l'ultima sessione
claude-resume
# Mostra: "Domani finisco il sito web del bar"

# Vedi tutta la memoria
claude-memory
```

#### Memoria specifica per progetto:
```bash
# Vai in un progetto
cd ~/claude-workspace/projects/active/mio-progetto

# Salva stato del progetto
claude-project-memory save "Completato il login, ora faccio il menu"

# Aggiungi un TODO
claude-project-memory todo add "Implementare validazione form"
claude-project-memory todo add "Aggiungere CSS al menu"

# Vedi TODO
claude-project-memory todo list

# Completa un TODO
claude-project-memory todo done 1

# Riprende progetto
claude-project-memory resume
```

### Verifica che la memoria funzioni:
```bash
# Test memoria globale
claude-save "Test memoria funziona" && claude-resume

# Test memoria progetto
cd ~/claude-workspace/projects/active
mkdir test-progetto
cd test-progetto
claude-project-memory save "Progetto test inizializzato"
claude-project-memory todo add "Primo task di test"
claude-project-memory resume
```

---

## 7. PRIMO PROGETTO - Guida Pratica

> 🎯 **Creiamo insieme il tuo primo progetto per vedere tutto in azione**

### Passo 1: Crea il progetto
```bash
# Vai nella directory progetti attivi
cd ~/claude-workspace/projects/active

# Crea una nuova directory per il progetto
mkdir il-mio-primo-progetto
cd il-mio-primo-progetto

# Inizializza la memoria del progetto
claude-project-memory save "Nuovo progetto creato - inizio sviluppo"
```

### Passo 2: Aggiungi alcuni TODO
```bash
# Pianifica il lavoro
claude-project-memory todo add "Creare file README"
claude-project-memory todo add "Impostare struttura directory"
claude-project-memory todo add "Scrivere prima funzione"

# Vedi la lista
claude-project-memory todo list
```

### Passo 3: Inizia a lavorare
```bash
# Crea alcuni file
echo "# Il Mio Primo Progetto" > README.md
mkdir src
echo "console.log('Ciao mondo!');" > src/main.js

# Aggiorna la memoria
claude-project-memory save "Creati README e file principale"

# Completa il primo TODO
claude-project-memory todo done 1
```

### Passo 4: Sincronizza tutto
```bash
# Torna alla directory principale
cd ~/claude-workspace

# Salva nota globale
claude-save "Primo progetto creato con successo!"

# Sincronizza con GitHub
git add .
git commit -m "➕ Nuovo progetto: il-mio-primo-progetto"
git push origin main
```

### Passo 5: Testa su altro dispositivo
**Sul laptop (o altro dispositivo):**
```bash
# Sincronizza
cd ~/claude-workspace
git pull origin main

# Vedi la memoria globale
claude-resume
# Dovrebbe mostrare: "Primo progetto creato con successo!"

# Vai al progetto
cd projects/active/il-mio-primo-progetto

# Vedi la memoria del progetto
claude-project-memory resume
# Dovrebbe mostrare tutti i dettagli del progetto!
```

---

## 8. CAPIRE COME FUNZIONA IL SISTEMA

> 🔍 **Spiegazione semplice per chi non è tecnico**

### Come funziona la sincronizzazione GitHub
**In parole semplici:**
- GitHub è come un "disco rigido su internet"
- Ogni volta che salvi qualcosa, va anche su GitHub
- Quando accendi l'altro computer, scarica tutto da GitHub
- È come avere la stessa cartella su tutti i computer

**Cosa viene sincronizzato:**
✅ Tutti i file dei progetti  
✅ La memoria del workspace  
✅ I TODO e le note  
✅ La configurazione del sistema  

**Cosa NON viene sincronizzato:**
❌ File temporanei (`.tmp`, `.log`)  
❌ Directory `node_modules` (troppo grandi)  
❌ File di sistema privati  

### Come funziona la pulizia automatica della memoria
**Il sistema è intelligente:**
- Ogni giorno, controlla se la memoria è diventata troppo grande
- Mantiene sempre le informazioni importanti (progetti attivi, TODO recenti)
- Rimuove solo le informazioni vecchie e non più utili
- **Non perdi mai nulla di importante**

**Esempio di pulizia:**
- Mantiene: "Domani finisco il sito" (recente e importante)
- Rimuove: "Test memoria funziona" (vecchio e di test)

### Sicurezza semplice
**Le tue chiavi SSH sono come "password super sicure":**
- Solo i tuoi computer possono accedere ai tuoi progetti
- Anche se qualcuno conosce il tuo username GitHub, non può accedere
- Ogni computer ha la sua "password" unica

**Best practices:**
- Non condividere mai le chiavi SSH (`~/.ssh/claude_workspace_key`)
- Se un computer viene perso/rubato, rimuovi la sua chiave da GitHub
- Fai backup regolari (il sistema lo fa automaticamente)

---

## 9. USO QUOTIDIANO DEL SISTEMA

> 📅 **Come usare il workspace nella vita di tutti i giorni**

### Routine mattutina:
```bash
# Apri il terminale
cd ~/claude-workspace

# Vedi cosa stavi facendo
claude-resume

# Sincronizza (se non è automatico)
git pull origin main

# Vai al progetto su cui stai lavorando
cd projects/active/nome-progetto

# Riprendi il contesto del progetto
claude-project-memory resume
```

### Durante il lavoro:
```bash
# Ogni volta che completi qualcosa di importante
claude-project-memory save "Completata funzionalità X"

# Aggiungi TODO quando ti vengono in mente
claude-project-memory todo add "Ricordati di testare su mobile"

# Salva note per la prossima sessione
claude-save "Domani sistemare il bug del login"
```

### Routine serale:
```bash
# Salva lo stato finale
claude-project-memory save "Finito per oggi - domani continuo con Y"
claude-save "Buona giornata di lavoro, domani riprendere progetto X"

# Sincronizza tutto
git add .
git commit -m "📝 Fine giornata - aggiornamento progetti"
git push origin main
```

### Cambio dispositivo:
```bash
# Sul nuovo dispositivo
cd ~/claude-workspace
git pull origin main
claude-resume  # Vedi subito dove eri rimasto!
```

---

## 10. MANUTENZIONE E RISOLUZIONE PROBLEMI

> 🔧 **Come mantenere il sistema in salute**

### Controlli settimanali (5 minuti):
```bash
# Verifica stato generale
claude-status

# Verifica dimensione memoria
claude-memory-cleaner stats

# Se la memoria è troppo grande
claude-memory-cleaner auto
```

### Problemi comuni e soluzioni:

#### "La sincronizzazione non funziona"
```bash
# Verifica connessione internet
ping -c 3 github.com

# Verifica autenticazione GitHub
ssh -T git@github.com

# Forza sincronizzazione manuale
git pull origin main
git push origin main
```

#### "Non vedo la memoria dell'altro dispositivo"
```bash
# Verifica che la memoria sia sincronizzata
ls -la .claude/memory/

# Se vuota, sincronizza manualmente
git pull origin main

# Se ancora non funziona, inizializza
claude-save "Reinizializzo memoria"
```

#### "Il comando claude-save non funziona"
```bash
# Verifica che gli script siano eseguibili
ls -la scripts/claude-*.sh

# Se non sono eseguibili
chmod +x scripts/*.sh

# Verifica che siano nel PATH
echo $PATH | grep claude-workspace
```

### Quando chiedere aiuto:
- Se vedi errori che non capisci
- Se la sincronizzazione si blocca per più di un giorno
- Se perdi dati importanti (raro, ma possibile)
- Se vuoi aggiungere funzionalità personalizzate

### Backup di emergenza:
```bash
# Crea un backup completo
tar -czf ~/backup-claude-workspace-$(date +%Y%m%d).tar.gz ~/claude-workspace/

# Verifica che il backup sia stato creato
ls -lh ~/backup-claude-workspace-*.tar.gz
```

---

## ✅ CHECKLIST FINALE

### Dopo l'installazione completa, dovresti avere:
- [ ] 🖥️ PC fisso configurato come dispositivo principale
- [ ] 💻 Laptop configurato per sincronizzazione automatica
- [ ] 🔐 Chiavi SSH funzionanti su GitHub
- [ ] 🧠 Sistema memoria attivo e sincronizzato
- [ ] 📁 Primo progetto di test creato e funzionante
- [ ] 🔄 Sincronizzazione automatica attiva
- [ ] 📝 Tutti i comandi base testati e funzionanti

### Test finale:
1. **Sul PC fisso**: `claude-save "Test finale installazione"`
2. **Sul laptop**: `git pull && claude-resume` (deve mostrare la nota)
3. **Crea progetto sul laptop** e verifica che appaia sul PC fisso
4. **Aggiungi TODO** e verifica che si sincronizzino

### 🎉 Congratulazioni!
Hai installato con successo Claude Workspace! Ora hai un sistema professionale che:
- Mantiene tutti i tuoi progetti sincronizzati
- Ricorda sempre dove eri rimasto
- Fa backup automatico di tutto
- Ti permette di lavorare seamlessly su più dispositivi

**Prossimi passi suggeriti:**
- Esplora i template in `templates/` per progetti rapidi
- Leggi `docs/WORKFLOW.md` per workflow avanzati
- Configura i tuoi editor preferiti per lavorare nella directory `~/claude-workspace`

---

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

## Sistema Memoria Intelligente 🧠

Claude Workspace include un **sistema di memoria intelligente** che mantiene continuità tra sessioni e dispositivi, memorizzando automaticamente il contesto dei progetti senza appesantire il sistema.

### Caratteristiche principali
- **Memoria per-progetto**: Ogni progetto mantiene il suo contesto specifico
- **Memoria globale workspace**: Stato generale del workspace
- **Pulizia intelligente**: Compattazione automatica che preserva informazioni importanti
- **Sincronizzazione cross-device**: Memoria sincronizzata tra PC fisso e laptop
- **Auto-save integrato**: Salvataggio automatico collegato al sistema di sync

### Struttura memoria
```
.claude/memory/
├── workspace-memory.json          # Memoria globale workspace
└── projects/                      # Memoria specifica per progetto
    ├── active_sito-bar.json
    ├── sandbox_test-app.json
    └── production_api-server.json
```

### Comandi memoria

#### Memoria globale workspace
```bash
# Salva stato corrente con nota
claude-save "Completato header, domani il menu"

# Riprende ultima sessione
claude-resume

# Gestione memoria generale
claude-memory
```

#### Memoria per-progetto
```bash
# Salva stato progetto corrente
claude-project-memory save "Implementato sistema login"

# Riprende progetto specifico
claude-project-memory resume active/my-project

# Gestione TODO del progetto
claude-project-memory todo add "Implementare validazione form"
claude-project-memory todo list
claude-project-memory todo done 1

# Lista progetti con memoria
claude-project-memory list
```

#### Pulizia memoria
```bash
# Pulizia automatica intelligente
claude-memory-cleaner auto

# Statistiche utilizzo memoria
claude-memory-cleaner stats

# Pulizia progetto specifico
claude-memory-cleaner project active/my-project
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

### Workflow classico (con memoria intelligente)

1. **Iniziare un nuovo progetto sul laptop**:
   ```bash
   cd ~/claude-workspace/projects/active
   mkdir nuovo-progetto
   cd nuovo-progetto
   
   # Inizializza memoria progetto
   claude-project-memory save "Nuovo progetto inizializzato"
   claude-project-memory todo add "Creare struttura base"
   
   # ... sviluppo ...
   ```

2. **Salvare stato e sincronizzare**:
   ```bash
   # Salva automaticamente durante lo sviluppo
   claude-project-memory save "Completata homepage"
   claude-save "Prossima sessione: implementare menu"
   
   # Sync automatico ogni 5 minuti, oppure manuale
   ~/claude-workspace/scripts/sync-now.sh
   ```

3. **Continuare sul PC fisso**:
   ```bash
   # Riprendi contesto generale
   claude-resume
   # Output: "Prossima sessione: implementare menu"
   
   # Vai al progetto
   cd ~/claude-workspace/projects/active/nuovo-progetto
   
   # Riprendi contesto specifico progetto
   claude-project-memory resume
   # Output: dettagli ultimo stato, TODO, file attivi
   
   # Continua sviluppo con piena continuità
   ```

### Workflow avanzato con memoria

1. **Gestione TODO durante sviluppo**:
   ```bash
   # Aggiungi task
   claude-project-memory todo add "Implementare validazione form"
   claude-project-memory todo add "Aggiungere test unitari"
   
   # Visualizza TODO
   claude-project-memory todo list
   
   # Completa task
   claude-project-memory todo done 1
   ```

2. **Cambio dispositivo frequente**:
   ```bash
   # Sul laptop
   claude-project-memory save "Implementato login, ora faccio logout"
   
   # Sul PC fisso (dopo sync automatico)
   claude-project-memory resume
   # Vede subito: "Implementato login, ora faccio logout"
   ```

3. **Gestione memoria quando necessario**:
   ```bash
   # Verifica stato memoria
   claude-memory-cleaner stats
   
   # Pulizia manuale se necessario
   claude-memory-cleaner auto
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

### Problemi sincronizzazione
- **Sync non funziona**: Verifica connessione SSH con `ssh nullrunner@192.168.1.106`
- **Permessi negati**: Controlla stato con `claude-status.sh` sul PC fisso
- **File mancanti**: Verifica i log in `~/claude-workspace/logs/`

### Problemi memoria
- **Memoria non salva**: Verifica permessi su `.claude/memory/` con `ls -la .claude/`
- **Progetto non rilevato**: Assicurati di essere in `~/claude-workspace/projects/tipo/nome`
- **Memoria corrotta**: Reset con `rm -rf .claude/memory && claude-save "Reset memoria"`
- **Memoria troppo grande**: Esegui `claude-memory-cleaner auto --force`

### Comandi diagnostica
```bash
# Stato generale sistema
~/claude-workspace/scripts/claude-status.sh

# Stato memoria
claude-memory-cleaner stats

# Verifica sincronizzazione memoria
claude-resume  # Deve mostrare ultima sessione
```

Per maggiori dettagli, consulta la documentazione completa in `docs/`, in particolare:
- `docs/MEMORY-SYSTEM.md` - Guida completa sistema memoria
- `docs/WORKFLOW.md` - Workflow avanzati con memoria  
- `docs/SECURITY.md` - Sicurezza e backup memoria