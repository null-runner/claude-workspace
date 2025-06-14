#!/bin/bash
# setup-cron.sh - Configura cron job per cleanup automatico sandbox

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configurazione
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
CLEANUP_SCRIPT="${WORKSPACE_DIR}/scripts/cleanup-sandbox.sh"
LOG_FILE="${WORKSPACE_DIR}/logs/cron-setup.log"

# Crea directory log se non esiste
mkdir -p "$(dirname "$LOG_FILE")"

# Funzioni di logging
log() {
    echo -e "${GREEN}[$(date '+%H:%M:%S')] ✅ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

error() {
    echo -e "${RED}[$(date '+%H:%M:%S')] ❌ $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
    exit 1
}

info() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ℹ️  $1${NC}"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" >> "$LOG_FILE"
}

# Verifica che lo script di cleanup esista
check_cleanup_script() {
    if [[ ! -f "$CLEANUP_SCRIPT" ]]; then
        error "Script di cleanup non trovato: $CLEANUP_SCRIPT"
    fi
    
    if [[ ! -x "$CLEANUP_SCRIPT" ]]; then
        warn "Script di cleanup non eseguibile, correggendo permessi..."
        chmod +x "$CLEANUP_SCRIPT"
    fi
    
    log "Script di cleanup verificato: $CLEANUP_SCRIPT"
}

# Configura cron job per cleanup sandbox
setup_sandbox_cleanup() {
    local frequency="${1:-daily}"
    local retention_hours="${2:-24}"
    
    info "Configurando cleanup sandbox automatico..."
    info "Frequenza: $frequency"
    info "Retention: $retention_hours ore"
    
    # Rimuovi eventuali job esistenti per evitare duplicati
    crontab -l 2>/dev/null | grep -v "cleanup-sandbox.sh" | crontab - 2>/dev/null || true
    
    # Determina la schedulazione cron
    local cron_schedule
    case "$frequency" in
        "hourly")
            cron_schedule="0 * * * *"
            ;;
        "every6h")
            cron_schedule="0 */6 * * *"
            ;;
        "daily")
            cron_schedule="0 2 * * *"  # Alle 2 di notte
            ;;
        "weekly")
            cron_schedule="0 2 * * 0"  # Domenica alle 2
            ;;
        *)
            cron_schedule="$frequency"  # Usa pattern cron custom
            ;;
    esac
    
    # Crea comando con variabili d'ambiente
    local cron_command="WORKSPACE_DIR=$WORKSPACE_DIR RETENTION_HOURS=$retention_hours $CLEANUP_SCRIPT >> $WORKSPACE_DIR/logs/cleanup/cron-cleanup.log 2>&1"
    
    # Aggiungi il job al crontab
    (crontab -l 2>/dev/null; echo "$cron_schedule $cron_command") | crontab -
    
    log "Cron job configurato: $cron_schedule"
    log "Comando: $cron_command"
}

# Setup job di backup progetti
setup_backup_job() {
    local frequency="${1:-weekly}"
    
    info "Configurando backup automatico progetti..."
    
    # Script di backup (creato se non esiste)
    local backup_script="${WORKSPACE_DIR}/scripts/backup-projects.sh"
    
    if [[ ! -f "$backup_script" ]]; then
        info "Creando script di backup..."
        cat > "$backup_script" << 'EOF'
#!/bin/bash
# backup-projects.sh - Backup automatico progetti

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
BACKUP_DIR="${WORKSPACE_DIR}/backups"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup progetti active e production
for category in active production; do
    if [[ -d "$WORKSPACE_DIR/projects/$category" ]] && [[ -n "$(ls -A "$WORKSPACE_DIR/projects/$category" 2>/dev/null)" ]]; then
        tar -czf "$BACKUP_DIR/${category}-${TIMESTAMP}.tar.gz" -C "$WORKSPACE_DIR/projects" "$category"
        echo "Backup created: ${category}-${TIMESTAMP}.tar.gz"
    fi
done

# Rimuovi backup più vecchi di 30 giorni
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +30 -delete 2>/dev/null || true
EOF
        chmod +x "$backup_script"
        log "Script di backup creato: $backup_script"
    fi
    
    # Rimuovi job backup esistenti
    crontab -l 2>/dev/null | grep -v "backup-projects.sh" | crontab - 2>/dev/null || true
    
    # Determina schedulazione
    local cron_schedule
    case "$frequency" in
        "daily")
            cron_schedule="0 3 * * *"  # Alle 3 di notte
            ;;
        "weekly")
            cron_schedule="0 3 * * 1"  # Lunedì alle 3
            ;;
        "monthly")
            cron_schedule="0 3 1 * *"  # Primo del mese alle 3
            ;;
        *)
            cron_schedule="$frequency"
            ;;
    esac
    
    local cron_command="$backup_script >> $WORKSPACE_DIR/logs/backup.log 2>&1"
    (crontab -l 2>/dev/null; echo "$cron_schedule $cron_command") | crontab -
    
    log "Job di backup configurato: $cron_schedule"
}

