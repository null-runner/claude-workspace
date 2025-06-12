# Sicurezza - Claude Workspace

Questa guida descrive il sistema di sicurezza implementato in Claude Workspace e le best practices per mantenerlo sicuro.

## Come funziona la sicurezza

Il sistema Claude Workspace implementa diversi livelli di sicurezza:

### 1. Autenticazione SSH basata su chiavi

**Principio**: Solo dispositivi con chiavi SSH autorizzate possono accedere

**Implementazione**:
- Nessuna autenticazione con password
- Chiavi ED25519 (più sicure di RSA)
- Una chiave univoca per ogni dispositivo

**Configurazione**:
```bash
# Generazione chiave sicura
ssh-keygen -t ed25519 -b 256 -f ~/.ssh/claude_workspace_key -C "device-identifier"

# Permessi corretti
chmod 700 ~/.ssh
chmod 600 ~/.ssh/claude_workspace_key
chmod 644 ~/.ssh/claude_workspace_key.pub
```

### 2. Sistema di controllo accessi

**File di controllo**: `~/claude-workspace/configs/access_control.conf`

**Struttura**:
```
# Access Control Configuration
# Format: DEVICE_ID|PUBLIC_KEY|STATUS|LAST_ACCESS
laptop-nullrunner|ssh-ed25519 AAAAC3...|ENABLED|2025-01-06 10:30:45
```

**Stati possibili**:
- `ENABLED`: Dispositivo autorizzato
- `DISABLED`: Accesso temporaneamente disabilitato
- `BLOCKED`: Accesso permanentemente bloccato

### 3. Validazione dei dispositivi

**Script di controllo**: Prima di ogni sync, il sistema verifica:

1. **Chiave SSH valida**:
   ```bash
   # Estratto da sync-now.sh
   SSH_KEY=$(ssh-keygen -lf ~/.ssh/claude_workspace_key.pub | awk '{print $2}')
   ```

2. **Dispositivo autorizzato**:
   ```bash
   # Verifica sul server
   grep "$SSH_KEY" ~/claude-workspace/configs/access_control.conf | grep "ENABLED"
   ```

3. **IP di origine** (opzionale):
   ```bash
   # In .ssh/authorized_keys
   from="192.168.1.*" ssh-ed25519 AAAAC3...
   ```

## Sistema di controllo accessi

### Architettura del controllo

```
Laptop → SSH Key → PC Fisso → Verifica access_control.conf → Accesso
                      ↓
                  Log accesso
```

### Script di gestione

1. **claude-status.sh**: Mostra stato attuale
   ```bash
   ~/claude-workspace/scripts/claude-status.sh
   ```

2. **claude-enable.sh**: Abilita accesso temporaneo
   ```bash
   ~/claude-workspace/scripts/claude-enable.sh
   # Durata default: 24 ore
   ```

3. **claude-disable.sh**: Disabilita accesso
   ```bash
   ~/claude-workspace/scripts/claude-disable.sh
   ```

### Logging degli accessi

Tutti gli accessi vengono registrati in:
- `~/claude-workspace/logs/access.log`: Log degli accessi
- `~/claude-workspace/logs/sync.log`: Log delle sincronizzazioni
- `/var/log/auth.log`: Log SSH di sistema

Formato log:
```
[2025-01-06 10:30:45] ACCESS_GRANTED: laptop-nullrunner from 192.168.1.150
[2025-01-06 10:31:02] SYNC_START: laptop-nullrunner
[2025-01-06 10:31:15] SYNC_COMPLETE: laptop-nullrunner (1.2MB transferred)
```

## Best Practices

### 1. Gestione delle chiavi SSH

**DO**:
- Usare chiavi diverse per ogni dispositivo
- Proteggere le chiavi private con passphrase
- Ruotare le chiavi periodicamente (ogni 6 mesi)
- Backup sicuro delle chiavi

**DON'T**:
- Condividere chiavi tra dispositivi
- Lasciare chiavi senza passphrase
- Commettere chiavi in repository Git
- Usare chiavi RSA < 2048 bit

**Rotazione chiavi**:
```bash
# Sul laptop
ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key_new
ssh-copy-id -i ~/.ssh/claude_workspace_key_new nullrunner@192.168.1.106

# Sul PC fisso - rimuovere chiave vecchia
sed -i '/OLD_KEY_FINGERPRINT/d' ~/.ssh/authorized_keys

# Aggiornare access_control.conf
```

### 2. Monitoraggio accessi

**Controlli regolari**:
```bash
# Ultimi accessi
tail -50 ~/claude-workspace/logs/access.log | grep ACCESS

# Accessi falliti
grep "DENIED" ~/claude-workspace/logs/access.log

# Dispositivi attivi
~/claude-workspace/scripts/claude-status.sh | grep ENABLED
```

