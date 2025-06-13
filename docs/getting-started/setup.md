# Guida Setup Completa - Claude Workspace

Questa guida copre il setup completo del sistema Claude Workspace sia per il PC fisso che per il laptop.

## Setup PC Fisso

### Prerequisiti
- Ubuntu/Debian o sistema Linux compatibile
- Git installato
- Accesso SSH configurato
- Python 3.x per il server HTTP temporaneo

### Installazione step-by-step

1. **Clonare o creare la struttura base**:
   ```bash
   cd ~
   git clone <repository-url> claude-workspace
   # oppure
   mkdir -p ~/claude-workspace/{projects/{active,sandbox,production},scripts,configs,logs,docs}
   ```

2. **Eseguire lo script di setup**:
   ```bash
   cd ~/claude-workspace
   chmod +x setup.sh
   ./setup.sh
   ```

3. **Cosa fa lo script setup.sh**:
   - Crea tutte le directory necessarie
   - Imposta i permessi corretti (755 per directory, 644 per file)
   - Crea il file di controllo accessi
   - Genera gli script di gestione
   - Configura il logging

4. **Verificare l'installazione**:
   ```bash
   ~/claude-workspace/scripts/claude-status.sh
   ```

   Output atteso:
   ```
   === Claude Workspace Status ===
   Timestamp: 2025-01-06 10:30:45
   
   Access Control: ENABLED/DISABLED
   Allowed Devices: 1
   
   Directory Structure: OK
   Scripts: OK
   Permissions: OK
   ```

5. **Inizializzare sistema memoria intelligente**:
   ```bash
   # Crea struttura memoria
   mkdir -p ~/claude-workspace/.claude/memory/projects
   
   # Inizializza memoria globale workspace
   claude-save "Sistema Claude Workspace inizializzato"
   
   # Verifica funzionamento
   claude-resume
   ```

   Output atteso:
   ```
   🧠 MEMORIA WORKSPACE
   ====================
   📍 ULTIMA SESSIONE:
      Quando: Pochi secondi fa (hostname)
      Ultima nota: Sistema Claude Workspace inizializzato
   ```

### Configurazione SSH

1. **Generare chiavi SSH (se non esistenti)**:
   ```bash
   ssh-keygen -t ed25519 -C "claude-workspace"
   ```

2. **Configurare authorized_keys**:
   ```bash
   # Il setup.sh dovrebbe già aver configurato questo
   cat ~/.ssh/authorized_keys | grep "claude-workspace"
   ```

3. **Test connessione**:
   ```bash
   ssh nullrunner@localhost
   ```

## Setup Laptop

### Metodo 1: Setup Rapido (Consigliato)

1. **Sul PC fisso, avviare il server temporaneo**:
   ```bash
   cd ~/claude-workspace
   python3 -m http.server 8000
   ```

2. **Sul laptop, scaricare ed eseguire**:
   ```bash
   curl -o laptop-setup.sh http://192.168.1.106:8000/scripts/setup-laptop.sh
   chmod +x laptop-setup.sh
   ./laptop-setup.sh
   ```

3. **Inserire la chiave SSH quando richiesto**

### Metodo 2: Setup Manuale

1. **Creare la struttura delle directory**:
   ```bash
   mkdir -p ~/claude-workspace/{projects/{active,sandbox,production},scripts,logs}
   ```

2. **Copiare gli script necessari**:
   ```bash
   scp nullrunner@192.168.1.106:~/claude-workspace/scripts/{sync-now.sh,auto-sync.sh,sync-status.sh} ~/claude-workspace/scripts/
   chmod +x ~/claude-workspace/scripts/*.sh
   ```

3. **Configurare SSH**:
   ```bash
   # Generare chiave SSH
   ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key -C "laptop-claude"
   
   # Copiare la chiave pubblica sul PC fisso
   ssh-copy-id -i ~/.ssh/claude_workspace_key nullrunner@192.168.1.106
   ```

4. **Configurare SSH config**:
   ```bash
   cat >> ~/.ssh/config << EOF
   Host claude-desktop
       HostName 192.168.1.106
       User nullrunner
       IdentityFile ~/.ssh/claude_workspace_key
       StrictHostKeyChecking no
       UserKnownHostsFile /dev/null
   EOF
   ```

5. **Test iniziale**:
   ```bash
   ~/claude-workspace/scripts/sync-now.sh
   ```

6. **Inizializzare memoria sul laptop**:
   ```bash
   # Dopo primo sync, la memoria dovrebbe già essere sincronizzata
   # Verifica funzionamento
   claude-resume
   
   # Se non funziona, inizializza manualmente
   claude-save "Setup laptop completato"
   
   # Test memoria per-progetto
   cd ~/claude-workspace/projects/active
   mkdir test-project
   cd test-project
   claude-project-memory save "Test progetto inizializzato"
   ```

### Configurazione Sync Automatico

1. **Abilitare sync automatico**:
   ```bash
   ~/claude-workspace/scripts/auto-sync.sh enable
   ```

2. **Verificare crontab**:
   ```bash
   crontab -l | grep claude-workspace
   ```

   Dovrebbe mostrare:
   ```
   */5 * * * * ~/claude-workspace/scripts/sync-now.sh >> ~/claude-workspace/logs/auto-sync.log 2>&1
   ```

3. **Monitorare i log**:
   ```bash
   tail -f ~/claude-workspace/logs/auto-sync.log
   ```

## Troubleshooting Comune

### Problema: Sistema memoria non funziona

**Sintomi**: Comandi `claude-save` o `claude-project-memory` non funzionano

