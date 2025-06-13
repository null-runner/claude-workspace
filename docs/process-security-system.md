# Claude Workspace Process Security System

Sistema di gestione sicura dei processi per prevenire kill accidentali di processi critici.

## 🛡️ Panoramica

Il sistema di sicurezza dei processi di Claude Workspace implementa multiple validazioni per prevenire la terminazione accidentale di processi critici, specialmente Claude Code stesso e processi di sistema.

## 🚨 Problemi Risolti

### Problemi Precedenti
- **False positive**: Script che uccidevano processi con nomi simili
- **Mancanza ownership check**: Possibile kill di processi di altri utenti  
- **No whitelist**: Nessuna protezione per processi critici
- **Kill immediato**: Nessuna terminazione graceful
- **No logging**: Difficile debug in caso di problemi

### Soluzioni Implementate
- **Validazione multipla**: Ownership + whitelist + pattern matching
- **Graceful termination**: SIGTERM poi SIGKILL se necessario
- **Whitelist protettiva**: Protezione automatica processi critici
- **Logging completo**: Tracciamento di tutte le operazioni
- **API centralizzata**: Sistema unificato per tutti gli script

## 📁 Componenti del Sistema

### `claude-process-manager.sh`
Sistema centralizzato di gestione processi con funzionalità complete:

```bash
# Gestione servizi
claude-process-manager register <name> <pid> [description]
claude-process-manager kill-service <name> [timeout]
claude-process-manager list

# Terminazione sicura
claude-process-manager kill-pid <pid> [pattern] [timeout]
claude-process-manager find-processes <pattern>

# Manutenzione
claude-process-manager cleanup
claude-process-manager emergency-stop
```

### `claude-safe-process.sh`
Wrapper semplificato per operazioni comuni:

```bash
# Operazioni base
claude-safe-process kill-pattern "claude-sync" 5
claude-safe-process find "python.*script"
claude-safe-process is-safe 1234

# Gestione servizi
claude-safe-process register my-daemon 1234 "Background service"
claude-safe-process kill-service my-daemon
```

## 🔒 Whitelist Processi Protetti

Il sistema protegge automaticamente questi tipi di processi:

### Processi Sistema
- `systemd`, `kernel`, `init`, `kthreadd`
- `dbus`, `systemd-*`, `udev`, `cron`

### Claude Code e Development
- `claude-code`, `claude`, `code`
- `/usr/bin/code`, `/snap/code/`
- `docker`, `node`, `python3`, `java`

### Network e SSH
- `ssh`, `sshd`, `NetworkManager`
- `wpa_supplicant`

### Desktop Environment
- `gnome-*`, `kde-*`, `xfce-*`
- `X11`, `Xorg`, `wayland`

### Shell e Terminal
- `bash`, `zsh`, `fish`, `sh`
- `tmux`, `screen`, `terminal`

### Package Managers
- `apt`, `dpkg`, `snap`, `flatpak`
- `yum`, `dnf`

## 🔧 Integrazione negli Script

### Migrazione da kill/pkill unsafe
**Prima (unsafe):**
```bash
pkill -f "claude-sync"
kill $PID
```

**Dopo (safe):**
```bash
claude-safe-process kill-pattern "claude-sync"
claude-safe-process kill-pid $PID "claude-sync"
```

### Validazione prima del kill
```bash
if claude-safe-process is-safe $PID "pattern"; then
    claude-safe-process kill-pid $PID "pattern"
else
    echo "Process is protected or not owned by current user"
fi
```

### Registrazione servizi di background
```bash
my_daemon &
DAEMON_PID=$!
claude-safe-process register "my-daemon" $DAEMON_PID "Background service"

# Più tardi...
claude-safe-process kill-service "my-daemon"
```

## 📊 Logging e Monitoring

### File di Log
- **Process Manager**: `.claude/processes/process-manager.log`
- **Service Registry**: `.claude/processes/pids/`

### Informazioni Loggate
- Tutti i tentativi di kill con risultato
- Processi protetti dalla whitelist
- Violazioni di ownership
- Operazioni di registrazione/rimozione servizi

### Esempio Log Entry
```
[2025-06-14 01:48:14] [INFO] PID 71975 validated: sleep
[2025-06-14 01:48:14] [INFO] Attempting safe termination of PID 71975 (sleep)
[2025-06-14 01:48:15] [INFO] Process 71975 terminated gracefully
[2025-06-14 01:48:20] [ERROR] SAFETY: PID 1 (init) is whitelisted and should NOT be killed!
```

## 🧪 Testing

### Test Automatici
```bash
# Test di protezione whitelist
claude-process-manager validate-pid 1 init  # Dovrebbe fallire

# Test terminazione safe
sleep 60 &
TEST_PID=$!
claude-process-manager kill-pid $TEST_PID sleep 3  # Dovrebbe riuscire
```

### Verifiche Manuali
```bash
# Lista processi trovati senza kill
claude-safe-process find bash

# Verifica whitelist
claude-process-manager init-whitelist
cat ~/.claude-workspace/.claude/processes/safe-processes.whitelist
```

## 🚀 Script Aggiornati

Gli script seguenti sono stati aggiornati per usare il sistema sicuro:

### Core Scripts
- **claude-smart-exit.sh**: Terminazione sicura Claude Code
- **claude-autonomous-system.sh**: Stop sicuro servizi background
- **claude-smart-sync.sh**: Gestione sicura sync daemon

### Sync Scripts  
- **claude-intelligent-auto-sync.sh**: Stop sicuro processi sync
- **claude-full-workspace-sync.sh**: Emergency stop sicuro
- **cexit-safe**: Cleanup sicuro all'exit

### Utility Scripts
- **setup-laptop.sh**: Cleanup sicuro durante setup
- **claude-disable.sh**: Stop sicuro servizi

## 🔄 Backwards Compatibility

Il sistema include fallback per compatibilità:

```bash
# Se process manager non disponibile, usa metodo base con ownership check
if [[ -f "$process_manager" ]]; then
    "$process_manager" kill-pid "$pid" "$pattern" 10
else
    # Fallback con basic ownership validation
    local owner=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')
    [[ "$owner" == "$(id -u)" ]] && kill "$pid" 2>/dev/null
fi
```

## 📈 Benefici

### Sicurezza
- ✅ **Zero risk** di kill accidentali di Claude Code
- ✅ **Protezione sistema** da kill di processi critici
- ✅ **Isolamento utenti** tramite ownership validation

### Affidabilità
- ✅ **Graceful shutdown** con fallback a force kill
- ✅ **Logging completo** per debugging
- ✅ **Recovery automatico** da stati inconsistenti

### Usabilità
- ✅ **API semplificata** tramite wrapper
- ✅ **Integrazione trasparente** negli script esistenti
- ✅ **Debugging facilitato** tramite validazione e logging

## 🛠️ Manutenzione

### Cleanup Periodico
```bash
# Rimuove PID file orfani
claude-process-manager cleanup

# Emergency stop di tutti i servizi registrati
claude-process-manager emergency-stop
```

### Aggiornamento Whitelist
```bash
# Reinizializza whitelist con nuovi pattern
claude-process-manager init-whitelist

# Modifica manuale
vim ~/.claude-workspace/.claude/processes/safe-processes.whitelist
```

### Monitoring Status
```bash
# Status servizi registrati
claude-process-manager list

# Log recenti
tail -f ~/.claude-workspace/.claude/processes/process-manager.log
```

---

**Nota**: Questo sistema è progettato per essere fail-safe. In caso di dubbio, preferisce NON killare un processo piuttosto che rischiare un kill accidentale di processo critico.