**Alert automatici** (opzionale):
```bash
# Aggiungere a crontab per notifiche
*/30 * * * * ~/claude-workspace/scripts/check-suspicious.sh
```

### 3. Protezione dei dati

**Dati sensibili**:
- Non salvare password in chiaro nei progetti
- Usare `.gitignore` per escludere file sensibili
- Criptare dati sensibili prima del sync

**Esempio .gitignore**:
```
# Secrets
.env
*.key
*.pem
secrets/
credentials/

# Personal data
*.sqlite
*.db
personal/
```

**Criptazione file sensibili**:
```bash
# Criptare
gpg -c sensitive-file.txt

# Decriptare
gpg -d sensitive-file.txt.gpg
```

**Protezione memoria sistema**:
```bash
# La memoria può contenere informazioni sensibili
# Escludere dal sync se necessario
echo ".claude/memory/projects/sensitive-project_*.json" >> .rsync-exclude

# Backup criptato della memoria
tar -czf - .claude/memory/ | gpg -c > memory-backup-$(date +%Y%m%d).tar.gz.gpg

# Verificare contenuto memoria per informazioni sensibili
grep -r "password\|secret\|key\|token" .claude/memory/ 2>/dev/null || echo "Nessun dato sensibile trovato"
```

### 4. Sicurezza di rete

**Firewall** (sul PC fisso):
```bash
# Permettere solo SSH dalla rete locale
sudo ufw allow from 192.168.1.0/24 to any port 22

# Bloccare tutto il resto
sudo ufw default deny incoming
sudo ufw enable
```

**SSH hardening**:
```bash
# In /etc/ssh/sshd_config
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
```

### 5. Sicurezza Sistema Memoria Intelligente

Il sistema di memoria può contenere informazioni sensibili sui progetti e richiede attenzione particolare.

**Rischi potenziali**:
- Informazioni di progetto sensibili salvate in memoria
- Credenziali o token accidentalmente salvati in note
- Storico sessioni con dati riservati
- Sincronizzazione memoria tra dispositivi non sicuri

**Mitigazioni**:

**Controllo contenuto memoria**:
```bash
# Audit regolare per dati sensibili
claude-memory-cleaner stats | grep "sensitive patterns"

# Verifica manuale contenuto
find .claude/memory -name "*.json" -exec grep -l "password\|secret\|token\|key" {} \; 2>/dev/null

# Pulizia mirata se trovati dati sensibili
claude-memory-cleaner project active/sensitive-project --sanitize
```

**Configurazione sicurezza memoria**:
```bash
# Escludere progetti sensibili da sync automatico
cat >> .rsync-exclude << EOF
.claude/memory/projects/*confidential*.json
.claude/memory/projects/*secret*.json
.claude/memory/projects/*private*.json
EOF

# Configurare retention limitata per progetti sensibili
# In .claude/memory/workspace-memory.json
{
  "settings": {
    "sensitive_projects": ["confidential-client", "secret-research"],
    "max_retention_days": 7,
    "auto_sanitize": true
  }
}
```

**Backup sicuro memoria**:
```bash
# Backup criptato completo
tar -czf - .claude/memory/ | gpg --cipher-algo AES256 -c > \
    ~/secure-backups/memory-backup-$(date +%Y%m%d).tar.gz.gpg

# Backup selettivo (solo progetti non sensibili)
tar -czf - .claude/memory/workspace-memory.json \
    $(find .claude/memory/projects -name "*.json" | grep -v -E "confidential|secret|private") | \
    gpg -c > memory-safe-backup-$(date +%Y%m%d).tar.gz.gpg
```

**Pulizia automatica sensibili**:
```bash
# Script di pulizia automatica da aggiungere a cron
#!/bin/bash
# ~/claude-workspace/scripts/memory-security-cleanup.sh

# Pattern sensibili da rimuovere automaticamente
SENSITIVE_PATTERNS=(
    "password"
    "secret"
    "token"
    "api_key"
    "private_key"
    "credential"
)

for pattern in "${SENSITIVE_PATTERNS[@]}"; do
    find .claude/memory -name "*.json" -exec sed -i "/$pattern/d" {} \; 2>/dev/null
done

echo "$(date): Memory security cleanup completed" >> logs/security.log
```

**Controllo accesso memoria**:
```bash
# Permessi restrittivi su directory memoria
chmod 700 .claude/memory
chmod 600 .claude/memory/workspace-memory.json
chmod 600 .claude/memory/projects/*.json

# Verifica permessi
find .claude/memory -type f ! -perm 600 -ls
find .claude/memory -type d ! -perm 700 -ls
```

### 6. Backup e recovery

