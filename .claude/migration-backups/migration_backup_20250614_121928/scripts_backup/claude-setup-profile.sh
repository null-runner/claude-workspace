#!/bin/bash
# Claude Setup Profile - Configurazione iniziale utente
# Personalizza spiegazioni e tono basato su livello competenza

WORKSPACE_DIR="$HOME/claude-workspace"
PROFILE_FILE="$WORKSPACE_DIR/.claude/user-profile.json"
CLAUDE_MD="$WORKSPACE_DIR/CLAUDE.md"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Crea directory se non esiste
mkdir -p "$WORKSPACE_DIR/.claude"

# Funzione per setup iniziale
setup_profile() {
    echo -e "${CYAN}🚀 CLAUDE WORKSPACE SETUP${NC}"
    echo -e "${BLUE}Configuriamo il tuo profilo per personalizzare l'esperienza${NC}"
    echo ""
    
    # Nome utente
    echo -e "${BOLD}👤 Come ti chiami?${NC}"
    read -p "Nome (per saluti personalizzati): " user_name
    
    # Assessment competenza tecnica
    echo ""
    echo -e "${BOLD}💻 ASSESSMENT COMPETENZA TECNICA${NC}"
    echo -e "${BLUE}Ti farò 5 domande pratiche per valutare il tuo livello.${NC}"
    echo -e "${BLUE}Questo aiuta Claude a calibrare spiegazioni e dettagli tecnici.${NC}"
    echo ""
    echo -e "${YELLOW}📋 In base al risultato, Claude adatterà:${NC}"
    echo "   • Livello di dettaglio nelle spiegazioni"
    echo "   • Quantità di commenti nel codice" 
    echo "   • Assunzioni su conoscenze pregresse"
    echo "   • Stile delle guide e tutorial"
    echo ""
    echo -e "${CYAN}💡 Puoi sempre modificare manualmente dopo se il livello non ti convince!${NC}"
    echo ""
    
    read -p "Pronto per l'assessment? (y/N): " ready
    if [[ "$ready" != "y" && "$ready" != "Y" ]]; then
        echo "Assessment saltato - useremo livello intermedio di default"
        tech_level="intermediate"
        tech_description="Intermedio - Spiegazioni moderate con contesto (default)"
        assessment_score=2
    else
        assessment_score=0
        
        # Domanda 1: Git/Version Control
        echo ""
        echo -e "${BOLD}🔧 Domanda 1/5: Git e Version Control${NC}"
        echo "Cosa fa questo comando: git rebase -i HEAD~3"
        echo ""
        echo "a) Crea un nuovo branch con gli ultimi 3 commit"
        echo "b) Elimina gli ultimi 3 commit"
        echo "c) Apre editor per modificare/riordinare ultimi 3 commit"
        echo "d) Non lo so / Mai usato"
        echo ""
        read -p "Risposta (a/b/c/d): " q1
        case $q1 in
            c|C) assessment_score=$((assessment_score + 1)) ;;
        esac
        
        # Domanda 2: Command Line
        echo ""
        echo -e "${BOLD}🖥️  Domanda 2/5: Command Line${NC}"
        echo "Quale comando usi per trovare tutti i file .js che contengono 'function'?"
        echo ""
        echo "a) find . -name '*.js' | grep function"
        echo "b) grep -r 'function' . --include='*.js'"
        echo "c) ls *.js | search function"
        echo "d) Non saprei come fare"
        echo ""
        read -p "Risposta (a/b/c/d): " q2
        case $q2 in
            b|B) assessment_score=$((assessment_score + 1)) ;;
        esac
        
        # Domanda 3: Programmazione
        echo ""
        echo -e "${BOLD}⚙️  Domanda 3/5: Concetti di Programmazione${NC}"
        echo "Qual è la differenza principale tra '==' e '===' in JavaScript?"
        echo ""
        echo "a) Nessuna differenza"
        echo "b) == confronta valore, === confronta valore e tipo"
        echo "c) === è più veloce"
        echo "d) Non conosco JavaScript / Non so"
        echo ""
        read -p "Risposta (a/b/c/d): " q3
        case $q3 in
            b|B) assessment_score=$((assessment_score + 1)) ;;
        esac
        
        # Domanda 4: Debugging
        echo ""
        echo -e "${BOLD}🐛 Domanda 4/5: Debugging${NC}"
        echo "Il tuo programma ha un memory leak. Quale approccio usi per primo?"
        echo ""
        echo "a) Riavvio il programma finché non funziona"
        echo "b) Uso profiler/monitor memoria per identificare dove cresce"
        echo "c) Aggiungo più RAM al server"
        echo "d) Non so cos'è un memory leak"
        echo ""
        read -p "Risposta (a/b/c/d): " q4
        case $q4 in
            b|B) assessment_score=$((assessment_score + 1)) ;;
        esac
        
        # Domanda 5: Architettura
        echo ""
        echo -e "${BOLD}🏗️  Domanda 5/5: Architettura e Design${NC}"
        echo "Quando sceglieresti un database NoSQL invece di SQL?"
        echo ""
        echo "a) Sempre, è più moderno"
        echo "b) Mai, SQL è sempre meglio"
        echo "c) Quando ho dati non strutturati/variabili o serve scala orizzontale"
        echo "d) Non conosco la differenza"
        echo ""
        read -p "Risposta (a/b/c/d): " q5
        case $q5 in
            c|C) assessment_score=$((assessment_score + 1)) ;;
        esac
        
        # Valutazione risultato
        echo ""
        echo -e "${CYAN}📊 RISULTATO ASSESSMENT${NC}"
        echo "Punteggio: $assessment_score/5"
        echo ""
        
        if [[ $assessment_score -eq 0 ]]; then
            tech_level="beginner"
            tech_description="Principiante - Spiegazioni dettagliate e step-by-step"
            echo -e "${GREEN}🟢 Livello: PRINCIPIANTE${NC}"
            echo "Claude ti guiderà passo-passo con spiegazioni complete!"
        elif [[ $assessment_score -le 2 ]]; then
            tech_level="intermediate"
            tech_description="Intermedio - Spiegazioni moderate con contesto"
            echo -e "${YELLOW}🟡 Livello: INTERMEDIO${NC}"
            echo "Claude bilancerà spiegazioni e efficienza."
        elif [[ $assessment_score -le 4 ]]; then
            tech_level="advanced"
            tech_description="Avanzato - Spiegazioni concise ma complete"
            echo -e "${BLUE}🟠 Livello: AVANZATO${NC}"
            echo "Claude sarà conciso assumendo buone conoscenze di base."
        else
            tech_level="expert"
            tech_description="Esperto - Minimo overhead, massima efficienza"
            echo -e "${RED}🔴 Livello: ESPERTO${NC}"
            echo "Claude minimizzerà le spiegazioni per massima efficienza."
        fi
        
        echo ""
        echo -e "${YELLOW}🔧 Non ti convince il livello assegnato?${NC}"
        echo "Puoi cambiarlo manualmente ora o dopo con 'claude-setup-profile edit'"
        echo ""
        
        read -p "Vuoi modificare il livello ora? (y/N): " change_level
        if [[ "$change_level" == "y" || "$change_level" == "Y" ]]; then
            echo ""
            echo "1. 🟢 Principiante - Spiegazioni dettagliate e step-by-step"
            echo "2. 🟡 Intermedio - Spiegazioni moderate con contesto"  
            echo "3. 🟠 Avanzato - Spiegazioni concise ma complete"
            echo "4. 🔴 Esperto - Minimo overhead, massima efficienza"
            echo ""
            
            while true; do
                read -p "Nuovo livello (1-4): " manual_choice
                case $manual_choice in
                    1)
                        tech_level="beginner"
                        tech_description="Principiante - Spiegazioni dettagliate e step-by-step (manuale)"
                        break
                        ;;
                    2)
                        tech_level="intermediate" 
                        tech_description="Intermedio - Spiegazioni moderate con contesto (manuale)"
                        break
                        ;;
                    3)
                        tech_level="advanced"
                        tech_description="Avanzato - Spiegazioni concise ma complete (manuale)"
                        break
                        ;;
                    4)
                        tech_level="expert"
                        tech_description="Esperto - Minimo overhead, massima efficienza (manuale)"
                        break
                        ;;
                    *)
                        echo "Inserisci un numero da 1 a 4"
                        continue
                        ;;
                esac
            done
        fi
    fi
    
    # Timezone (opzionale)
    echo ""
    echo -e "${BOLD}🌍 Timezone (opzionale)${NC}"
    echo "Per timestamp personalizzati. Premi ENTER per auto-detect."
    read -p "Timezone (es: Europe/Rome): " timezone
    
    if [[ -z "$timezone" ]]; then
        timezone=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "UTC")
    fi
    
    # Preferenze comunicazione
    echo ""
    echo -e "${BOLD}💬 Preferenze di comunicazione${NC}"
    echo "1. 🎯 Diretto         - Risposte immediate, minimo small talk"
    echo "2. 🤝 Amichevole      - Tono cordiale con un po' di contesto"
    echo "3. 📚 Educativo       - Spiegazioni extra e suggerimenti"
    echo ""
    
    while true; do
        read -p "Stile preferito (1-3): " comm_style_choice
        case $comm_style_choice in
            1)
                comm_style="direct"
                comm_description="Diretto - Efficienza massima"
                break
                ;;
            2)
                comm_style="friendly"
                comm_description="Amichevole - Bilanciato"
                break
                ;;
            3)
                comm_style="educational"
                comm_description="Educativo - Con spiegazioni extra"
                break
                ;;
            *)
                echo "Inserisci un numero da 1 a 3"
                continue
                ;;
        esac
    done
    
    # Obiettivi (opzionale)
    echo ""
    echo -e "${BOLD}🎯 I tuoi obiettivi principali (opzionale)${NC}"
    echo "Es: Imparare Python, Sviluppare app web, Automatizzare task..."
    read -p "Obiettivi: " user_goals
    
    # Salva profilo
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    python3 << EOF
import json
from datetime import datetime

