#!/bin/bash
# setup-sandbox-complete.sh - Setup completo sistema sandbox

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configurazione
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"

# Banner
show_banner() {
    clear
    echo -e "${PURPLE}${BOLD}"
    cat << 'EOF'
   ______                 __    __              _____                 __________              
  / ____/   ____ _____   / /   / /__            / ___/ ____ _   ____  / ____/ __ \  ____   _  __
 / /       / __ `/ __ \ / /   / //_/  ______    \__ \ / __ `/  / __ \/ __/ / / / / / __ \ | |/_/
/ /___    / /_/ / /_/ // /   / ,<    /_____/   ___/ // /_/ /  / / / / /___/ /_/ / / /_/ />  <  
\____/    \__,_/\__,_//_/   /_/|_|            /____/ \__,_/  /_/ /_/_____/\____/  \____//_/|_|  
                                                                                                 
EOF
    echo -e "${NC}"
    echo -e "${CYAN}                        Sistema Sandbox Completo con Auto-Cleanup${NC}"
    echo -e "${YELLOW}                                    Version 1.0.0${NC}"
    echo
}

# Funzioni di logging
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"
    exit 1
}

info() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ℹ️  $1${NC}"
}

header() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════════════╗"
    echo "║$(printf "%-68s" " $1")║"
    echo "╚════════════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Verifica prerequisiti
check_prerequisites() {
    header "🔍 VERIFICA PREREQUISITI"
    
    # Verifica workspace esistente
    if [[ ! -d "$WORKSPACE_DIR" ]]; then
        error "Workspace Claude non trovato in $WORKSPACE_DIR. Esegui prima setup.sh"
    fi
    
    # Verifica script esistenti
    local required_scripts=(
        "cleanup-sandbox.sh"
        "claude-new.sh"
        "claude-archive.sh"
        "claude-list.sh"
        "setup-cron.sh"
    )
    
    for script in "${required_scripts[@]}"; do
        if [[ ! -f "$WORKSPACE_DIR/scripts/$script" ]]; then
            error "Script mancante: $script"
        fi
        
        if [[ ! -x "$WORKSPACE_DIR/scripts/$script" ]]; then
            warn "Correggendo permessi per $script"
            chmod +x "$WORKSPACE_DIR/scripts/$script"
        fi
    done
    
    log "Tutti i prerequisiti soddisfatti"
}

# Verifica e crea struttura template
setup_templates() {
    header "📋 SETUP TEMPLATE"
    
    local template_dir="$WORKSPACE_DIR/templates"
    
    # Verifica template esistenti
    local templates=(
        "python-basic"
        "nodejs-api"
        "react-app"
    )
    
    local templates_ok=true
    for template in "${templates[@]}"; do
        if [[ ! -d "$template_dir/$template" ]]; then
            warn "Template mancante: $template"
            templates_ok=false
        else
            log "Template verificato: $template"
        fi
    done
    
    if [[ "$templates_ok" == true ]]; then
        log "Tutti i template sono configurati correttamente"
    else
        error "Alcuni template sono mancanti. Assicurati che il setup sia stato completato correttamente."
    fi
    
    # Verifica file di template info
    for template in "${templates[@]}"; do
        if [[ ! -f "$template_dir/$template/.template-info" ]]; then
            warn "File .template-info mancante per $template"
        fi
    done
}

# Test funzionalità di base
test_basic_functionality() {
    header "🧪 TEST FUNZIONALITÀ"
    
    info "Testing cleanup script..."
    if "$WORKSPACE_DIR/scripts/cleanup-sandbox.sh" --list >/dev/null 2>&1; then
        log "Cleanup script funzionante"
    else
        error "Cleanup script non funziona"
    fi
    
    info "Testing list script..."
    if "$WORKSPACE_DIR/scripts/claude-list.sh" --summary >/dev/null 2>&1; then
        log "List script funzionante"
    else
        error "List script non funziona"
    fi
    
    info "Testing template listing..."
    if "$WORKSPACE_DIR/scripts/claude-new.sh" --list >/dev/null 2>&1; then
        log "Template system funzionante"
    else
        error "Template system non funziona"
    fi
    
    log "Tutti i test di base superati"
}