# Setup monitoraggio spazio disco
setup_disk_monitoring() {
    info "Configurando monitoraggio spazio disco..."
    
    local monitor_script="${WORKSPACE_DIR}/scripts/monitor-disk.sh"
    
    if [[ ! -f "$monitor_script" ]]; then
        cat > "$monitor_script" << 'EOF'
#!/bin/bash
# monitor-disk.sh - Monitora spazio disco workspace

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
THRESHOLD="${DISK_THRESHOLD:-85}"  # Soglia percentuale

# Ottieni uso spazio della partizione workspace
DISK_USAGE=$(df "$WORKSPACE_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

if [[ "$DISK_USAGE" -gt "$THRESHOLD" ]]; then
    echo "WARNING: Workspace disk usage is ${DISK_USAGE}% (threshold: ${THRESHOLD}%)"
    echo "Location: $WORKSPACE_DIR"
    echo "Consider running cleanup or archiving old projects"
    
    # Log nella directory workspace
    echo "[$(date)] Disk usage warning: ${DISK_USAGE}%" >> "$WORKSPACE_DIR/logs/disk-usage.log"
    
    # Se uso > 90%, esegui cleanup automatico dei sandbox
    if [[ "$DISK_USAGE" -gt 90 ]]; then
        echo "Critical disk usage, running automatic sandbox cleanup..."
        "$WORKSPACE_DIR/scripts/cleanup-sandbox.sh" -r 1  # Cleanup progetti > 1 ora
    fi
fi
EOF
        chmod +x "$monitor_script"
        log "Script monitoraggio creato: $monitor_script"
    fi
    
    # Rimuovi job esistenti
    crontab -l 2>/dev/null | grep -v "monitor-disk.sh" | crontab - 2>/dev/null || true
    
    # Monitora ogni ora
    local cron_command="$monitor_script >> $WORKSPACE_DIR/logs/disk-monitor.log 2>&1"
    (crontab -l 2>/dev/null; echo "0 * * * * $cron_command") | crontab -
    
    log "Monitoraggio spazio disco configurato (ogni ora)"
}

# Mostra status cron jobs
show_cron_status() {
    info "Cron jobs attualmente configurati:"
    echo
    
    local current_crontab=$(crontab -l 2>/dev/null)
    
    if [[ -z "$current_crontab" ]]; then
        warn "Nessun cron job configurato"
        return
    fi
    
    echo -e "${BLUE}Jobs relativi a Claude Workspace:${NC}"
    echo "$current_crontab" | grep -E "(cleanup-sandbox|backup-projects|monitor-disk)" | while read -r line; do
        echo "  $line"
    done
    
    echo
    echo -e "${BLUE}Tutti i cron jobs:${NC}"
    echo "$current_crontab" | sed 's/^/  /'
    echo
}

# Rimuovi tutti i cron jobs Claude
remove_all_jobs() {
    warn "Rimuovendo tutti i cron jobs di Claude Workspace..."
    
    crontab -l 2>/dev/null | grep -v -E "(cleanup-sandbox|backup-projects|monitor-disk)" | crontab - 2>/dev/null || {
        # Se non ci sono job rimanenti, rimuovi completamente il crontab
        crontab -r 2>/dev/null || true
    }
    
    log "Cron jobs rimossi"
}

# Modalità interattiva
interactive_setup() {
    echo -e "${CYAN}=== CONFIGURAZIONE CRON JOBS CLAUDE WORKSPACE ===${NC}"
    echo
    
    # Cleanup sandbox
    echo -e "${BLUE}1. Cleanup automatico sandbox${NC}"
    echo "Frequenza di cleanup:"
    echo "  1) Ogni ora"
    echo "  2) Ogni 6 ore"
    echo "  3) Giornaliero (consigliato)"
    echo "  4) Settimanale"
    echo
    read -p "Seleziona frequenza [1-4] (default: 3): " cleanup_freq
    
    case "$cleanup_freq" in
        1) cleanup_frequency="hourly" ;;
        2) cleanup_frequency="every6h" ;;
        4) cleanup_frequency="weekly" ;;
        *) cleanup_frequency="daily" ;;
    esac
    
    echo
    read -p "Retention ore per sandbox (default: 24): " retention_hours
    retention_hours="${retention_hours:-24}"
    
    # Backup
    echo
    echo -e "${BLUE}2. Backup automatico progetti${NC}"
    echo "Frequenza di backup:"
    echo "  1) Giornaliero"
    echo "  2) Settimanale (consigliato)"
    echo "  3) Mensile"
    echo "  4) Salta backup"
    echo
    read -p "Seleziona frequenza [1-4] (default: 2): " backup_freq
    
    case "$backup_freq" in
        1) backup_frequency="daily" ;;
        3) backup_frequency="monthly" ;;
        4) backup_frequency="skip" ;;
        *) backup_frequency="weekly" ;;
    esac
    
    # Monitoraggio disco
    echo
    echo -e "${BLUE}3. Monitoraggio spazio disco${NC}"
    read -p "Abilitare monitoraggio automatico? [Y/n]: " -n 1 -r enable_monitoring
    echo
    if [[ ! $enable_monitoring =~ ^[Nn]$ ]]; then
        enable_monitoring="yes"
    else
        enable_monitoring="no"
    fi
    
    # Conferma
    echo
    echo -e "${YELLOW}Configurazione selezionata:${NC}"
    echo "  • Cleanup sandbox: $cleanup_frequency (retention: ${retention_hours}h)"
    echo "  • Backup progetti: $backup_frequency"
    echo "  • Monitoraggio disco: $enable_monitoring"
    echo
    read -p "Procedere con la configurazione? [Y/n]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        setup_sandbox_cleanup "$cleanup_frequency" "$retention_hours"
        
        if [[ "$backup_frequency" != "skip" ]]; then
            setup_backup_job "$backup_frequency"
        fi
        
        if [[ "$enable_monitoring" == "yes" ]]; then
            setup_disk_monitoring
        fi
        
        log "Configurazione cron completata!"
        show_cron_status
    else
        warn "Configurazione annullata"
    fi
}