profile = {
    "version": "1.0",
    "created_at": "$timestamp",
    "user_info": {
        "name": "$user_name",
        "tech_level": "$tech_level",
        "tech_description": "$tech_description",
        "assessment_score": $assessment_score,
        "timezone": "$timezone",
        "communication_style": "$comm_style",
        "communication_description": "$comm_description",
        "goals": "$user_goals" if "$user_goals" else None
    },
    "preferences": {
        "explanation_detail": {
            "beginner": "high",
            "intermediate": "medium", 
            "advanced": "low",
            "expert": "minimal"
        }.get("$tech_level", "medium"),
        
        "code_comments": {
            "beginner": True,
            "intermediate": True,
            "advanced": False,
            "expert": False
        }.get("$tech_level", True),
        
        "step_by_step": {
            "beginner": True,
            "intermediate": True,
            "advanced": False,
            "expert": False
        }.get("$tech_level", True),
        
        "assume_knowledge": {
            "beginner": ["basic computer use"],
            "intermediate": ["basic programming", "command line basics"],
            "advanced": ["programming concepts", "development tools", "git"],
            "expert": ["advanced programming", "system architecture", "devops"]
        }.get("$tech_level", ["basic programming"])
    },
    "personalization": {
        "greeting_style": {
            "direct": "Ciao {name}",
            "friendly": "Ciao {name}! Come va?",
            "educational": "Ciao {name}! Pronto per imparare qualcosa di nuovo?"
        }.get("$comm_style", "Ciao {name}!"),
        
        "error_explanation": {
            "beginner": "detailed_with_context",
            "intermediate": "moderate_with_suggestions",
            "advanced": "concise_with_solution",
            "expert": "error_and_fix_only"
        }.get("$tech_level", "moderate_with_suggestions")
    },
    "stats": {
        "setup_completed": True,
        "last_updated": "$timestamp",
        "interactions_count": 0
    }
}

