#!/bin/bash
# claude-list.sh - Lista tutti i progetti con informazioni dettagliate

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

# Funzioni di logging
info() {
    echo -e "${CYAN}[$(date '+%H:%M:%S')] ℹ️  $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date '+%H:%M:%S')] ⚠️  $1${NC}"
}

header() {
    echo -e "${PURPLE}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║$(printf "%-64s" " $1")║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Ottieni informazioni progetto Claude
get_claude_info() {
    local project_path="$1"
    local info_file="$project_path/.claude/project.json"
    
    if [[ -f "$info_file" ]]; then
        if command -v jq >/dev/null 2>&1; then
            local template=$(jq -r '.template // "unknown"' "$info_file" 2>/dev/null)
            local created=$(jq -r '.created // "unknown"' "$info_file" 2>/dev/null | cut -d'T' -f1)
            local status=$(jq -r '.status // "unknown"' "$info_file" 2>/dev/null)
            echo "$template|$created|$status"
        else
            echo "unknown|unknown|unknown"
        fi
    else
        echo "none|unknown|unknown"
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
    find "$project_path" -type f 2>/dev/null | wc -l | tr -d ' '
}

# Ottieni ultima modifica
get_last_modified() {
    local project_path="$1"
    local age_days=0
    
    if command -v find >/dev/null 2>&1; then
        local last_mod_timestamp=$(find "$project_path" -type f -exec stat -c %Y {} \; 2>/dev/null | sort -n | tail -1)
        if [[ -n "$last_mod_timestamp" ]]; then
            local current_timestamp=$(date +%s)
            age_days=$(( (current_timestamp - last_mod_timestamp) / 86400 ))
            local formatted_date=$(date -d "@$last_mod_timestamp" "+%Y-%m-%d" 2>/dev/null)
            echo "${formatted_date:-N/A}|$age_days"
        else
            echo "N/A|999"
        fi
    else
        echo "N/A|999"
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
        echo "no-git"
    fi
}

# Ottieni status git
get_git_status() {
    local project_path="$1"
    if is_git_project "$project_path"; then
        cd "$project_path"
        local status=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
        if [[ "$status" -eq 0 ]]; then
            echo "clean"
        else
            echo "dirty($status)"
        fi
    else
        echo "no-git"
    fi
}

# Ottieni tipo di linguaggio/framework
detect_project_type() {
    local project_path="$1"
    
    # Python
    if [[ -f "$project_path/requirements.txt" ]] || [[ -f "$project_path/setup.py" ]] || [[ -f "$project_path/pyproject.toml" ]]; then
        echo "Python"
        return
    fi
    
    # Node.js
    if [[ -f "$project_path/package.json" ]]; then
        if [[ -f "$project_path/src/App.jsx" ]] || [[ -f "$project_path/src/App.tsx" ]]; then
            echo "React"
        elif grep -q '"@angular/' "$project_path/package.json" 2>/dev/null; then
            echo "Angular"
        elif grep -q '"vue"' "$project_path/package.json" 2>/dev/null; then
            echo "Vue"
        else
            echo "Node.js"
        fi
        return
    fi
    
    # Java
    if [[ -f "$project_path/pom.xml" ]] || [[ -f "$project_path/build.gradle" ]]; then
        echo "Java"
        return
    fi
    
    # Go
    if [[ -f "$project_path/go.mod" ]]; then
        echo "Go"
        return
    fi
    
    # Rust
    if [[ -f "$project_path/Cargo.toml" ]]; then
        echo "Rust"
        return
    fi
    
    # Docker
    if [[ -f "$project_path/Dockerfile" ]] || [[ -f "$project_path/docker-compose.yml" ]]; then
        echo "Docker"
        return
    fi
    
    # Generic
    echo "Generic"
}

# Lista progetti in una categoria
list_projects_category() {
    local category="$1"
    local detailed="${2:-false}"
    local category_dir="$PROJECTS_DIR/$category"
    
    if [[ ! -d "$category_dir" ]]; then
        warn "Directory $category non trovata: $category_dir"
        return 0
    fi
    
    local projects=($(find "$category_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort))
    
    if [[ ${#projects[@]} -eq 0 ]]; then
        info "Nessun progetto in $category"
        return 0
    fi
    
    echo -e "${BLUE}${BOLD}═══ $(echo $category | tr '[:lower:]' '[:upper:]') (${#projects[@]} progetti) ═══${NC}"
    echo
    
    if [[ "$detailed" == "true" ]]; then
        # Vista dettagliata
        printf "%-3s %-25s %-8s %-6s %-8s %-12s %-10s %-10s %-8s %-12s\n" \
            "ID" "NOME" "TIPO" "FILES" "SIZE" "ULTIMA MOD." "ETÀ" "GIT" "STATUS" "TEMPLATE"
        printf "%-3s %-25s %-8s %-6s %-8s %-12s %-10s %-10s %-8s %-12s\n" \
            "---" "----" "----" "-----" "----" "----------" "---" "---" "------" "--------"
    else
        # Vista compatta
        printf "%-3s %-30s %-10s %-8s %-12s %-10s %-12s\n" \
            "ID" "NOME" "TIPO" "SIZE" "ULTIMA MOD." "GIT" "TEMPLATE"
        printf "%-3s %-30s %-10s %-8s %-12s %-10s %-12s\n" \
            "---" "----" "----" "----" "----------" "---" "--------"
    fi
    
    local project_id=1
    for project_path in "${projects[@]}"; do
        local project_name=$(basename "$project_path")
        local size=$(get_project_size "$project_path")
        local files=$(count_project_files "$project_path")
        local last_mod_info=$(get_last_modified "$project_path")
        local last_mod_date=$(echo "$last_mod_info" | cut -d'|' -f1)
        local age_days=$(echo "$last_mod_info" | cut -d'|' -f2)
        local git_branch=$(get_git_branch "$project_path")
        local git_status=$(get_git_status "$project_path")
        local project_type=$(detect_project_type "$project_path")
        local claude_info=$(get_claude_info "$project_path")
        local template=$(echo "$claude_info" | cut -d'|' -f1)
        local created=$(echo "$claude_info" | cut -d'|' -f2)
        local status=$(echo "$claude_info" | cut -d'|' -f3)
        
        # Colori in base all'età e stato
        local color=""
        if [[ "$git_status" =~ dirty ]]; then
            color="$YELLOW"
        elif [[ $age_days -gt 30 ]]; then
            color="$RED"
        elif [[ $age_days -gt 7 ]]; then
            color="$YELLOW"
        else
            color="$GREEN"
        fi
        
        # Formatta età
        local age_display
        if [[ $age_days -eq 0 ]]; then
            age_display="oggi"
        elif [[ $age_days -eq 1 ]]; then
            age_display="1g"
        elif [[ $age_days -lt 7 ]]; then
            age_display="${age_days}g"
        elif [[ $age_days -lt 30 ]]; then
            age_display="$((age_days / 7))s"
        else
            age_display="$((age_days / 30))m"
        fi
        
        if [[ "$detailed" == "true" ]]; then
            printf "${color}%-3s %-25s %-8s %-6s %-8s %-12s %-10s %-10s %-8s %-12s${NC}\n" \
                "$project_id" "$project_name" "$project_type" "$files" "$size" \
                "$last_mod_date" "$age_display" "$git_branch" "$git_status" "$template"
        else
            printf "${color}%-3s %-30s %-10s %-8s %-12s %-10s %-12s${NC}\n" \
                "$project_id" "$project_name" "$project_type" "$size" \
                "$last_mod_date" "$git_branch" "$template"
        fi
        
        project_id=$((project_id + 1))
    done
    
    echo
}

# Statistiche generali
show_summary() {
    local active_count=$(find "$PROJECTS_DIR/active" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    local sandbox_count=$(find "$PROJECTS_DIR/sandbox" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    local production_count=$(find "$PROJECTS_DIR/production" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    local archive_count=$(find "$PROJECTS_DIR/archive" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
    local total_count=$((active_count + sandbox_count + production_count))
    
    # Calcola spazio totale
    local total_size="N/A"
    if command -v du >/dev/null 2>&1; then
        total_size=$(du -sh "$PROJECTS_DIR" 2>/dev/null | cut -f1)
    fi
    
    header "RIEPILOGO WORKSPACE"
    
    echo -e "${CYAN}📊 Statistiche Progetti:${NC}"
    echo "   • Active:     $active_count progetti"
    echo "   • Sandbox:    $sandbox_count progetti"
    echo "   • Production: $production_count progetti"
    echo "   • Archive:    $archive_count progetti"
    echo "   • Totale:     $total_count progetti attivi"
    echo "   • Spazio:     $total_size"
    echo
    
    # Progetti modificati di recente
    echo -e "${CYAN}🕒 Attività Recente:${NC}"
    local recent_projects=()
    for category in active sandbox production; do
        while IFS= read -r project_path; do
            local last_mod_info=$(get_last_modified "$project_path")
            local age_days=$(echo "$last_mod_info" | cut -d'|' -f2)
            if [[ $age_days -le 7 ]]; then
                recent_projects+=("$project_path|$age_days|$category")
            fi
        done < <(find "$PROJECTS_DIR/$category" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    done
    
    if [[ ${#recent_projects[@]} -gt 0 ]]; then
        # Ordina per età
        IFS=$'\n' recent_projects=($(printf '%s\n' "${recent_projects[@]}" | sort -t'|' -k2,2n))
        
        local count=0
        for recent in "${recent_projects[@]}"; do
            if [[ $count -ge 5 ]]; then break; fi
            
            local project_path=$(echo "$recent" | cut -d'|' -f1)
            local age_days=$(echo "$recent" | cut -d'|' -f2)
            local category=$(echo "$recent" | cut -d'|' -f3)
            local project_name=$(basename "$project_path")
            
            local age_display
            if [[ $age_days -eq 0 ]]; then
                age_display="oggi"
            elif [[ $age_days -eq 1 ]]; then
                age_display="ieri"
            else
                age_display="${age_days} giorni fa"
            fi
            
            echo "   • ${project_name} (${category}) - ${age_display}"
            count=$((count + 1))
        done
    else
        echo "   Nessuna attività recente"
    fi
    
    echo
    
    # Progetti che necessitano attenzione
    echo -e "${YELLOW}⚠️  Attenzione Richiesta:${NC}"
    local needs_attention=false
    
    # Progetti con modifiche non committate
    local dirty_projects=()
    for category in active production; do
        while IFS= read -r project_path; do
            local git_status=$(get_git_status "$project_path")
            if [[ "$git_status" =~ dirty ]]; then
                dirty_projects+=("$(basename "$project_path") ($category)")
            fi
        done < <(find "$PROJECTS_DIR/$category" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    done
    
    if [[ ${#dirty_projects[@]} -gt 0 ]]; then
        echo "   Git modifiche non committate:"
        for dirty in "${dirty_projects[@]}"; do
            echo "     • $dirty"
        done
        needs_attention=true
    fi
    
    # Progetti sandbox vecchi
    local old_sandbox=()
    while IFS= read -r project_path; do
        local last_mod_info=$(get_last_modified "$project_path")
        local age_days=$(echo "$last_mod_info" | cut -d'|' -f2)
        if [[ $age_days -gt 7 ]]; then
            old_sandbox+=("$(basename "$project_path") (${age_days}g)")
        fi
    done < <(find "$PROJECTS_DIR/sandbox" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    
    if [[ ${#old_sandbox[@]} -gt 0 ]]; then
        echo "   Sandbox vecchi (considera cleanup):"
        for old in "${old_sandbox[@]}"; do
            echo "     • $old"
        done
        needs_attention=true
    fi
    
    if [[ "$needs_attention" == false ]]; then
        echo "   Tutto a posto! ✅"
    fi
    
    echo
}

# Vista ad albero
show_tree_view() {
    if ! command -v tree >/dev/null 2>&1; then
        warn "Comando 'tree' non disponibile, mostro struttura semplificata"
        echo
        
        echo -e "${BLUE}📁 Struttura Progetti:${NC}"
        for category in active sandbox production archive; do
            local category_dir="$PROJECTS_DIR/$category"
            if [[ -d "$category_dir" ]]; then
                local count=$(find "$category_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
                echo "├── $category/ ($count progetti)"
                
                while IFS= read -r project_path; do
                    local project_name=$(basename "$project_path")
                    local project_type=$(detect_project_type "$project_path")
                    echo "│   ├── $project_name ($project_type)"
                done < <(find "$category_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | head -3)
                
                if [[ $count -gt 3 ]]; then
                    echo "│   └── ... e altri $((count - 3)) progetti"
                fi
            fi
        done
        echo
    else
        echo -e "${BLUE}📁 Struttura Progetti:${NC}"
        tree -L 2 -d --dirsfirst "$PROJECTS_DIR" | head -20
        echo
    fi
}

# Search progetti
search_projects() {
    local search_term="$1"
    if [[ -z "$search_term" ]]; then
        warn "Termine di ricerca non specificato"
        return 1
    fi
    
    echo -e "${CYAN}🔍 Risultati ricerca per: ${BOLD}$search_term${NC}"
    echo
    
    local found_count=0
    
    for category in active sandbox production archive; do
        local category_dir="$PROJECTS_DIR/$category"
        if [[ ! -d "$category_dir" ]]; then continue; fi
        
        local found_in_category=false
        
        while IFS= read -r project_path; do
            local project_name=$(basename "$project_path")
            
            # Cerca nel nome del progetto
            if [[ "$project_name" =~ $search_term ]]; then
                if [[ "$found_in_category" == false ]]; then
                    echo -e "${BLUE}In $category:${NC}"
                    found_in_category=true
                fi
                
                local project_type=$(detect_project_type "$project_path")
                local size=$(get_project_size "$project_path")
                local last_mod_info=$(get_last_modified "$project_path")
                local last_mod_date=$(echo "$last_mod_info" | cut -d'|' -f1)
                
                echo "  • $project_name ($project_type) - $size - $last_mod_date"
                found_count=$((found_count + 1))
                continue
            fi
            
            # Cerca nei file README
            if [[ -f "$project_path/README.md" ]]; then
                if grep -qi "$search_term" "$project_path/README.md" 2>/dev/null; then
                    if [[ "$found_in_category" == false ]]; then
                        echo -e "${BLUE}In $category (README):${NC}"
                        found_in_category=true
                    fi
                    
                    echo "  • $project_name (trovato in README)"
                    found_count=$((found_count + 1))
                fi
            fi
            
        done < <(find "$category_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
        
        if [[ "$found_in_category" == true ]]; then
            echo
        fi
    done
    
    if [[ $found_count -eq 0 ]]; then
        warn "Nessun progetto trovato per '$search_term'"
    else
        info "Trovati $found_count risultati"
    fi
}

# Export lista progetti
export_projects() {
    local format="${1:-csv}"
    local output_file="${2:-projects-$(date +%Y%m%d-%H%M%S).$format}"
    
    info "Esportando lista progetti in formato $format..."
    
    case "$format" in
        "csv")
            echo "Category,Name,Type,Size,Files,LastModified,AgeDays,GitBranch,GitStatus,Template,Created" > "$output_file"
            
            for category in active sandbox production archive; do
                local category_dir="$PROJECTS_DIR/$category"
                if [[ ! -d "$category_dir" ]]; then continue; fi
                
                while IFS= read -r project_path; do
                    local project_name=$(basename "$project_path")
                    local size=$(get_project_size "$project_path")
                    local files=$(count_project_files "$project_path")
                    local last_mod_info=$(get_last_modified "$project_path")
                    local last_mod_date=$(echo "$last_mod_info" | cut -d'|' -f1)
                    local age_days=$(echo "$last_mod_info" | cut -d'|' -f2)
                    local git_branch=$(get_git_branch "$project_path")
                    local git_status=$(get_git_status "$project_path")
                    local project_type=$(detect_project_type "$project_path")
                    local claude_info=$(get_claude_info "$project_path")
                    local template=$(echo "$claude_info" | cut -d'|' -f1)
                    local created=$(echo "$claude_info" | cut -d'|' -f2)
                    
                    echo "$category,$project_name,$project_type,$size,$files,$last_mod_date,$age_days,$git_branch,$git_status,$template,$created" >> "$output_file"
                done < <(find "$category_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
            done
            ;;
            
        "json")
            echo '{"generated": "'$(date -Iseconds)'", "projects": [' > "$output_file"
            local first=true
            
            for category in active sandbox production archive; do
                local category_dir="$PROJECTS_DIR/$category"
                if [[ ! -d "$category_dir" ]]; then continue; fi
                
                while IFS= read -r project_path; do
                    if [[ "$first" == false ]]; then
                        echo "," >> "$output_file"
                    fi
                    first=false
                    
                    local project_name=$(basename "$project_path")
                    local size=$(get_project_size "$project_path")
                    local files=$(count_project_files "$project_path")
                    local last_mod_info=$(get_last_modified "$project_path")
                    local last_mod_date=$(echo "$last_mod_info" | cut -d'|' -f1)
                    local age_days=$(echo "$last_mod_info" | cut -d'|' -f2)
                    local git_branch=$(get_git_branch "$project_path")
                    local git_status=$(get_git_status "$project_path")
                    local project_type=$(detect_project_type "$project_path")
                    local claude_info=$(get_claude_info "$project_path")
                    local template=$(echo "$claude_info" | cut -d'|' -f1)
                    local created=$(echo "$claude_info" | cut -d'|' -f2)
                    
                    cat >> "$output_file" << EOF
  {
    "category": "$category",
    "name": "$project_name",
    "type": "$project_type",
    "size": "$size",
    "files": $files,
    "lastModified": "$last_mod_date",
    "ageDays": $age_days,
    "git": {
      "branch": "$git_branch",
      "status": "$git_status"
    },
    "template": "$template",
    "created": "$created",
    "path": "$project_path"
  }
EOF
                done < <(find "$category_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
            done
            
            echo "" >> "$output_file"
            echo "]}," >> "$output_file"
            echo "}" >> "$output_file"
            ;;
    esac
    
    info "Lista esportata in: $output_file"
}

# Help
show_help() {
    cat << 'EOF'
Uso: claude-list.sh [OPZIONI] [CATEGORIA]

Lista progetti Claude con informazioni dettagliate.

CATEGORIE:
    active       - Progetti in sviluppo attivo (default)
    sandbox      - Progetti temporanei/esperimenti
    production   - Progetti in produzione
    archive      - Progetti archiviati
    all          - Tutte le categorie

OPZIONI:
    -h, --help           Mostra questo messaggio
    -s, --summary        Mostra solo il riepilogo
    -d, --detailed       Vista dettagliata con tutte le colonne
    -t, --tree           Mostra struttura ad albero
    -f, --find TERM      Cerca progetti per nome o contenuto
    -e, --export FORMAT  Esporta lista (csv|json)
    -o, --output FILE    File di output per export

ESEMPI:
    # Lista progetti active
    claude-list.sh
    
    # Lista tutti i progetti
    claude-list.sh all
    
    # Vista dettagliata sandbox
    claude-list.sh sandbox --detailed
    
    # Riepilogo generale
    claude-list.sh --summary
    
    # Cerca progetti
    claude-list.sh --find "react"
    
    # Export CSV
    claude-list.sh --export csv
    
    # Struttura ad albero
    claude-list.sh --tree

COLORI:
    Verde  - Progetto recente (< 7 giorni)
    Giallo - Progetto moderato (7-30 giorni) o modifiche non committate
    Rosso  - Progetto vecchio (> 30 giorni)

EOF
}

# Main
main() {
    local category="active"
    local detailed=false
    local summary_only=false
    local tree_view=false
    local search_term=""
    local export_format=""
    local output_file=""
    
    # Parse argomenti
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--summary)
                summary_only=true
                shift
                ;;
            -d|--detailed)
                detailed=true
                shift
                ;;
            -t|--tree)
                tree_view=true
                shift
                ;;
            -f|--find)
                search_term="$2"
                shift 2
                ;;
            -e|--export)
                export_format="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            active|sandbox|production|archive|all)
                category="$1"
                shift
                ;;
            *)
                warn "Opzione non riconosciuta: $1"
                shift
                ;;
        esac
    done
    
    # Verifica che la directory progetti esista
    if [[ ! -d "$PROJECTS_DIR" ]]; then
        warn "Directory progetti non trovata: $PROJECTS_DIR"
        info "Esegui prima 'claude-new.sh' per creare la struttura"
        exit 1
    fi
    
    # Esegui azione richiesta
    if [[ -n "$search_term" ]]; then
        search_projects "$search_term"
    elif [[ -n "$export_format" ]]; then
        export_projects "$export_format" "$output_file"
    elif [[ "$tree_view" == true ]]; then
        show_tree_view
    elif [[ "$summary_only" == true ]]; then
        show_summary
    else
        # Mostra sempre il riepilogo
        show_summary
        
        # Mostra progetti per categoria
        if [[ "$category" == "all" ]]; then
            for cat in active sandbox production archive; do
                list_projects_category "$cat" "$detailed"
            done
        else
            list_projects_category "$category" "$detailed"
        fi
        
        # Suggerimenti
        echo -e "${CYAN}💡 Suggerimenti:${NC}"
        echo "   • Usa 'claude-new.sh' per creare nuovi progetti"
        echo "   • Usa 'claude-archive.sh' per archiviare progetti completati"
        echo "   • Usa 'cleanup-sandbox.sh' per pulire progetti sandbox vecchi"
        echo
    fi
}

# Esegui main
main "$@"