#!/bin/bash
# cleanup-sandbox.sh - Rimuove progetti sandbox più vecchi del periodo di retention configurato

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configurazione predefinita
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
SANDBOX_DIR="${WORKSPACE_DIR}/projects/sandbox"
LOG_DIR="${WORKSPACE_DIR}/logs/cleanup"
LOG_FILE="${LOG_DIR}/cleanup-$(date +%Y%m%d-%H%M%S).log"
RETENTION_HOURS="${RETENTION_HOURS:-24}"
DRY_RUN="${DRY_RUN:-false}"

# Crea directory dei log se non esiste
mkdir -p "$LOG_DIR"

# Funzioni di logging
log() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${GREEN}[${timestamp}] ✅ ${message}${NC}"
    echo "[${timestamp}] ${message}" >> "$LOG_FILE"
}

warn() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${YELLOW}[${timestamp}] ⚠️  ${message}${NC}"
    echo "[${timestamp}] WARNING: ${message}" >> "$LOG_FILE"
}

error() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${RED}[${timestamp}] ❌ ${message}${NC}"
    echo "[${timestamp}] ERROR: ${message}" >> "$LOG_FILE"
    exit 1
}

info() {
    local message="$1"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo -e "${BLUE}[${timestamp}] ℹ️  ${message}${NC}"
    echo "[${timestamp}] INFO: ${message}" >> "$LOG_FILE"
}

# Funzione per calcolare l'età di un file/directory in ore
get_age_hours() {
    local path="$1"
    local current_time=$(date +%s)
    local file_time=$(stat -c %Y "$path" 2>/dev/null || stat -f %m "$path" 2>/dev/null)
    local age_seconds=$((current_time - file_time))
    echo $((age_seconds / 3600))
}

# Funzione per ottenere la dimensione human-readable
get_size() {
    local path="$1"
    if command -v du >/dev/null 2>&1; then
        du -sh "$path" 2>/dev/null | cut -f1
    else
        echo "N/A"
    fi
}

# Funzione per verificare se un progetto è un sandbox valido
is_sandbox_project() {
    local project_dir="$1"
    
    # Verifica che sia una directory
    if [[ ! -d "$project_dir" ]]; then
        return 1
    fi
    
    # Verifica che il nome segua il pattern sandbox
    local dirname=$(basename "$project_dir")
    if [[ ! "$dirname" =~ ^sandbox- ]]; then
        return 1
    fi
    
    return 0
}

# Funzione per pulire un singolo progetto
cleanup_project() {
    local project_dir="$1"
    local project_name=$(basename "$project_dir")
    local age_hours=$(get_age_hours "$project_dir")
    local size=$(get_size "$project_dir")
    
    info "Rimuovendo progetto: ${project_name} (età: ${age_hours}h, dimensione: ${size})"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        warn "DRY RUN: Non rimuovo realmente ${project_dir}"
        return 0
    fi
    
    # Backup dei file importanti prima della rimozione
    if [[ -f "${project_dir}/README.md" ]] || [[ -f "${project_dir}/.git/config" ]]; then
        local backup_dir="${LOG_DIR}/backups/$(date +%Y%m%d)"
        mkdir -p "$backup_dir"
        
        # Crea un piccolo file di metadata
        cat > "${backup_dir}/${project_name}.info" << EOF
Project: ${project_name}
Path: ${project_dir}
Removed: $(date)
Age: ${age_hours} hours
Size: ${size}
EOF
        
        # Salva eventuale README
        if [[ -f "${project_dir}/README.md" ]]; then
            cp "${project_dir}/README.md" "${backup_dir}/${project_name}.README.md" 2>/dev/null || true
        fi
    fi
    
    # Rimuovi il progetto
    if rm -rf "$project_dir"; then
        log "Progetto ${project_name} rimosso con successo"
        return 0
    else
        warn "Impossibile rimuovere ${project_name}"
        return 1
    fi
}