with open("$PROFILE_FILE", "w") as f:
    json.dump(profile, f, indent=2)

print("✅ Profilo salvato con successo!")
EOF
    
    # Update CLAUDE.md con info profilo
    update_claude_md_with_profile
    
    # Mostra riassunto
    echo ""
    echo -e "${GREEN}🎉 SETUP COMPLETATO!${NC}"
    echo ""
    echo -e "${BOLD}📋 Il tuo profilo:${NC}"
    echo -e "   👤 Nome: ${BLUE}$user_name${NC}"
    echo -e "   💻 Livello: ${BLUE}$tech_description${NC}"
    echo -e "   💬 Stile: ${BLUE}$comm_description${NC}"
    echo -e "   🌍 Timezone: ${BLUE}$timezone${NC}"
    if [[ -n "$user_goals" ]]; then
        echo -e "   🎯 Obiettivi: ${BLUE}$user_goals${NC}"
    fi
    echo ""
    
    # Spiegazione personalizzata in base al livello
    case $tech_level in
        "beginner")
            echo -e "${YELLOW}💡 Nota per principianti:${NC}"
            echo "Claude ti darà spiegazioni dettagliate e step-by-step."
            echo "Se qualcosa non è chiaro, chiedi sempre di spiegare meglio!"
            echo "Userai principalmente questi comandi:"
            echo "  • ./scripts/css save - per salvare il tuo lavoro"
            echo "  • ./scripts/ctools recent - per vedere cosa stavi facendo"
            ;;
        "intermediate")
            echo -e "${YELLOW}💡 Nota per utenti intermedi:${NC}"
            echo "Claude bilancerà spiegazioni e efficienza."
            echo "Riceverai contesto quando necessario, ma senza troppi dettagli."
            echo "Se hai dubbi su un comando, chiedi liberamente!"
            ;;
        "advanced")
            echo -e "${YELLOW}💡 Nota per utenti avanzati:${NC}"
            echo "Claude sarà conciso ma completo nelle spiegazioni."
            echo "Assumerà conoscenza di sviluppo e strumenti standard."
            echo "Focus su efficienza e risultati."
            ;;
        "expert")
            echo -e "${YELLOW}💡 Nota per esperti:${NC}"
            echo "Claude minimizzerà l'overhead e sarà diretto."
            echo "Spiegazioni solo quando richieste esplicitamente."
            echo "Massima efficienza e velocità."
            ;;
    esac
    
    echo ""
    echo -e "${CYAN}🔧 Puoi sempre modificare il profilo con:${NC}"
    echo "   claude-setup-profile edit"
    echo ""
}

