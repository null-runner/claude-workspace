# Guida Setup Completa - Claude Workspace Enterprise

Questa guida copre il setup completo del sistema Claude Workspace Enterprise-Grade sia per il PC fisso che per il laptop. Il sistema è ora dotato di componenti enterprise per massima robustezza e performance.

## Setup PC Fisso

### Prerequisiti
- Ubuntu/Debian o sistema Linux compatibile
- Git installato
- Accesso SSH configurato
- Python 3.x (richiesto per componenti enterprise)
- **Nuovo**: jq (JSON processor) per coordinatori
- **Nuovo**: flock utility per file locking
- **Minimo**: 2GB RAM liberi per sistema autonomo
- **Raccomandato**: SSD per performance ottimale

### Installazione step-by-step

1. **Clonare o creare la struttura base**:
   ```bash
   cd ~
   git clone <repository-url> claude-workspace
   # oppure
   mkdir -p ~/claude-workspace/{projects/{active,sandbox,production},scripts,configs,logs,docs}
   ```

2. **Eseguire lo script di setup enterprise**:
   ```bash
   cd ~/claude-workspace
   chmod +x setup.sh
   ./setup.sh --enterprise
   ```
   
   **Nota**: Il flag `--enterprise` abilita componenti avanzati:
   - Sistema di coordinamento processi
   - File locking avanzato
   - Backup automatico enterprise
   - Monitoraggio performance

3. **Cosa fa lo script setup.sh --enterprise**:
   - Crea tutte le directory necessarie (incluse enterprise)
   - Imposta i permessi corretti (755 per directory, 644 per file)
   - Crea il file di controllo accessi con protezione processi
   - Genera gli script di gestione enterprise
   - Configura il logging multi-livello
   - **Nuovo**: Inizializza coordinatori (memory, sync, project)
   - **Nuovo**: Configura sistema di lock distribuito
   - **Nuovo**: Installa componenti di monitoraggio
   - **Nuovo**: Setup rotazione log automatica

4. **Verificare l'installazione enterprise**:
   ```bash
   ~/claude-workspace/scripts/claude-startup.sh
   ```

   Output atteso enterprise:
   ```
   🚀 CLAUDE WORKSPACE ENTERPRISE STARTUP
   =====================================
   📍 Sistema Autonomo: ATTIVO
   🎯 Coordinatori: OK (3/3)
   🔒 File Locking: ENABLED
   📊 Monitoraggio: HEALTHY
   🧠 Memoria: LOADED
   🔄 Sync: READY
   
   ✅ Sistema enterprise completamente operativo
   ```

5. **Inizializzare sistema memoria enterprise**:
   ```bash
   # Avvia coordinatore memoria
   ~/claude-workspace/scripts/claude-memory-coordinator.sh start
   
   # Inizializza memoria globale workspace
   ~/claude-workspace/scripts/claude-simplified-memory.sh save "Sistema Claude Workspace Enterprise inizializzato"
   
   # Verifica funzionamento
   ~/claude-workspace/scripts/claude-simplified-memory.sh load
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

### Configurazione Sync Enterprise

1. **Abilitare sync enterprise con coordinatore**:
   ```bash
   ~/claude-workspace/scripts/claude-sync-coordinator.sh enable
   ~/claude-workspace/scripts/claude-smart-sync.sh start
   ```

2. **Verificare servizi enterprise**:
   ```bash
   ~/claude-workspace/scripts/claude-autonomous-system.sh status
   ```

   Dovrebbe mostrare:
   ```
   📊 ENTERPRISE SERVICES STATUS
   ===========================
   Master Daemon: RUNNING
   Sync Coordinator: ACTIVE
   Memory Coordinator: HEALTHY
   Project Monitor: MONITORING
   Intelligence Extractor: LEARNING
   ```

3. **Monitorare i log enterprise**:
   ```bash
   ~/claude-workspace/scripts/claude-autonomous-system.sh logs
   ```

## Exit Sicuro Sistema Enterprise

### 🗂️ Comando cexit (Raccomandato)

Per uscire dal sistema enterprise in modo sicuro:

```bash
# Exit sicuro mantenendo sessione aperta (raccomandato)
~/claude-workspace/scripts/cexit-safe

# Exit completo con terminazione Claude Code
~/claude-workspace/scripts/cexit

# Exit con sync forzato
~/claude-workspace/scripts/cexit --force-sync
```

**Importante**: 
- **NON usare** `exit` normale - non attiva il graceful shutdown
- **Usa sempre** `cexit` o `cexit-safe` per preservare stato sistema
- Il sistema enterprise richiede shutdown coordinato

### Cosa fa cexit
1. 💾 Salva automaticamente stato sessione
2. 🔄 Sync intelligente finale
3. 📊 Aggiorna statistiche performance
4. 🔒 Rilascia tutti i lock
5. 🚫 Termina servizi background
6. 🔍 Analizza attività sessione per insights

## Troubleshooting Enterprise

### Problema: Sistema memoria enterprise non funziona

**Sintomi**: Coordinatore memoria non risponde o memoria non sincronizza

**Soluzioni Enterprise**:
```bash
# Verifica coordinatore memoria
~/claude-workspace/scripts/claude-memory-coordinator.sh status

# Riavvia coordinatore se necessario
~/claude-workspace/scripts/claude-memory-coordinator.sh restart

# Verifica struttura enterprise
ls -la ~/claude-workspace/.claude/memory-coordination/
ls -la ~/claude-workspace/.claude/logs/

# Test memoria con coordinatore
~/claude-workspace/scripts/claude-simplified-memory.sh save "Test memoria enterprise"
~/claude-workspace/scripts/claude-simplified-memory.sh load

# Verifica lock files
ls -la ~/claude-workspace/.claude/*.lock

# Pulisci lock se bloccati
~/claude-workspace/scripts/claude-sync-lock.sh cleanup
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

### Problema: Sistema lock enterprise bloccato

**Sintomo**: "Lock acquisition failed" o coordinatori non rispondono

**Soluzione Enterprise**:
```bash
# Diagnosi lock enterprise
~/claude-workspace/scripts/claude-sync-lock.sh status

# Cleanup lock automatico
~/claude-workspace/scripts/claude-sync-lock.sh cleanup

# Verifica coordinatori
~/claude-workspace/scripts/claude-autonomous-system.sh status

# Riavvio coordinatori se necessario
~/claude-workspace/scripts/claude-memory-coordinator.sh restart
~/claude-workspace/scripts/claude-sync-coordinator.sh restart

# Verifica processi enterprise
ps aux | grep -E "(claude-.*coordinator|autonomous-system)"

# Recovery completo sistema
~/claude-workspace/scripts/claude-startup.sh --recovery
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