# Help
show_help() {
    cat << EOF
Uso: $(basename "$0") [OPZIONI] [COMANDO]

Configura cron jobs per automazione Claude Workspace.

COMANDI:
    setup           Configurazione interattiva (default)
    cleanup FREQ    Configura solo cleanup sandbox
    backup FREQ     Configura solo backup progetti  
    monitor         Configura solo monitoraggio disco
    status          Mostra status cron jobs
    remove          Rimuovi tutti i job Claude

OPZIONI CLEANUP:
    -r, --retention HOURS   Ore di retention (default: 24)
    
FREQUENZE:
    hourly          Ogni ora
    every6h         Ogni 6 ore
    daily           Giornaliero
    weekly          Settimanale
    monthly         Mensile
    "PATTERN"       Pattern cron custom (es. "0 */4 * * *")

ESEMPI:
    # Configurazione interattiva
    $(basename "$0")
    
    # Setup cleanup ogni 6 ore con retention 12h
    $(basename "$0") cleanup every6h -r 12
    
    # Setup backup settimanale
    $(basename "$0") backup weekly
    
    # Mostra status
    $(basename "$0") status
    
    # Pattern cron custom per cleanup
    $(basename "$0") cleanup "0 */4 * * *"

PATTERN CRON:
    I pattern seguono il formato standard cron:
    ┌───────────── minuto (0 - 59)
    │ ┌───────────── ora (0 - 23)
    │ │ ┌───────────── giorno del mese (1 - 31)
    │ │ │ ┌───────────── mese (1 - 12)
    │ │ │ │ ┌───────────── giorno della settimana (0 - 6)
    │ │ │ │ │
    * * * * *

EOF
}

# Main
main() {
    local command=""
    local retention_hours="24"
    
    # Se nessun argomento, usa modalità interattiva
    if [[ $# -eq 0 ]]; then
        command="interactive"
    fi
    
    # Parse argomenti
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -r|--retention)
                retention_hours="$2"
                shift 2
                ;;
            setup|cleanup|backup|monitor|status|remove)
                command="$1"
                shift
                ;;
            *)
                if [[ -z "$frequency" ]]; then
                    frequency="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Verifica script di cleanup
    check_cleanup_script
    
    # Esegui comando
    case "$command" in
        "setup"|"interactive"|"")
            interactive_setup
            ;;
        "cleanup")
            setup_sandbox_cleanup "${frequency:-daily}" "$retention_hours"
            log "Cleanup job configurato"
            ;;
        "backup")
            setup_backup_job "${frequency:-weekly}"
            log "Backup job configurato"
            ;;
        "monitor")
            setup_disk_monitoring
            log "Monitoraggio configurato"
            ;;
        "status")
            show_cron_status
            ;;
        "remove")
            remove_all_jobs
            ;;
        *)
            error "Comando non riconosciuto: $command"
            ;;
    esac
}

# Esegui main
main "$@"