# Funzione per modificare profilo esistente
edit_profile() {
    if [[ ! -f "$PROFILE_FILE" ]]; then
        echo -e "${RED}❌ Nessun profilo trovato. Usa 'setup' per crearne uno.${NC}"
        return 1
    fi
    
    echo -e "${CYAN}✏️ MODIFICA PROFILO${NC}"
    echo ""
    
    # Mostra profilo corrente
    python3 << EOF
import json

with open("$PROFILE_FILE") as f:
    profile = json.load(f)

user = profile["user_info"]
print("📋 PROFILO CORRENTE:")
print(f"   👤 Nome: {user['name']}")
print(f"   💻 Livello: {user['tech_description']}")
print(f"   💬 Stile: {user['communication_description']}")
print(f"   🌍 Timezone: {user['timezone']}")
if user.get('goals'):
    print(f"   🎯 Obiettivi: {user['goals']}")
print()
EOF
    
    echo "Cosa vuoi modificare?"
    echo "1. Nome"
    echo "2. Livello competenza"
    echo "3. Stile comunicazione"
    echo "4. Timezone"
    echo "5. Obiettivi"
    echo "6. Reset completo"
    echo ""
    
    read -p "Scegli (1-6): " choice
    
    case $choice in
        1)
            read -p "Nuovo nome: " new_name
            python3 << EOF
import json
with open("$PROFILE_FILE") as f:
    profile = json.load(f)
profile["user_info"]["name"] = "$new_name"
with open("$PROFILE_FILE", "w") as f:
    json.dump(profile, f, indent=2)
print("✅ Nome aggiornato")
EOF
            ;;
        6)
            echo -e "${YELLOW}⚠️ Questo cancellerà tutto il profilo.${NC}"
            read -p "Confermi? (y/N): " confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                rm -f "$PROFILE_FILE"
                setup_profile
            fi
            ;;
        *)
            echo "Funzione non ancora implementata. Usa reset completo per ora."
            ;;
    esac
}

# Funzione per aggiornare CLAUDE.md
update_claude_md_with_profile() {
    # Aggiungi sezione profilo utente al CLAUDE.md
    if ! grep -q "## Profilo Utente" "$CLAUDE_MD"; then
        cat >> "$CLAUDE_MD" << 'EOF'

## Profilo Utente
Il workspace ha un profilo utente configurato. Claude personalizza:
- Livello dettaglio spiegazioni basato su competenza
- Tono e stile comunicazione
- Assunzioni su conoscenze pregresse
- Saluti e interazioni

Usa `claude-setup-profile edit` per modificare.
EOF
    fi
}