# Crea progetto di esempio
create_demo_project() {
    header "🎯 PROGETTO DEMO"
    
    local demo_exists=false
    
    # Verifica se esiste già un progetto demo
    if [[ -d "$WORKSPACE_DIR/projects/sandbox" ]]; then
        local demo_count=$(find "$WORKSPACE_DIR/projects/sandbox" -name "sandbox-demo-*" -type d 2>/dev/null | wc -l)
        if [[ $demo_count -gt 0 ]]; then
            demo_exists=true
        fi
    fi
    
    if [[ "$demo_exists" == false ]]; then
        info "Creando progetto demo per test..."
        
        cd "$WORKSPACE_DIR"
        if ./scripts/claude-new.sh demo-setup python-basic sandbox >/dev/null 2>&1; then
            log "Progetto demo creato: sandbox-demo-setup"
        else
            warn "Impossibile creare progetto demo (non critico)"
        fi
    else
        log "Progetto demo già esistente"
    fi
}

# Setup automazione
setup_automation() {
    header "⚙️  SETUP AUTOMAZIONE"
    
    echo -e "${CYAN}Configurazione automazione cron jobs:${NC}"
    echo
    echo "Il sistema può configurare automaticamente:"
    echo "  • Cleanup sandbox ogni 6 ore (retention 24h)"
    echo "  • Backup progetti settimanale"
    echo "  • Monitoraggio spazio disco"
    echo
    
    read -p "Vuoi configurare l'automazione ora? [Y/n]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        info "Configurando automazione con impostazioni raccomandate..."
        
        cd "$WORKSPACE_DIR"
        
        # Setup cleanup ogni 6 ore
        if ./scripts/setup-cron.sh cleanup every6h >/dev/null 2>&1; then
            log "Cleanup automatico configurato (ogni 6 ore)"
        else
            warn "Impossibile configurare cleanup automatico"
        fi
        
        # Setup backup settimanale
        if ./scripts/setup-cron.sh backup weekly >/dev/null 2>&1; then
            log "Backup automatico configurato (settimanale)"
        else
            warn "Impossibile configurare backup automatico"
        fi
        
        # Setup monitoraggio disco
        if ./scripts/setup-cron.sh monitor >/dev/null 2>&1; then
            log "Monitoraggio spazio disco configurato"
        else
            warn "Impossibile configurare monitoraggio disco"
        fi
        
        log "Automazione configurata con successo!"
    else
        info "Automazione saltata. Puoi configurarla in seguito con: ./scripts/setup-cron.sh"
    fi
}

