# Claude Workspace - Istruzioni per Claude

## Controllo Iniziale
Esegui automaticamente:
1. `git status` per file modificati
2. Leggi memoria recente in `.memory/`
3. Controlla `logs/sync.log` per sync
4. Lista `projects/active/`
5. Riassumi situazione e suggerisci azioni

## Commit e Push (CRITICO)
```bash
git commit -m "Titolo modifiche

- Dettaglio 1
- Dettaglio 2

Co-Authored-By: nullrunner <nullrunner@users.noreply.github.com>
" && git push
```
⚠️ SEMPRE commit+push insieme! Sync automatico si basa su GitHub.

## Documentazione
- README max 200 righe, bilingue EN/IT
- Docs in `docs/getting-started/`, `docs/guides/`, `docs/planning/`  
- Sezione neofiti sempre inclusa

## Comandi
- Sync: `./scripts/sync.sh`
- Memoria: `./scripts/memory.sh save "desc"`
- Progetti: `ls projects/active/`