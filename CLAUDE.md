# Claude Workspace - Istruzioni per Claude

## Controllo Iniziale Automatico

All'inizio di ogni conversazione, esegui automaticamente questi controlli:

1. **Analizza lo stato del progetto**:
   - Controlla git status per vedere file modificati
   - Leggi il file di memoria più recente in `.memory/`
   - Verifica l'ultimo sync dal log
   - Identifica progetti attivi in `projects/active/`

2. **Riassumi la situazione**:
   - Su cosa si stava lavorando (da memoria e commit)
   - File modificati non committati
   - Prossimi passi pianificati
   - Eventuali problemi di sincronizzazione

3. **Suggerisci azioni**:
   - Se ci sono file da committare
   - Se è necessario un sync manuale
   - Se ci sono TODO da completare

## Struttura Documentazione

La documentazione è organizzata in modo gerarchico:

### README Files
- `README.md` - Entry point principale (EN) - max 200 righe
- `README_IT.md` - Entry point principale (IT) - max 200 righe
- Include quick-start guide e sezione per neofiti/vibe coders
- Link alla documentazione dettagliata in `docs/`

### Documentazione Dettagliata (`docs/`)
```
docs/
├── getting-started/          # Per iniziare
│   ├── setup-en.md          # Installazione (EN)
│   └── setup-it.md          # Installazione (IT)
├── guides/                  # Guide approfondite
│   ├── memory-system-en.md  # Sistema memoria (EN)
│   ├── memory-system-it.md  # Sistema memoria (IT)
│   ├── sandbox-system-it.md # Sistema sandbox (IT)
│   ├── workflow-en.md       # Flusso di lavoro (EN)
│   ├── workflow-it.md       # Flusso di lavoro (IT)
│   └── security/            # Sicurezza
│       ├── security-en.md   # Sicurezza (EN)
│       └── security-it.md   # Sicurezza (IT)
├── planning/                # Pianificazione
│   └── public-workspace-planning.md  # Piano workspace pubblico
└── reference/               # Riferimenti (futuro)
```

### Regole per la Documentazione
1. **Bilingue**: Ogni documento deve avere versione EN e IT
2. **README semplici**: Max 200 righe, entry point friendly
3. **Struttura gerarchica**: Documentazione dettagliata in sottocartelle
4. **Link interni**: Mantenere riferimenti incrociati aggiornati
5. **Sezione neofiti**: Sempre includere spiegazioni per non-programmatori

## Comandi Utili

- Per sync manuale: `./scripts/sync.sh`
- Per salvare memoria: `./scripts/memory.sh save "descrizione"`
- Per vedere progetti attivi: `ls projects/active/`

## Regole per Commit e Push

⚠️ **CRITICO**: Ogni commit DEVE essere seguito IMMEDIATAMENTE da push!

### Procedura Obbligatoria:
1. `git add .` (o file specifici)
2. `git commit -m "messaggio"`
3. `git push` **IMMEDIATAMENTE**

### Formato Commit:
```bash
git commit -m "$(cat <<'EOF'
🔥 Titolo descrittivo del cambiamento

- Punto 1 delle modifiche
- Punto 2 delle modifiche
- Punto 3 delle modifiche

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)" && git push
```

### Perché è Critico:
- Il sistema di sync automatico si basa sui commit su GitHub
- Commit solo locali rompono la sincronizzazione
- Altri device non vedono le modifiche
- Il workspace diventa inconsistente

## Note Importanti

- Il sistema fa sync automatico ogni 5 minuti **DA GITHUB**
- I file di memoria sono in `.memory/` con timestamp
- I log di sync sono in `logs/sync.log`
- Documentazione sempre bilingue (EN/IT)
- README deve rimanere sotto 200 righe e essere friendly
- **SEMPRE committare E pushare insieme**