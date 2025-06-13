# Claude Workspace

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

## CRITICO: Commit
SEMPRE usare DUE comandi bash consecutivi:
1. `git commit -m "msg"`
2. `git push`

**OBBLIGATORIO: Tutti i commit devono essere firmati:**
```bash
🤖 Generated with Claude Workspace (by null-runner)
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Sistema Autonomo
Il workspace ora è **completamente autonomo** con sync automatico:
- **Memoria Semplificata**: Context automatico per Claude senza scoring complesso
- **Detection Progetti**: Auto-start/stop tracking quando entri/esci da progetti  
- **Intelligence Extraction**: Auto-learning da git commits, log errors, file patterns
- **Smart Exit**: Analisi intelligente attività sessione, distingue crash da exit normale
- **Crash Detection**: Recovery automatico solo per crash reali, non per exit normali
- **Smart Sync**: Auto-sync workspace tra dispositivi basato su natural checkpoints
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