# Funzione per caricare profilo esistente (per uso da altri script)
load_profile() {
    if [[ -f "$PROFILE_FILE" ]]; then
        python3 << EOF
import json
try:
    with open("$PROFILE_FILE") as f:
        profile = json.load(f)
    
    user = profile["user_info"]
    prefs = profile["preferences"]
    
    # Output formato shell-friendly
    print(f"USER_NAME='{user['name']}'")
    print(f"TECH_LEVEL='{user['tech_level']}'")
    print(f"COMM_STYLE='{user['communication_style']}'")
    print(f"TIMEZONE='{user['timezone']}'")
    print(f"EXPLANATION_DETAIL='{prefs['explanation_detail']}'")
    print(f"STEP_BY_STEP={str(prefs['step_by_step']).lower()}")
    
except Exception as e:
    print("# Profile not found or invalid")
    exit(1)
EOF
        return 0
    else
        return 1
    fi
}

# Funzione per mostrare profilo
show_profile() {
    if [[ ! -f "$PROFILE_FILE" ]]; then
        echo -e "${RED}❌ Nessun profilo configurato${NC}"
        echo "Usa 'claude-setup-profile setup' per iniziare"
        return 1
    fi
    
    echo -e "${CYAN}👤 USER PROFILE${NC}"
    echo ""
    
    python3 << EOF
import json
from datetime import datetime

with open("$PROFILE_FILE") as f:
    profile = json.load(f)

user = profile["user_info"]
prefs = profile["preferences"]
stats = profile.get("stats", {})

print("📋 INFORMAZIONI UTENTE")
print("=" * 30)
print(f"👤 Nome: {user['name']}")
print(f"💻 Livello competenza: {user['tech_description']}")
if user.get('assessment_score') is not None:
    print(f"📊 Punteggio assessment: {user['assessment_score']}/5")
print(f"💬 Stile comunicazione: {user['communication_description']}")
print(f"🌍 Timezone: {user['timezone']}")
if user.get('goals'):
    print(f"🎯 Obiettivi: {user['goals']}")
print()

print("⚙️  PREFERENZE CLAUDE")
print("=" * 30)
print(f"📝 Dettaglio spiegazioni: {prefs['explanation_detail']}")
print(f"💬 Commenti nel codice: {'Sì' if prefs['code_comments'] else 'No'}")
print(f"👣 Guide step-by-step: {'Sì' if prefs['step_by_step'] else 'No'}")
print()

print("📊 STATISTICHE")
print("=" * 30)
print(f"📅 Profilo creato: {user.get('created_at', 'N/A')}")
print(f"🔄 Ultimo aggiornamento: {stats.get('last_updated', 'N/A')}")
print(f"💬 Interazioni: {stats.get('interactions_count', 0)}")
EOF
}

# Funzione per applicare personalizzazioni
get_personalized_greeting() {
    if [[ -f "$PROFILE_FILE" ]]; then
        python3 << EOF
import json
try:
    with open("$PROFILE_FILE") as f:
        profile = json.load(f)
    
    name = profile["user_info"]["name"]
    style = profile["personalization"]["greeting_style"]
    print(style.format(name=name))
except:
    print("Ciao!")
EOF
    else
        echo "Ciao! (Configura il tuo profilo con: claude-setup-profile setup)"
    fi
}

# Help
show_help() {
    echo "Claude Setup Profile - Configurazione utente personalizzata"
    echo ""
    echo "Uso: claude-setup-profile [comando]"
    echo ""
    echo "Comandi:"
    echo "  setup                 - Setup iniziale profilo utente"
    echo "  show                  - Mostra profilo corrente"
    echo "  edit                  - Modifica profilo esistente"
    echo "  load                  - Carica profilo (per script)"
    echo "  greeting              - Mostra saluto personalizzato"
    echo ""
    echo "Il profilo personalizza:"
    echo "  • Livello dettaglio spiegazioni basato su competenza tecnica"
    echo "  • Stile e tono di comunicazione"
    echo "  • Assunzioni su conoscenze pregresse"
    echo "  • Saluti e interazioni"
    echo ""
    echo "Esempi:"
    echo "  claude-setup-profile setup"
    echo "  claude-setup-profile show"
}

# Main
case "$1" in
    "setup")
        setup_profile
        ;;
    "show"|"status")
        show_profile
        ;;
    "edit")
        edit_profile
        ;;
    "load")
        load_profile
        ;;
    "greeting")
        get_personalized_greeting
        ;;
    "help"|"--help"|"-h"|"")
        show_help
        ;;
    *)
        echo -e "${RED}❌ Comando sconosciuto: $1${NC}"
        show_help
        exit 1
        ;;
esac