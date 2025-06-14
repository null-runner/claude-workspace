#!/bin/bash
# claude-archive.sh - Archivia progetti completati

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
PROJECTS_DIR="${WORKSPACE_DIR}/projects"
ARCHIVE_DIR="${PROJECTS_DIR}/archive"
LOG_FILE="${WORKSPACE_DIR}/logs/project-archive.log"

# Crea directory se non esistono
mkdir -p "$ARCHIVE_DIR" "$(dirname "$LOG_FILE")"

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

header() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║$(printf "%-64s" " $1")║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Ottieni informazioni progetto
get_project_info() {
    local project_path="$1"
    local info_file="$project_path/.claude/project.json"
    
    if [[ -f "$info_file" ]]; then
        echo "$info_file"
    else
        echo ""
    fi
}

# Calcola dimensione progetto
get_project_size() {
    local project_path="$1"
    if command -v du >/dev/null 2>&1; then
        du -sh "$project_path" 2>/dev/null | cut -f1
    else
        echo "N/A"
    fi
}

# Conta file nel progetto
count_project_files() {
    local project_path="$1"
    find "$project_path" -type f 2>/dev/null | wc -l
}

# Ottieni ultima modifica
get_last_modified() {
    local project_path="$1"
    if command -v find >/dev/null 2>&1; then
        find "$project_path" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -n | tail -1 | xargs -I {} date -d @{} "+%Y-%m-%d %H:%M" 2>/dev/null || date -r "$project_path" "+%Y-%m-%d %H:%M" 2>/dev/null
    else
        date -r "$project_path" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "N/A"
    fi
}

# Verifica se è un progetto git
is_git_project() {
    local project_path="$1"
    [[ -d "$project_path/.git" ]]
}

# Ottieni branch git corrente
get_git_branch() {
    local project_path="$1"
    if is_git_project "$project_path"; then
        cd "$project_path" && git branch --show-current 2>/dev/null || echo "unknown"
    else
        echo "not-git"
    fi
}

# Ottieni status git
get_git_status() {
    local project_path="$1"
    if is_git_project "$project_path"; then
        cd "$project_path"
        local status=$(git status --porcelain 2>/dev/null)
        if [[ -z "$status" ]]; then
            echo "clean"
        else
            echo "dirty"
        fi
    else
        echo "not-git"
    fi
}