# Mostra riepilogo finale
show_summary() {
    header "🎉 SETUP COMPLETATO"
    
    echo -e "${GREEN}${BOLD}Sistema Sandbox Claude configurato con successo!${NC}"
    echo
    
    echo -e "${BLUE}📊 Componenti Installati:${NC}"
    echo "   ✅ Script di cleanup automatico sandbox"
    echo "   ✅ Sistema template (Python, Node.js, React)"
    echo "   ✅ Gestione progetti completa (new/archive/list)"
    echo "   ✅ Automazione cron job"
    echo "   ✅ Monitoraggio e logging"
    echo
    
    echo -e "${BLUE}🚀 Comandi Principali:${NC}"
    echo "   • Nuovo progetto:        ./scripts/claude-new.sh"
    echo "   • Lista progetti:        ./scripts/claude-list.sh"
    echo "   • Cleanup sandbox:       ./scripts/cleanup-sandbox.sh"
    echo "   • Archivia progetti:     ./scripts/claude-archive.sh"
    echo "   • Configura automazione: ./scripts/setup-cron.sh"
    echo
    
    echo -e "${BLUE}📋 Template Disponibili:${NC}"
    echo "   • python-basic  - Progetto Python completo"
    echo "   • nodejs-api    - API REST con Express"
    echo "   • react-app     - Applicazione React moderna"
    echo
    
    # Mostra statistiche attuali
    echo -e "${BLUE}📈 Stato Workspace:${NC}"
    cd "$WORKSPACE_DIR"
    ./scripts/claude-list.sh --summary 2>/dev/null | grep -E "(Progetti|Spazio)" | sed 's/^/   /'
    echo
    
    # Mostra cron jobs configurati
    echo -e "${BLUE}⏰ Automazione Configurata:${NC}"
    local cron_jobs=$(crontab -l 2>/dev/null | grep -E "(cleanup-sandbox|backup-projects|monitor-disk)" | wc -l)
    if [[ $cron_jobs -gt 0 ]]; then
        echo "   ✅ $cron_jobs job automatici configurati"
        crontab -l 2>/dev/null | grep -E "(cleanup-sandbox|backup-projects|monitor-disk)" | sed 's/^/   • /'
    else
        echo "   ⚠️  Nessun job automatico configurato"
        echo "   💡 Usa: ./scripts/setup-cron.sh per configurare"
    fi
    echo
    
    echo -e "${YELLOW}📚 Documentazione:${NC}"
    echo "   • Guida completa: docs/SANDBOX-SYSTEM.md"
    echo "   • Setup generale: docs/SETUP.md"
    echo "   • Workflow: docs/WORKFLOW.md"
    echo
    
    echo -e "${GREEN}${BOLD}🎯 Il tuo sistema sandbox è pronto per l'uso!${NC}"
    echo
    echo -e "${CYAN}Esempio rapido:${NC}"
    echo "  ./scripts/claude-new.sh mio-test python-basic sandbox"
    echo "  # Sviluppa il progetto..."
    echo "  # Cleanup automatico rimuoverà i progetti vecchi"
    echo
}

# Test completo del sistema
run_full_test() {
    header "🔬 TEST COMPLETO SISTEMA"
    
    local test_project="test-sandbox-system-$(date +%s)"
    
    info "Eseguendo test completo del sistema..."
    
    # Test 1: Creazione progetto
    info "Test 1: Creazione progetto..."
    cd "$WORKSPACE_DIR"
    if ./scripts/claude-new.sh "$test_project" python-basic sandbox >/dev/null 2>&1; then
        log "✅ Creazione progetto riuscita"
    else
        error "❌ Creazione progetto fallita"
    fi
    
    # Test 2: Lista progetti
    info "Test 2: Lista progetti..."
    if ./scripts/claude-list.sh sandbox >/dev/null 2>&1; then
        log "✅ Lista progetti funzionante"
    else
        error "❌ Lista progetti fallita"
    fi
    
    # Test 3: Cleanup dry-run
    info "Test 3: Cleanup dry-run..."
    if ./scripts/cleanup-sandbox.sh --dry-run >/dev/null 2>&1; then
        log "✅ Cleanup dry-run funzionante"
    else
        error "❌ Cleanup dry-run fallito"
    fi
    
    # Test 4: Archiviazione
    info "Test 4: Archiviazione progetto..."
    if ./scripts/claude-archive.sh archive "sandbox-$test_project" >/dev/null 2>&1; then
        log "✅ Archiviazione funzionante"
    else
        warn "⚠️  Archiviazione non riuscita (progetto potrebbe non esistere)"
    fi
    
    # Cleanup test project se esiste ancora
    if [[ -d "$WORKSPACE_DIR/projects/sandbox/sandbox-$test_project" ]]; then
        rm -rf "$WORKSPACE_DIR/projects/sandbox/sandbox-$test_project"
        info "Progetto test rimosso"
    fi
    
    log "Test completo sistema completato"
}

# Main function
main() {
    show_banner
    
    echo -e "${CYAN}Questo script completerà la configurazione del sistema sandbox Claude.${NC}"
    echo -e "${CYAN}Verranno installati e configurati tutti i componenti necessari.${NC}"
    echo
    
    read -p "Continuare con il setup completo? [Y/n]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Setup annullato."
        exit 0
    fi
    
    check_prerequisites
    setup_templates
    test_basic_functionality
    create_demo_project
    run_full_test
    setup_automation
    show_summary
    
    echo -e "${GREEN}${BOLD}🚀 Setup sandbox sistema completato con successo!${NC}"
}

# Esegui main
main "$@"