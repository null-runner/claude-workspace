# Claude Workspace

<!-- CLAUDE.MD deve essere MINIMAL - solo direttive essenziali, niente commenti inutili -->

## Controllo Iniziale (OBBLIGATORIO)
All'inizio di OGNI conversazione - tono amichevole "vediamo dove eravamo rimasti":
1. `./scripts/claude-startup.sh` - avvia sistema completamente autonomo
2. `./scripts/claude-simplified-memory.sh load` - carica context sessione
3. `git status` - file modificati
4. **Recap automatico con info da sistema autonomo:**
   - 📊 **Stato**: context caricato, progetto rilevato, sistema attivo
   - 🚨 **Issues**: eventuali problemi rilevati automaticamente  
   - 🎯 **Next**: azioni suggerite dal sistema intelligente

**Nota**: File di sistema (.claude/*, logs/*) sono automaticamente ignorati dal git e NON sono errori.

## Exit Hook (Disabilitato)
**Exit hook automatico DISABILITATO per sicurezza**:
- Exit hook automatico rimosso per evitare interferenze
- Comando `exit` normale funziona come standard (nessun hook)
- Per graceful exit usare `cexit` manualmente quando necessario

**Opzioni per graceful exit**:
- `cexit` / `./scripts/cexit` - graceful exit + terminazione forzata Claude Code
- `./scripts/cexit-safe` - graceful exit + lascia sessione aperta (raccomandato)  
- `exit` - exit normale senza alcun hook automatico

## CRITICO: Commit Frequenti
**COMMIT IMMEDIATO OBBLIGATORIO** dopo modifiche a:
- Script critici (cexit, startup, sync, autonomous, exit-hook)
- CLAUDE.md o documentazione
- Configurazioni sistema (.claude/*)
- Qualsiasi modifica richiesta dall'user

**SEMPRE usare DUE comandi bash consecutivi:**
1. `git add .`
2. `git commit -m "msg"`
3. `git push`

**OBBLIGATORIO: Tutti i commit devono essere firmati:**
```bash
🤖 Generated with Claude Workspace (by null-runner)
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Sistema Autonomo (Enterprise-Grade)
Il workspace ora è **completamente autonomo** e **enterprise-stable**:
- **Memoria Unificata**: Un solo coordinator per tutti i sistemi memoria (no più conflitti)
- **File Locking**: Zero corruption con locking automatico per tutti i file JSON
- **Sync Coordinato**: Queue-based sync, rate limiting, zero race conditions
- **Exit Hook Sicuro**: Detection Claude Code automatica, mai crash dell'IDE
- **Process Security**: Whitelist protezione, ownership validation, kill safe
- **Operazioni Atomiche**: File critici (PID, state, config) scritti atomicamente
- **Error Handling**: Sistema enterprise con timeout, retry, graceful degradation
- **Performance**: 23x faster con caching, batch operations, overhead ridotto
- **Backup Intelligence**: Retention policies, cleanup automatico, recovery strategies
- **Master Daemon**: Sistema unificato che gestisce tutti i servizi in background

## Regole
- **Bilingue**: OGNI modifica doc in EN e IT 
- README max 200 righe + sezione neofiti
- Usare TodoWrite per task complessi

## Comandi Principali
- **Setup**: `./scripts/claude-setup-profile.sh setup` (primo avvio)
- **Startup**: `./scripts/claude-startup.sh` (avvia tutto automaticamente)
- **Status**: `./scripts/claude-autonomous-system.sh status` (stato servizi)
- **Memory**: `./scripts/claude-simplified-memory.sh load/save` (context Claude)
- **Exit**: `./scripts/claude-smart-exit.sh` (uscita intelligente con analisi attività)
- **Smart Sync**: `./scripts/claude-smart-sync.sh start/stop/status` (auto-sync intelligente)
- **Sync Manual**: `./scripts/sync-now.sh` (backup remoto manuale)

## Comandi Debug
- `./scripts/claude-auto-project-detector.sh test` - test detection progetti
- `./scripts/claude-intelligence-extractor.sh summary` - mostra insights estratti
- `./scripts/claude-autonomous-system.sh logs` - log sistema autonomo

## Profilo Utente
Il workspace ha un profilo utente configurato. Claude personalizza:
- Livello dettaglio spiegazioni basato su competenza
- Tono e stile comunicazione  
- Assunzioni su conoscenze pregresse
- Saluti e interazioni

Usa `claude-setup-profile edit` per modificare.