**Soluzioni**:
```bash
# Verifica esistenza directory memoria
ls -la ~/claude-workspace/.claude/memory/

# Se non esiste, crea manualmente
mkdir -p ~/claude-workspace/.claude/memory/projects

# Verifica permessi
chmod 700 ~/claude-workspace/.claude/memory
chmod 755 ~/claude-workspace/.claude/memory/projects

# Test script memoria
which claude-save
ls -la ~/claude-workspace/scripts/claude-*.sh

# Se mancano, aggiungi al PATH o usa path completo
~/claude-workspace/scripts/claude-save.sh "Test memoria"
```

### Problema: Memoria non sincronizza tra dispositivi

**Causa**: Directory `.claude/memory/` non inclusa nel sync

**Soluzione**:
```bash
# Verifica file .rsync-exclude
cat ~/claude-workspace/.rsync-exclude | grep -v "^#" | grep "claude"

# Se .claude è escluso, rimuovilo
sed -i '/\.claude/d' ~/claude-workspace/.rsync-exclude

# Forza sync memoria
rsync -avz ~/claude-workspace/.claude/ nullrunner@192.168.1.106:~/claude-workspace/.claude/
```

### Problema: "Permission denied" durante SSH

**Causa**: Chiave SSH non riconosciuta o permessi errati

**Soluzione**:
```bash
# Sul laptop
ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key
cat ~/.ssh/claude_workspace_key.pub

# Sul PC fisso
echo "CHIAVE_PUBBLICA_QUI" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### Problema: "Connection refused" su porta 22

**Causa**: SSH server non attivo sul PC fisso

**Soluzione**:
```bash
# Sul PC fisso
sudo systemctl status ssh
sudo systemctl start ssh
sudo systemctl enable ssh
```

### Problema: Sync fallisce silenziosamente

**Causa**: Problemi di rete o configurazione

**Debug**:
```bash
# Test connessione diretta
ssh -v nullrunner@192.168.1.106

# Test rsync manuale
rsync -avz --dry-run ~/claude-workspace/projects/ nullrunner@192.168.1.106:~/claude-workspace/projects/
```

### Problema: File di lock bloccato

**Sintomo**: Messaggio "Another sync is already running"

**Soluzione**:
```bash
# Sul laptop
rm ~/claude-workspace/.sync.lock

# Verificare processi rsync zombie
ps aux | grep rsync
# Se necessario: killall rsync
```

### Problema: Spazio disco insufficiente

**Controllo**:
```bash
# Su entrambi i sistemi
df -h ~/claude-workspace
du -sh ~/claude-workspace/*
```

**Pulizia**:
```bash
# Rimuovere log vecchi
find ~/claude-workspace/logs -name "*.log" -mtime +30 -delete

# Archiviare progetti vecchi
tar -czf ~/backups/old-projects-$(date +%Y%m%d).tar.gz ~/claude-workspace/projects/production/old-project
rm -rf ~/claude-workspace/projects/production/old-project
```

## Configurazioni Avanzate

### Escludere file dal sync

Creare `~/claude-workspace/.rsync-exclude`:
```
*.tmp
*.log
node_modules/
__pycache__/
.git/
*.swp
.DS_Store
```

### Modificare frequenza sync

Editare crontab:
```bash
crontab -e
# Cambiare */5 con */10 per sync ogni 10 minuti
```

### Backup automatico

Aggiungere a crontab sul PC fisso:
```bash
0 2 * * * tar -czf ~/backups/claude-workspace-$(date +\%Y\%m\%d).tar.gz ~/claude-workspace/
```

## Verifica Post-Setup

### Checklist PC Fisso
- [ ] Directory structure creata
- [ ] Scripts eseguibili
- [ ] SSH server attivo
- [ ] Controllo accessi configurato
- [ ] Log directory scrivibile
- [ ] Sistema memoria inizializzato
- [ ] Comandi claude-save e claude-resume funzionanti
- [ ] Directory .claude/memory/ creata con permessi corretti

### Checklist Laptop
- [ ] SSH key configurata
- [ ] Connessione SSH funzionante
- [ ] Scripts di sync funzionanti
- [ ] Sync automatico configurato (opzionale)
- [ ] Primo sync completato con successo
- [ ] Memoria sincronizzata dal PC fisso
- [ ] Comandi memoria funzionanti (claude-save, claude-project-memory)
- [ ] Test progetto con memoria completato

## Comandi Utili per Debug

```bash
# Verificare connettività
ping -c 3 192.168.1.106
nc -zv 192.168.1.106 22

# Debug SSH
ssh -vvv nullrunner@192.168.1.106

# Test rsync con output verbose
rsync -avz --dry-run --progress ~/claude-workspace/projects/ nullrunner@192.168.1.106:~/claude-workspace/projects/

# Controllare log di sistema
journalctl -u ssh -f  # Sul PC fisso
tail -f /var/log/auth.log  # Sul PC fisso

# Monitorare sync in tempo reale
watch -n 1 'ls -la ~/claude-workspace/.sync.lock; tail -5 ~/claude-workspace/logs/sync.log'

# Debug sistema memoria
# Verifica struttura memoria
find ~/claude-workspace/.claude/memory -type f -name "*.json" | head -10

# Test comandi memoria
claude-save "Test sistema memoria" && claude-resume

# Verifica dimensione memoria
du -sh ~/claude-workspace/.claude/memory/

# Lista progetti con memoria
claude-project-memory list

# Statistiche memoria
claude-memory-cleaner stats

# Test sincronizzazione memoria cross-device
rsync -avz --dry-run ~/claude-workspace/.claude/ nullrunner@192.168.1.106:~/claude-workspace/.claude/
```