# Lista progetti disponibili per l'archiviazione
list_archivable_projects() {
    local source_type="$1"  # active, sandbox, production
    local source_dir="$PROJECTS_DIR/$source_type"
    
    if [[ ! -d "$source_dir" ]]; then
        warn "Directory $source_type non trovata: $source_dir"
        return 1
    fi
    
    echo -e "${BLUE}Progetti in ${source_type}:${NC}"
    echo
    
    if [[ -z "$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]]; then
        info "Nessun progetto trovato in $source_type"
        return 0
    fi
    
    printf "%-3s %-30s %-10s %-8s %-15s %-10s %-10s\n" "ID" "NOME" "DIMENSIONE" "FILES" "ULTIMA MODIFICA" "GIT" "STATUS"
    printf "%-3s %-30s %-10s %-8s %-15s %-10s %-10s\n" "---" "----" "---------" "-----" "---------------" "---" "------"
    
    local project_id=1
    while IFS= read -r project_path; do
        local project_name=$(basename "$project_path")
        local size=$(get_project_size "$project_path")
        local files=$(count_project_files "$project_path")
        local last_mod=$(get_last_modified "$project_path")
        local git_branch=$(get_git_branch "$project_path")
        local git_status=$(get_git_status "$project_path")
        
        # Colora in base allo stato git
        if [[ "$git_status" == "dirty" ]]; then
            printf "${YELLOW}%-3s %-30s %-10s %-8s %-15s %-10s %-10s${NC}\n" "$project_id" "$project_name" "$size" "$files" "$last_mod" "$git_branch" "$git_status"
        elif [[ "$git_status" == "clean" ]]; then
            printf "${GREEN}%-3s %-30s %-10s %-8s %-15s %-10s %-10s${NC}\n" "$project_id" "$project_name" "$size" "$files" "$last_mod" "$git_branch" "$git_status"
        else
            printf "%-3s %-30s %-10s %-8s %-15s %-10s %-10s\n" "$project_id" "$project_name" "$size" "$files" "$last_mod" "$git_branch" "$git_status"
        fi
        
        project_id=$((project_id + 1))
    done < <(find "$source_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    
    echo
}

# Crea archivio compresso del progetto
create_compressed_archive() {
    local project_path="$1"
    local project_name=$(basename "$project_path")
    local timestamp=$(date +%Y%m%d-%H%M%S)
    local archive_name="${project_name}-${timestamp}"
    local archive_path="$ARCHIVE_DIR/$archive_name"
    
    info "Creando archivio compresso per $project_name..."
    
    # Crea directory archivio
    mkdir -p "$archive_path"
    
    # Copia il progetto
    if cp -r "$project_path/"* "$archive_path/" 2>/dev/null; then
        # Copia anche i file nascosti (ma non .git se molto grande)
        cp -r "$project_path/".* "$archive_path/" 2>/dev/null || true
        
        # Rimuovi .git se esiste per risparmiare spazio (opzionale)
        if [[ -d "$archive_path/.git" ]]; then
            local git_size=$(du -sh "$archive_path/.git" 2>/dev/null | cut -f1)
            read -p "Rimuovere directory .git ($git_size) dall'archivio? [y/N]: " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -rf "$archive_path/.git"
                info "Directory .git rimossa dall'archivio"
            fi
        fi
        
        # Crea metadata archivio
        cat > "$archive_path/.archive-info.json" << EOF
{
    "original_name": "$project_name",
    "original_path": "$project_path",
    "archived_date": "$(date -Iseconds)",
    "archived_by": "$(whoami)@$(hostname)",
    "original_size": "$(get_project_size "$project_path")",
    "files_count": $(count_project_files "$project_path"),
    "last_modified": "$(get_last_modified "$project_path")",
    "git_branch": "$(get_git_branch "$project_path")",
    "git_status": "$(get_git_status "$project_path")",
    "archive_version": "1.0"
}
EOF
        
        # Crea README per l'archivio
        cat > "$archive_path/ARCHIVE-README.md" << EOF
# Progetto Archiviato: $project_name

**Data archiviazione:** $(date)  
**Path originale:** $project_path  
**Archiviato da:** $(whoami)@$(hostname)  

## Informazioni Originali

- **Dimensione:** $(get_project_size "$project_path")
- **File totali:** $(count_project_files "$project_path")
- **Ultima modifica:** $(get_last_modified "$project_path")
- **Branch Git:** $(get_git_branch "$project_path")
- **Status Git:** $(get_git_status "$project_path")

## Per Ripristinare

\`\`\`bash
# Copia il progetto nella directory desiderata
cp -r "$archive_path" /path/to/new/location/$project_name

# Se era un progetto git, reinizializza se necessario
cd /path/to/new/location/$project_name
git init
git add -A
git commit -m "Ripristinato da archivio"
\`\`\`

---
*Archiviato automaticamente da Claude Workspace*
EOF
        
        log "Archivio creato: $archive_path"
        echo "$archive_path"
    else
        error "Impossibile creare archivio per $project_name"
    fi
}

# Archivia singolo progetto
archive_project() {
    local project_path="$1"
    local project_name=$(basename "$project_path")
    local compress="${2:-false}"
    
    if [[ ! -d "$project_path" ]]; then
        error "Progetto non trovato: $project_path"
    fi
    
    header "ARCHIVIAZIONE PROGETTO: $project_name"
    
    # Informazioni progetto
    info "Path: $project_path"
    info "Dimensione: $(get_project_size "$project_path")"
    info "File: $(count_project_files "$project_path")"
    info "Ultima modifica: $(get_last_modified "$project_path")"
    
    # Verifica stato git
    local git_status=$(get_git_status "$project_path")
    if [[ "$git_status" == "dirty" ]]; then
        warn "Il progetto ha modifiche non committate"
        read -p "Continuare comunque? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            warn "Archiviazione annullata"
            return 1
        fi
    fi
    
    # Crea archivio
    local archive_created=false
    if [[ "$compress" == "true" ]]; then
        if create_compressed_archive "$project_path" >/dev/null; then
            archive_created=true
        fi
    else
        # Semplice spostamento in archive
        local timestamp=$(date +%Y%m%d-%H%M%S)
        local archive_name="${project_name}-${timestamp}"
        local archive_path="$ARCHIVE_DIR/$archive_name"
        
        if mv "$project_path" "$archive_path"; then
            # Crea metadata
            cat > "$archive_path/.archive-info.json" << EOF
{
    "original_name": "$project_name",
    "original_path": "$project_path",
    "archived_date": "$(date -Iseconds)",
    "archived_by": "$(whoami)@$(hostname)",
    "archive_type": "moved",
    "archive_version": "1.0"
}
EOF
            log "Progetto spostato in archivio: $archive_path"
            archive_created=true
        else
            error "Impossibile spostare il progetto in archivio"
        fi
    fi
    
    if [[ "$archive_created" == true ]]; then
        log "Progetto $project_name archiviato con successo!"
        
        # Aggiorna statistiche
        update_archive_stats
    fi
}

# Aggiorna statistiche archivio
update_archive_stats() {
    local total_archives=$(find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    local total_size=$(du -sh "$ARCHIVE_DIR" 2>/dev/null | cut -f1)
    
    cat > "$ARCHIVE_DIR/.archive-stats.json" << EOF
{
    "last_updated": "$(date -Iseconds)",
    "total_archives": $total_archives,
    "total_size": "$total_size",
    "updated_by": "$(whoami)@$(hostname)"
}
EOF
}

# Lista progetti archiviati
list_archived_projects() {
    if [[ ! -d "$ARCHIVE_DIR" ]] || [[ -z "$(find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)" ]]; then
        info "Nessun progetto archiviato trovato"
        return 0
    fi
    
    echo -e "${BLUE}Progetti archiviati:${NC}"
    echo
    
    printf "%-3s %-40s %-15s %-10s %-20s\n" "ID" "NOME" "DATA ARCHIVIO" "DIMENSIONE" "NOME ORIGINALE"
    printf "%-3s %-40s %-15s %-10s %-20s\n" "---" "----" "-------------" "---------" "----------------"
    
    local archive_id=1
    while IFS= read -r archive_path; do
        local archive_name=$(basename "$archive_path")
        local size=$(get_project_size "$archive_path")
        local archive_date="N/A"
        local original_name="N/A"
        
        # Leggi metadata se esiste
        if [[ -f "$archive_path/.archive-info.json" ]]; then
            if command -v jq >/dev/null 2>&1; then
                archive_date=$(jq -r '.archived_date // "N/A"' "$archive_path/.archive-info.json" 2>/dev/null | cut -d'T' -f1)
                original_name=$(jq -r '.original_name // "N/A"' "$archive_path/.archive-info.json" 2>/dev/null)
            fi
        fi
        
        printf "%-3s %-40s %-15s %-10s %-20s\n" "$archive_id" "$archive_name" "$archive_date" "$size" "$original_name"
        archive_id=$((archive_id + 1))
    done < <(find "$ARCHIVE_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
    
    echo
    
    # Mostra statistiche
    if [[ -f "$ARCHIVE_DIR/.archive-stats.json" ]]; then
        if command -v jq >/dev/null 2>&1; then
            local total_archives=$(jq -r '.total_archives // 0' "$ARCHIVE_DIR/.archive-stats.json" 2>/dev/null)
            local total_size=$(jq -r '.total_size // "N/A"' "$ARCHIVE_DIR/.archive-stats.json" 2>/dev/null)
            info "Totale archivi: $total_archives, Spazio occupato: $total_size"
        fi
    fi
}

# Modalità interattiva per archiviazione
interactive_archive() {
    header "ARCHIVIAZIONE INTERATTIVA PROGETTI"
    
    # Scegli tipo di progetto da archiviare
    echo -e "${CYAN}Da quale categoria vuoi archiviare?${NC}"
    echo "  1) active     - Progetti in sviluppo attivo"
    echo "  2) sandbox    - Progetti temporanei/esperimenti"
    echo "  3) production - Progetti in produzione"
    echo
    read -p "Seleziona [1-3]: " type_choice
    
    local source_type
    case "$type_choice" in
        2) source_type="sandbox" ;;
        3) source_type="production" ;;
        *) source_type="active" ;;
    esac
    
    # Lista progetti
    echo
    list_archivable_projects "$source_type"
    
    # Selezione progetto
    local source_dir="$PROJECTS_DIR/$source_type"
    local projects=($(find "$source_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort))
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        warn "Nessun progetto da archiviare in $source_type"
        return 0
    fi
    
    echo -e "${CYAN}Quale progetto vuoi archiviare? (inserisci ID o nome):${NC}"
    read -p "> " selection
    
    local project_path=""
    
    # Verifica se è un ID numerico
    if [[ "$selection" =~ ^[0-9]+$ ]] && [[ $selection -ge 1 ]] && [[ $selection -le ${#projects[@]} ]]; then
        project_path="${projects[$((selection - 1))]}"
    else
        # Cerca per nome
        for project in "${projects[@]}"; do
            if [[ "$(basename "$project")" == "$selection" ]]; then
                project_path="$project"
                break
            fi
        done
    fi
    
    if [[ -z "$project_path" ]]; then
        error "Progetto non trovato: $selection"
    fi
    
    # Opzioni di archiviazione
    echo
    echo -e "${CYAN}Modalità di archiviazione:${NC}"
    echo "  1) Spostamento semplice (più veloce)"
    echo "  2) Copia compressa (mantiene originale)"
    echo
    read -p "Seleziona [1-2] (default: 1): " archive_mode
    
    local compress="false"
    case "$archive_mode" in
        2) compress="true" ;;
    esac
    
    # Conferma
    echo
    echo -e "${YELLOW}Stai per archiviare:${NC}"
    echo "  Progetto: $(basename "$project_path")"
    echo "  Path: $project_path"
    echo "  Modalità: $([ "$compress" == "true" ] && echo "Copia compressa" || echo "Spostamento")"
    echo
    read -p "Continuare? [Y/n]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        archive_project "$project_path" "$compress"
    else
        warn "Archiviazione annullata"
    fi
}

# Ripristina progetto dall'archivio
restore_project() {
    local archive_name="$1"
    local target_type="${2:-active}"
    
    if [[ -z "$archive_name" ]]; then
        error "Nome archivio non specificato"
    fi
    
    local archive_path="$ARCHIVE_DIR/$archive_name"
    if [[ ! -d "$archive_path" ]]; then
        # Prova a cercare per pattern
        local found_archives=($(find "$ARCHIVE_DIR" -name "*$archive_name*" -type d 2>/dev/null))
        if [[ ${#found_archives[@]} -eq 1 ]]; then
            archive_path="${found_archives[0]}"
            archive_name=$(basename "$archive_path")
        elif [[ ${#found_archives[@]} -gt 1 ]]; then
            warn "Trovati più archivi corrispondenti:"
            for arch in "${found_archives[@]}"; do
                echo "  $(basename "$arch")"
            done
            error "Specifica il nome completo dell'archivio"
        else
            error "Archivio non trovato: $archive_name"
        fi
    fi
    
    # Determina nome progetto ripristinato
    local original_name="$archive_name"
    if [[ -f "$archive_path/.archive-info.json" ]] && command -v jq >/dev/null 2>&1; then
        original_name=$(jq -r '.original_name // basename' "$archive_path/.archive-info.json" 2>/dev/null)
    fi
    
    # Rimuovi timestamp dal nome se presente
    original_name=$(echo "$original_name" | sed 's/-[0-9]\{8\}-[0-9]\{6\}$//')
    
    local target_dir="$PROJECTS_DIR/$target_type"
    local target_path="$target_dir/$original_name"
    
    # Verifica che il target non esista già
    if [[ -d "$target_path" ]]; then
        warn "Il progetto $original_name esiste già in $target_type"
        read -p "Sovrascrivere? [y/N]: " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            # Genera nome alternativo
            local counter=1
            while [[ -d "$target_dir/${original_name}-restored-$counter" ]]; do
                counter=$((counter + 1))
            done
            target_path="$target_dir/${original_name}-restored-$counter"
            info "Ripristino con nome alternativo: $(basename "$target_path")"
        else
            rm -rf "$target_path"
        fi
    fi
    
    info "Ripristinando $archive_name -> $(basename "$target_path")"
    
    # Copia il progetto
    if cp -r "$archive_path" "$target_path"; then
        # Rimuovi file di archivio
        rm -f "$target_path/.archive-info.json" "$target_path/ARCHIVE-README.md"
        
        # Reinizializza git se necessario
        if [[ ! -d "$target_path/.git" ]] && [[ -f "$target_path/.gitignore" ]]; then
            cd "$target_path"
            git init --quiet
            git add -A
            git commit -m "Progetto ripristinato da archivio $archive_name" --quiet
            info "Repository Git reinizializzato"
        fi
        
        log "Progetto ripristinato con successo: $target_path"
    else
        error "Impossibile ripristinare il progetto"
    fi
}

# Help
show_help() {
    cat << EOF
Uso: $(basename "$0") [OPZIONI] [PROGETTO] [MODALITÀ]

Archivia progetti completati nel workspace Claude.

COMANDI:
    archive PROJECT [copy|move]  Archivia un progetto specifico
    restore ARCHIVE [TYPE]       Ripristina un progetto dall'archivio
    list [archived|TYPE]         Lista progetti (TYPE: active|sandbox|production)
    interactive                  Modalità interattiva (default)

OPZIONI:
    -h, --help        Mostra questo messaggio
    -l, --list        Lista tutti i progetti archiviabili
    -a, --archived    Lista progetti archiviati
    -i, --interactive Modalità interattiva
    -c, --compress    Usa modalità compressa (copia invece di spostare)

ESEMPI:
    # Modalità interattiva
    $(basename "$0")
    
    # Archivia progetto specifico
    $(basename "$0") archive my-project
    
    # Archivia con compressione
    $(basename "$0") archive my-project copy
    
    # Lista progetti active
    $(basename "$0") list active
    
    # Lista archivi
    $(basename "$0") list archived
    
    # Ripristina progetto
    $(basename "$0") restore my-project-20240101-120000 active

TIPI DI PROGETTO:
    active      - Progetti in sviluppo attivo
    sandbox     - Progetti temporanei/esperimenti
    production  - Progetti pronti per produzione

MODALITÀ ARCHIVIAZIONE:
    move (default) - Sposta il progetto in archivio
    copy           - Crea copia compressa mantenendo l'originale

EOF
}

# Main
main() {
    local command=""
    local project_name=""
    local archive_mode="move"
    local compress=false
    
    # Se nessun argomento, usa modalità interattiva
    if [[ $# -eq 0 ]]; then
        interactive_archive
        exit 0
    fi
    
    # Parse argomenti
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                command="list"
                shift
                ;;
            -a|--archived)
                command="list_archived"
                shift
                ;;
            -i|--interactive)
                interactive_archive
                exit 0
                ;;
            -c|--compress)
                compress=true
                shift
                ;;
            archive|restore|list)
                command="$1"
                shift
                ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                elif [[ "$1" =~ ^(copy|move|active|sandbox|production|archived)$ ]]; then
                    archive_mode="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Esegui comando
    case "$command" in
        "archive")
            if [[ -z "$project_name" ]]; then
                error "Nome progetto non specificato"
            fi
            
            # Trova il progetto
            local project_path=""
            for project_type in active sandbox production; do
                local candidate="$PROJECTS_DIR/$project_type/$project_name"
                if [[ -d "$candidate" ]]; then
                    project_path="$candidate"
                    break
                fi
            done
            
            if [[ -z "$project_path" ]]; then
                error "Progetto non trovato: $project_name"
            fi
            
            local use_compress="false"
            if [[ "$archive_mode" == "copy" ]] || [[ "$compress" == true ]]; then
                use_compress="true"
            fi
            
            archive_project "$project_path" "$use_compress"
            ;;
            
        "restore")
            if [[ -z "$project_name" ]]; then
                error "Nome archivio non specificato"
            fi
            restore_project "$project_name" "$archive_mode"
            ;;
            
        "list")
            if [[ "$project_name" == "archived" ]] || [[ "$archive_mode" == "archived" ]]; then
                list_archived_projects
            else
                local list_type="${project_name:-active}"
                if [[ ! "$list_type" =~ ^(active|sandbox|production)$ ]]; then
                    list_type="active"  
                fi
                list_archivable_projects "$list_type"
            fi
            ;;
            
        "list_archived")
            list_archived_projects
            ;;
            
        *)
            # Modalità interattiva se comando non riconosciuto
            interactive_archive
            ;;
    esac
}

# Esegui main
main "$@"