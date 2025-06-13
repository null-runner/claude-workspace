# Claude Workspace

## Controllo Iniziale (OBBLIGATORIO)
All'inizio di OGNI conversazione - tono amichevole "vediamo dove eravamo rimasti":
1. `git status` - file modificati
2. Leggi `.memory/` più recente 
3. Controlla `logs/sync.log` ultimo sync
4. `ls projects/active/` progetti attivi
5. **Recap veloce con colori ANSI:**
   - 📊 **Stato**: file pending, memoria, ultimo sync
   - 🚨 **Issues**: problemi da risolvere (se ci sono)
   - 🎯 **Next**: 1-3 azioni concrete da fare subito

## CRITICO: Commit
`git commit -m "msg" && git push` - SEMPRE pushare!  
Co-Authored-By: nullrunner <nullrunner@users.noreply.github.com>

## Regole
- **Bilingue**: OGNI modifica doc in EN e IT 
- README max 200 righe + sezione neofiti
- Usare TodoWrite per task complessi

## Comandi
- Sync: `./scripts/sync.sh`
- Memoria: `./scripts/memory.sh save "desc"`
- Progetti: `ls projects/active/`