**Backup delle configurazioni**:
```bash
# Backup settimanale completo (include memoria)
tar -czf ~/backups/claude-config-$(date +%Y%m%d).tar.gz \
    ~/.ssh/authorized_keys \
    ~/claude-workspace/configs/ \
    ~/claude-workspace/scripts/ \
    ~/claude-workspace/.claude/memory/

# Backup solo configurazioni (senza memoria)
tar -czf ~/backups/claude-config-minimal-$(date +%Y%m%d).tar.gz \
    ~/.ssh/authorized_keys \
    ~/claude-workspace/configs/ \
    ~/claude-workspace/scripts/
```

**Recovery plan**:
1. Ripristinare backup configurazioni
2. Verificare chiavi SSH
3. Controllare log per attività sospette
4. Verificare integrità memoria sistema
5. Re-sincronizzare progetti
6. Testare comandi memoria per funzionamento

## Gestione emergenze

### Dispositivo compromesso

1. **Disabilitare immediatamente**:
   ```bash
   # Sul PC fisso
   ~/claude-workspace/scripts/claude-disable.sh
   ```

2. **Rimuovere chiave SSH**:
   ```bash
   # Identificare la chiave
   grep "laptop-name" ~/claude-workspace/configs/access_control.conf
   
   # Rimuovere da authorized_keys
   sed -i '/CHIAVE_COMPROMESSA/d' ~/.ssh/authorized_keys
   ```

3. **Audit dei log**:
   ```bash
   # Verificare accessi recenti
   grep "laptop-name" ~/claude-workspace/logs/access.log | tail -100
   ```

4. **Cambiare tutte le chiavi**:
   - Generare nuove chiavi su tutti i dispositivi
   - Aggiornare authorized_keys
   - Aggiornare access_control.conf

### Accesso non autorizzato

**Indicatori**:
- Accessi da IP sconosciuti
- Sync in orari inusuali
- File modificati inaspettatamente

**Risposta**:
```bash
# 1. Bloccare accesso
~/claude-workspace/scripts/claude-disable.sh

# 2. Analizzare log
grep -E "DENIED|FAILED|ERROR" ~/claude-workspace/logs/*.log

# 3. Verificare integrità file
find ~/claude-workspace -type f -mtime -1 -ls

# 4. Backup immediato
tar -czf ~/emergency-backup-$(date +%Y%m%d-%H%M%S).tar.gz ~/claude-workspace/
```

## Checklist sicurezza periodica

### Giornaliera
- [ ] Controllare log accessi per anomalie
- [ ] Verificare sync completati con successo
- [ ] Verificare dimensione memoria sistema (< 10MB)

### Settimanale
- [ ] Backup configurazioni (include memoria)
- [ ] Review dispositivi autorizzati
- [ ] Controllare spazio disco
- [ ] Audit contenuto memoria per dati sensibili
- [ ] Testare recovery memoria da backup

### Mensile
- [ ] Audit completo dei log
- [ ] Verificare tutti i dispositivi autorizzati
- [ ] Testare procedure di recovery
- [ ] Aggiornare sistema operativo e SSH
- [ ] Pulizia completa memoria intelligente
- [ ] Verifica consistenza memoria cross-device

### Semestrale
- [ ] Rotazione chiavi SSH
- [ ] Review policy di sicurezza
- [ ] Penetration test interno
- [ ] Aggiornamento documentazione

## Comandi utili per la sicurezza

```bash
# Verificare fingerprint chiave SSH
ssh-keygen -lf ~/.ssh/claude_workspace_key.pub

# Controllare connessioni SSH attive
ss -tan | grep :22

# Monitorare tentativi di accesso
sudo tail -f /var/log/auth.log | grep ssh

# Verificare permessi file
find ~/claude-workspace -type f -perm /077 -ls

# Controllare processi sospetti
ps aux | grep -E "rsync|ssh" | grep -v grep

# Analizzare traffico di rete (richiede tcpdump)
sudo tcpdump -i any port 22 -n

# Verificare integrità con checksum
find ~/claude-workspace -type f -exec md5sum {} \; > checksums.txt
md5sum -c checksums.txt

# Comandi sicurezza memoria sistema
# Verificare dimensione memoria
du -sh .claude/memory/

# Audit contenuto memoria per dati sensibili
grep -r "password\|secret\|token\|key\|credential" .claude/memory/ 2>/dev/null

# Backup criptato memoria
tar -czf - .claude/memory/ | gpg -c > memory-secure-$(date +%Y%m%d).tar.gz.gpg

# Statistiche sicurezza memoria
claude-memory-cleaner stats | grep -E "size|sensitive|projects"

# Test recovery memoria
cp -r .claude/memory .claude/memory.test.backup
rm -rf .claude/memory
cp -r .claude/memory.test.backup .claude/memory

# Verifica permessi memoria
find .claude/memory -type f ! -perm 600 -o -type d ! -perm 700
```