# Funzione principale di cleanup
perform_cleanup() {
    info "Avvio cleanup dei progetti sandbox"
    info "Directory sandbox: ${SANDBOX_DIR}"
    info "Periodo di retention: ${RETENTION_HOURS} ore"
    info "Modalità: $([ "$DRY_RUN" == "true" ] && echo "DRY RUN" || echo "PRODUZIONE")"
    
    # Verifica che la directory sandbox esista
    if [[ ! -d "$SANDBOX_DIR" ]]; then
        warn "Directory sandbox non trovata: ${SANDBOX_DIR}"
        return 0
    fi
    
    # Conta progetti prima del cleanup
    local total_projects=0
    local removed_projects=0
    local failed_removals=0
    local total_space_freed=0
    
    # Trova tutti i progetti sandbox
    while IFS= read -r project_dir; do
        if ! is_sandbox_project "$project_dir"; then
            continue
        fi
        
        total_projects=$((total_projects + 1))
        
        # Controlla l'età del progetto
        local age_hours=$(get_age_hours "$project_dir")
        
        if [[ $age_hours -gt $RETENTION_HOURS ]]; then
            local size_before=$(du -sk "$project_dir" 2>/dev/null | cut -f1 || echo "0")
            
            if cleanup_project "$project_dir"; then
                removed_projects=$((removed_projects + 1))
                total_space_freed=$((total_space_freed + size_before))
            else
                failed_removals=$((failed_removals + 1))
            fi
        else
            info "Mantenendo progetto: $(basename "$project_dir") (età: ${age_hours}h)"
        fi
    done < <(find "$SANDBOX_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    
    # Report finale
    echo
    log "=== REPORT CLEANUP ==="
    log "Progetti totali esaminati: ${total_projects}"
    log "Progetti rimossi: ${removed_projects}"
    log "Rimozioni fallite: ${failed_removals}"
    log "Spazio liberato: $((total_space_freed / 1024)) MB"
}

# Funzione per impostare un lock file per evitare esecuzioni concorrenti
acquire_lock() {
    local lock_file="/tmp/claude-cleanup-sandbox.lock"
    
    if [[ -f "$lock_file" ]]; then
        local lock_pid=$(cat "$lock_file" 2>/dev/null)
        if kill -0 "$lock_pid" 2>/dev/null; then
            error "Un'altra istanza di cleanup è già in esecuzione (PID: $lock_pid)"
        else
            warn "Rimuovendo lock file obsoleto"
            rm -f "$lock_file"
        fi
    fi
    
    echo $$ > "$lock_file"
    trap "rm -f $lock_file" EXIT
}

# Funzione per mostrare l'help
show_help() {
    cat << EOF
Uso: $(basename "$0") [OPZIONI]

Script per la pulizia automatica dei progetti sandbox più vecchi del periodo di retention.

OPZIONI:
    -h, --help              Mostra questo messaggio di aiuto
    -d, --dry-run           Esegue in modalità dry-run (non rimuove realmente i file)
    -r, --retention HOURS   Imposta il periodo di retention in ore (default: 24)
    -s, --sandbox-dir DIR   Specifica la directory sandbox (default: \$WORKSPACE_DIR/projects/sandbox)
    -l, --list              Lista tutti i progetti sandbox con le loro età
    -v, --verbose           Output verboso

VARIABILI D'AMBIENTE:
    WORKSPACE_DIR           Directory del workspace (default: \$HOME/claude-workspace)
    RETENTION_HOURS         Ore di retention (default: 24)
    DRY_RUN                 Modalità dry-run (true/false, default: false)

ESEMPI:
    # Cleanup normale con retention di 24 ore
    $(basename "$0")
    
    # Dry run con retention di 48 ore
    $(basename "$0") --dry-run --retention 48
    
    # Lista tutti i progetti sandbox
    $(basename "$0") --list
    
    # Configurazione tramite variabili d'ambiente
    RETENTION_HOURS=12 $(basename "$0")

CRON EXAMPLE:
    # Esegui cleanup ogni 6 ore
    0 */6 * * * $WORKSPACE_DIR/scripts/cleanup-sandbox.sh >> /dev/null 2>&1

EOF
}

# Funzione per listare i progetti
list_projects() {
    info "Lista progetti sandbox:"
    echo
    
    if [[ ! -d "$SANDBOX_DIR" ]]; then
        warn "Directory sandbox non trovata: ${SANDBOX_DIR}"
        return 1
    fi
    
    printf "%-40s %-10s %-15s %-10s\n" "PROGETTO" "ETÀ (ore)" "ULTIMA MODIFICA" "DIMENSIONE"
    printf "%-40s %-10s %-15s %-10s\n" "--------" "---------" "---------------" "----------"
    
    while IFS= read -r project_dir; do
        if ! is_sandbox_project "$project_dir"; then
            continue
        fi
        
        local project_name=$(basename "$project_dir")
        local age_hours=$(get_age_hours "$project_dir")
        local last_modified=$(date -r "$project_dir" "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$(stat -f %m "$project_dir")" "+%Y-%m-%d %H:%M" 2>/dev/null)
        local size=$(get_size "$project_dir")
        
        # Colora in base all'età
        if [[ $age_hours -gt $RETENTION_HOURS ]]; then
            printf "${RED}%-40s %-10s %-15s %-10s${NC}\n" "$project_name" "$age_hours" "$last_modified" "$size"
        else
            printf "${GREEN}%-40s %-10s %-15s %-10s${NC}\n" "$project_name" "$age_hours" "$last_modified" "$size"
        fi
    done < <(find "$SANDBOX_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    
    echo
}

# Parse degli argomenti
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -r|--retention)
            RETENTION_HOURS="$2"
            shift 2
            ;;
        -s|--sandbox-dir)
            SANDBOX_DIR="$2"
            shift 2
            ;;
        -l|--list)
            list_projects
            exit 0
            ;;
        -v|--verbose)
            set -x
            shift
            ;;
        *)
            error "Opzione non riconosciuta: $1"
            ;;
    esac
done

# Validazione del periodo di retention
if ! [[ "$RETENTION_HOURS" =~ ^[0-9]+$ ]] || [[ "$RETENTION_HOURS" -lt 1 ]]; then
    error "Il periodo di retention deve essere un numero positivo di ore"
fi

# Main
main() {
    log "=== INIZIO CLEANUP SANDBOX ==="
    log "Script version: 1.0.0"
    log "Hostname: $(hostname)"
    log "User: $(whoami)"
    
    acquire_lock
    perform_cleanup
    
    log "=== CLEANUP COMPLETATO ==="
}

# Esegui il main
main