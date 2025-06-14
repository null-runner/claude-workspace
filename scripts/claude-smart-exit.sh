#!/bin/bash
# Claude Smart Exit - Prompt intelligente per salvare sessione
# Rileva attività significativa e chiede conferma di salvataggio

WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/claude-workspace}"
export WORKSPACE_DIR

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Funzione per analizzare attività sessione
analyze_session_activity() {
    local significant_activity=false
    local activity_summary=""
    local activity_score=0
    
    echo -e "${CYAN}🔍 Analyzing session activity...${NC}"
    
    python3 << 'EOF'
import json
import os
import subprocess
import sys
from datetime import datetime, timedelta
from pathlib import Path

def analyze_git_changes():
    """Analizza modifiche git per capire cosa è stato fatto"""
    try:
        # Git status
        result = subprocess.run(['git', 'status', '--porcelain'], 
                              capture_output=True, text=True, check=True,
                              cwd=os.environ.get('WORKSPACE_DIR'))
        
        if not result.stdout.strip():
            return 0, []
        
        changes = []
        score = 0
        
        for line in result.stdout.strip().split('\n'):
            if len(line) >= 3:
                status = line[:2]
                filepath = line[3:]
                
                # Categorizza cambiamenti
                if filepath.endswith('.py'):
                    changes.append(f"Modified Python: {filepath}")
                    score += 3
                elif filepath.endswith('.sh'):
                    changes.append(f"Modified script: {filepath}")
                    score += 3
                elif filepath.endswith('.md'):
                    changes.append(f"Updated docs: {filepath}")
                    score += 2
                elif filepath.endswith('.json'):
                    changes.append(f"Updated config: {filepath}")
                    score += 2
                elif 'CLAUDE.md' in filepath:
                    changes.append(f"Modified workspace config")
                    score += 4
                else:
                    changes.append(f"Modified: {filepath}")
                    score += 1
        
        return score, changes[:5]  # Max 5 changes to show
        
    except Exception as e:
        return 0, [f"Git analysis error: {str(e)}"]

def analyze_recent_memory():
    """Controlla se c'è stata attività recente significativa"""
    try:
        session_file = Path(os.environ.get('WORKSPACE_DIR')) / '.claude/memory/current-session-context.json'
        if not session_file.exists():
            return 0, "No previous session"
        
        with open(session_file) as f:
            session = json.load(f)
        
        # Controlla quanto tempo fa è stata l'ultima sessione
        last_timestamp = session.get('timestamp', '')
        if last_timestamp:
            last_time = datetime.fromisoformat(last_timestamp.replace('Z', '+00:00'))
            time_diff = datetime.now().replace(tzinfo=last_time.tzinfo) - last_time
            
            if time_diff < timedelta(minutes=10):
                return 1, f"Recent session ({time_diff.seconds//60}min ago)"
            elif time_diff < timedelta(hours=2):
                return 2, f"Session {time_diff.seconds//3600}h ago"
        
        return 0, "Old session"
        
    except Exception as e:
        return 0, f"Memory analysis error: {str(e)}"

def estimate_conversation_length():
    """Stima lunghezza conversazione basata su context"""
    # Placeholder - in una implementazione reale potresti contare
    # messaggi, file letti, comandi eseguiti, etc.
    
    # Per ora stimiamo in base a file modificati
    git_score, _ = analyze_git_changes()
    
    if git_score > 10:
        return 5, "Extensive conversation (many changes)"
    elif git_score > 5:
        return 3, "Moderate conversation (several changes)"
    elif git_score > 0:
        return 2, "Light conversation (few changes)"
    else:
        return 0, "Minimal conversation (no changes)"

def check_todo_activity():
    """Verifica se ci sono state attività sui todo"""
    try:
        # Questo è un placeholder - in futuro potresti tracciare
        # todo completati, task iniziati, etc.
        return 1, "Todo activity detected"
    except:
        return 0, "No todo activity"

# Analisi principale
print("🔍 SESSION ACTIVITY ANALYSIS")
print("=" * 40)

total_score = 0
activities = []

# Git changes
git_score, git_changes = analyze_git_changes()
total_score += git_score
if git_changes:
    activities.extend(git_changes)

print(f"📝 Git Changes Score: {git_score}")
for change in git_changes[:3]:
    print(f"   • {change}")

# Memory recency
memory_score, memory_info = analyze_recent_memory()
total_score += memory_score
print(f"🧠 Memory Recency Score: {memory_score} ({memory_info})")

# Conversation length
conv_score, conv_info = estimate_conversation_length()
total_score += conv_score
print(f"💬 Conversation Score: {conv_score} ({conv_info})")

# Todo activity
todo_score, todo_info = check_todo_activity()
# total_score += todo_score  # Commentato per ora
print(f"✅ Todo Score: {todo_score} ({todo_info})")

print()
print(f"🎯 TOTAL ACTIVITY SCORE: {total_score}")

# Determina se vale la pena salvare
if total_score >= 8:
    significance = "HIGH"
    recommendation = "STRONGLY_RECOMMEND"
elif total_score >= 4:
    significance = "MEDIUM" 
    recommendation = "RECOMMEND"
elif total_score >= 1:
    significance = "LOW"
    recommendation = "SUGGEST"
else:
    significance = "NONE"
    recommendation = "SKIP"

print(f"📊 Significance: {significance}")
print(f"💡 Recommendation: {recommendation}")

# Output per bash script
print("\n" + "="*50)
print(f"SCORE:{total_score}")
print(f"SIGNIFICANCE:{significance}")
print(f"RECOMMENDATION:{recommendation}")

# Summary per utente
if activities:
    print("SUMMARY:In this session we:")
    for activity in activities[:4]:
        print(f"SUMMARY:• {activity}")
else:
    print("SUMMARY:No significant file changes detected")

EOF
}

# Funzione principale smart exit
smart_exit_prompt() {
    echo -e "${PURPLE}🚪 Claude Smart Exit${NC}"
    echo ""
    
    # Analizza attività
    local analysis_output=$(analyze_session_activity)
    
    # Estrai informazioni dall'output Python
    local score=$(echo "$analysis_output" | grep "^SCORE:" | cut -d: -f2)
    local significance=$(echo "$analysis_output" | grep "^SIGNIFICANCE:" | cut -d: -f2)
    local recommendation=$(echo "$analysis_output" | grep "^RECOMMENDATION:" | cut -d: -f2)
    
    # Estrai summary
    local summary_lines=$(echo "$analysis_output" | grep "^SUMMARY:" | cut -d: -f2-)
    
    echo ""
    echo -e "${YELLOW}📋 Session Summary:${NC}"
    echo "$summary_lines" | while read line; do
        if [[ -n "$line" ]]; then
            echo -e "   $line"
        fi
    done
    echo ""
    
    # Decisione basata su recommendation
    case "$recommendation" in
        "STRONGLY_RECOMMEND")
            echo -e "${GREEN}💡 This session had significant activity. Save recommended!${NC}"
            prompt_save_session "high"
            ;;
        "RECOMMEND")
            echo -e "${BLUE}💡 This session had moderate activity. Save suggested.${NC}"
            prompt_save_session "medium"
            ;;
        "SUGGEST")
            echo -e "${CYAN}💡 This session had minor activity. Save optional.${NC}"
            prompt_save_session "low"
            ;;
        "SKIP")
            echo -e "${YELLOW}💡 Minimal activity detected. Save probably not needed.${NC}"
            echo -e "Exit without saving? ${CYAN}[Y/n]${NC}"
            read -r response
            if [[ "$response" =~ ^[Nn] ]]; then
                prompt_save_session "minimal"
            else
                # Marca exit come graceful anche senza salvataggio
                mark_graceful_exit
                echo -e "${GREEN}👋 Goodbye! Session not saved.${NC}"
                
                if terminate_claude_code "" "auto_mode"; then
                    exit 0
                else
                    return 0
                fi
            fi
            ;;
    esac
}

# Funzione per il prompt di salvataggio
prompt_save_session() {
    local priority="$1"
    
    echo ""
    echo -e "${CYAN}💾 Save this session?${NC}"
    echo -e "   ${GREEN}[y]${NC} Yes, save session"
    echo -e "   ${RED}[n]${NC} No, exit without saving"
    echo -e "   ${BLUE}[c]${NC} Custom note"
    echo ""
    echo -n "Choice [y/n/c]: "
    
    read -r choice
    
    case "$choice" in
        [Yy]|"")
            # Auto-generate note based on activity
            local auto_note=$(generate_auto_note)
            echo ""
            echo -e "${YELLOW}🤖 Auto-generated note:${NC} $auto_note"
            echo -e "Save with this note? ${CYAN}[Y/n]${NC}"
            read -r confirm
            if [[ ! "$confirm" =~ ^[Nn] ]]; then
                save_session "$auto_note"
            else
                prompt_custom_note
            fi
            ;;
        [Cc])
            prompt_custom_note
            ;;
        [Nn])
            # Trigger smart sync anche senza salvataggio sessione
            if [[ -f "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" ]]; then
                echo -e "${CYAN}🔄 Triggering exit sync...${NC}"
                "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" sync "Exit checkpoint (no session save)"
            fi
            
            # Marca exit come graceful anche senza salvataggio
            mark_graceful_exit
            echo -e "${GREEN}👋 Goodbye! Session not saved.${NC}"
            
            if terminate_claude_code "" "auto_mode"; then
                exit 0
            else
                return 0
            fi
            ;;
        *)
            echo -e "${RED}Invalid choice. Try again.${NC}"
            prompt_save_session "$priority"
            ;;
    esac
}

# Termina Claude Code in modo sicuro usando il process manager
terminate_claude_code() {
    local prompt_text="${1:-🚪 Terminare Claude Code? [Y/n]: }"
    local force_terminate="${2:-false}"  # New parameter for safe mode
    
    # In auto mode, terminate automatically without prompting
    if [[ "$force_terminate" == "auto_mode" ]]; then
        echo -e "${GREEN}🤖 Auto mode: Terminating Claude Code automatically${NC}"
        # Skip the prompt, go directly to termination
        echo -e "${RED}👋 Terminating Claude Code...${NC}"
        
        # Use the centralized process manager for safe termination
        local process_manager="$WORKSPACE_DIR/scripts/claude-process-manager.sh"
        
        if [[ ! -f "$process_manager" ]]; then
            echo -e "${RED}❌ Process manager not found - using fallback method${NC}"
            fallback_claude_termination
            return $?
        fi
        
        # Find Claude processes safely using the process manager
        echo -e "${CYAN}🔍 Searching for Claude processes safely...${NC}"
        local claude_pids
        mapfile -t claude_pids < <("$process_manager" find-processes "claude" 2>/dev/null)
        
        if [[ ${#claude_pids[@]} -eq 0 ]]; then
            # Try more specific pattern
            mapfile -t claude_pids < <("$process_manager" find-processes "claude-code" 2>/dev/null)
        fi
        
        if [[ ${#claude_pids[@]} -eq 0 ]]; then
            echo -e "${YELLOW}⚠️  No Claude processes found to terminate${NC}"
            return 0
        fi
        
        # Terminate each process safely
        for pid in "${claude_pids[@]}"; do
            if [[ -n "$pid" && "$pid" =~ ^[0-9]+$ ]]; then
                echo -e "${CYAN}🔄 Terminating Claude process: $pid${NC}"
                "$process_manager" terminate-process "$pid" 2>/dev/null || true
            fi
        done
        
        # Wait a moment for processes to terminate
        sleep 2
        
        # Verify termination
        mapfile -t remaining_pids < <("$process_manager" find-processes "claude" 2>/dev/null)
        if [[ ${#remaining_pids[@]} -eq 0 ]]; then
            echo -e "${GREEN}✅ Claude Code terminated successfully${NC}"
            return 0
        else
            echo -e "${YELLOW}⚠️  Some Claude processes may still be running${NC}"
            return 0
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}$prompt_text${NC}\c"
    read -r terminate_response
    
    if [[ "$terminate_response" =~ ^[Nn] ]]; then
        echo -e "${BLUE}💡 Sessione mantenuta aperta${NC}"
        return 1  # Don't terminate
    else
        echo -e "${RED}👋 Terminating Claude Code...${NC}"
        
        # Use the centralized process manager for safe termination
        local process_manager="$WORKSPACE_DIR/scripts/claude-process-manager.sh"
        
        if [[ ! -f "$process_manager" ]]; then
            echo -e "${RED}❌ Process manager not found - using fallback method${NC}"
            fallback_claude_termination
            return $?
        fi
        
        # Find Claude processes safely using the process manager
        echo -e "${CYAN}🔍 Searching for Claude processes safely...${NC}"
        local claude_pids
        mapfile -t claude_pids < <("$process_manager" find-processes "claude" 2>/dev/null)
        
        if [[ ${#claude_pids[@]} -eq 0 ]]; then
            # Try more specific pattern
            mapfile -t claude_pids < <("$process_manager" find-processes "claude-code" 2>/dev/null)
        fi
        
        if [[ ${#claude_pids[@]} -eq 0 ]]; then
            echo -e "${YELLOW}⚠️  No Claude processes found - already terminated?${NC}"
            return 0
        fi
        
        echo -e "${GREEN}✅ Found ${#claude_pids[@]} Claude process(es) for safe termination${NC}"
        
        # Terminate each Claude process using the safe process manager
        local terminated=0
        local failed=0
        
        for claude_pid in "${claude_pids[@]}"; do
            echo -e "${RED}🔥 Safely terminating Claude Code PID: $claude_pid${NC}"
            
            if "$process_manager" kill-pid "$claude_pid" "claude" 10; then
                ((terminated++))
            else
                ((failed++))
                echo -e "${RED}❌ Failed to terminate PID $claude_pid${NC}"
            fi
        done
        
        echo ""
        echo -e "${GREEN}✅ Termination summary: $terminated successful, $failed failed${NC}"
        
        if [[ $terminated -gt 0 ]]; then
            echo -e "${GREEN}✅ Claude Code termination completed!${NC}"
            return 0
        else
            echo -e "${RED}❌ No Claude processes were terminated${NC}"
            return 1
        fi
    fi
}

# Fallback termination method (old unsafe method, only used if process manager fails)
fallback_claude_termination() {
    echo -e "${YELLOW}⚠️  Using fallback termination method${NC}"
    
    # Simple pgrep with basic validation
    local claude_pids
    mapfile -t claude_pids < <(pgrep -x "claude" 2>/dev/null)
    
    if [[ ${#claude_pids[@]} -eq 0 ]]; then
        mapfile -t claude_pids < <(pgrep "claude-code" 2>/dev/null)
    fi
    
    if [[ ${#claude_pids[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No Claude processes found${NC}"
        return 0
    fi
    
    # Basic ownership check only
    local current_uid=$(id -u)
    local valid_pids=()
    
    for pid in "${claude_pids[@]}"; do
        local process_owner=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [[ "$process_owner" == "$current_uid" ]]; then
            valid_pids+=("$pid")
        fi
    done
    
    if [[ ${#valid_pids[@]} -eq 0 ]]; then
        echo -e "${YELLOW}⚠️  No owned Claude processes found${NC}"
        return 0
    fi
    
    # Simple termination
    for pid in "${valid_pids[@]}"; do
        echo -e "${RED}🔥 Terminating Claude PID: $pid${NC}"
        kill -TERM "$pid" 2>/dev/null
        sleep 2
        kill -KILL "$pid" 2>/dev/null
    done
    
    return 0
}

# Validate if a PID is actually a Claude process
validate_claude_process() {
    local pid="$1"
    
    # Check if PID exists and is accessible
    if ! kill -0 "$pid" 2>/dev/null; then
        echo -e "${YELLOW}⚠️  PID $pid not accessible or doesn't exist${NC}"
        return 1
    fi
    
    # Check process ownership (should be owned by current user)
    local process_owner=$(ps -o uid= -p "$pid" 2>/dev/null | tr -d ' ')
    local current_uid=$(id -u)
    
    if [[ -z "$process_owner" ]]; then
        echo -e "${YELLOW}⚠️  PID $pid: unable to determine process owner${NC}"
        return 1
    fi
    
    if [[ "$process_owner" != "$current_uid" ]]; then
        echo -e "${YELLOW}⚠️  PID $pid owned by different user (UID: $process_owner vs $current_uid)${NC}"
        return 1
    fi
    
    # Get process command and details
    local process_cmd=$(ps -o comm= -p "$pid" 2>/dev/null)
    local process_args=$(ps -o args= -p "$pid" 2>/dev/null)
    
    # Validate it's actually Claude-related
    if [[ "$process_cmd" =~ ^claude$ ]] || [[ "$process_args" =~ claude.*code ]] || [[ "$process_args" =~ ^claude ]]; then
        echo -e "${GREEN}✅ PID $pid validated as Claude process: $process_cmd${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  PID $pid doesn't appear to be Claude process: $process_cmd${NC}"
        echo -e "${YELLOW}    Args: $process_args${NC}"
        return 1
    fi
}

# Genera nota automatica intelligente
generate_auto_note() {
    python3 << 'EOF'
import subprocess
import os

try:
    # Analizza git status per generare nota smart
    result = subprocess.run(['git', 'status', '--porcelain'], 
                          capture_output=True, text=True,
                          cwd=os.environ.get('WORKSPACE_DIR'))
    
    if not result.stdout.strip():
        print("Session checkpoint")
        exit()
    
    # Conta tipi di modifiche
    scripts = 0
    configs = 0
    docs = 0
    other = 0
    
    for line in result.stdout.strip().split('\n'):
        if len(line) >= 3:
            filepath = line[3:]
            if filepath.endswith('.sh'):
                scripts += 1
            elif filepath.endswith(('.md', '.txt')):
                docs += 1
            elif filepath.endswith(('.json', '.yml', '.yaml')) or 'CLAUDE.md' in filepath:
                configs += 1
            else:
                other += 1
    
    # Genera nota basata sui cambiamenti
    parts = []
    if scripts > 0:
        parts.append(f"Updated {scripts} script{'s' if scripts > 1 else ''}")
    if configs > 0:
        parts.append(f"Modified {configs} config{'s' if configs > 1 else ''}")
    if docs > 0:
        parts.append(f"Updated {docs} doc{'s' if docs > 1 else ''}")
    if other > 0:
        parts.append(f"Changed {other} other file{'s' if other > 1 else ''}")
    
    if parts:
        note = " + ".join(parts)
    else:
        note = "File modifications"
    
    print(note)
    
except Exception as e:
    print("Development session")
EOF
}

# Marca exit come graceful per evitare recovery al prossimo startup (atomic)
mark_graceful_exit() {
    local recovery_dir="$WORKSPACE_DIR/.claude/auto-memory"
    local exit_type_file="$recovery_dir/exit_type"
    local temp_file="$recovery_dir/exit_type.tmp.$$"
    
    mkdir -p "$recovery_dir"
    # Atomic write: write to temp file, then move
    echo "graceful_exit" > "$temp_file"
    mv "$temp_file" "$exit_type_file"
}

# Prompt per nota custom
prompt_custom_note() {
    echo ""
    echo -e "${CYAN}✏️  Enter custom session note:${NC}"
    echo -n "Note: "
    read -r custom_note
    
    if [[ -z "$custom_note" ]]; then
        echo -e "${RED}Empty note. Using auto-generated note.${NC}"
        local auto_note=$(generate_auto_note)
        save_session "$auto_note"
    else
        save_session "$custom_note"
    fi
}

# Salva la sessione
save_session() {
    local note="$1"
    echo ""
    echo -e "${YELLOW}💾 Saving session...${NC}"
    
    # Marca exit come graceful prima di salvare
    mark_graceful_exit
    
    # Trigger smart sync on exit
    if [[ -f "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" ]]; then
        echo -e "${CYAN}🔄 Triggering exit sync...${NC}"
        "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" sync "Exit checkpoint: $note"
    fi
    
    if [[ -f "$WORKSPACE_DIR/scripts/claude-enhanced-save.sh" ]]; then
        "$WORKSPACE_DIR/scripts/claude-enhanced-save.sh" "$note"
        echo ""
        echo -e "${GREEN}✅ Session saved successfully!${NC}"
        echo -e "${GREEN}👋 Goodbye!${NC}"
    else
        echo -e "${RED}❌ Enhanced save script not found${NC}"
        echo -e "${YELLOW}💡 Using basic memory save...${NC}"
        
        # Fallback to basic save
        mkdir -p "$WORKSPACE_DIR/.claude/memory"
        echo "{\"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\", \"note\": \"$note\"}" > "$WORKSPACE_DIR/.claude/memory/last-session.json"
        echo -e "${GREEN}✅ Basic session saved!${NC}"
        echo -e "${GREEN}👋 Goodbye!${NC}"
    fi
    
    if terminate_claude_code "" "auto_mode"; then
        exit 0
    else
        return 0
    fi
}

# Help
show_help() {
    echo "Claude Smart Exit - Intelligent session save prompt"
    echo ""
    echo "Usage: claude-smart-exit [options]"
    echo ""
    echo "Options:"
    echo "  --force-prompt    Always show save prompt regardless of activity"
    echo "  --auto           Auto-save without prompt if significant activity"
    echo "  --safe-mode      Safe mode - never terminate Claude Code"
    echo "  --analyze-only   Only analyze and show activity, don't prompt"
    echo "  --help           Show this help"
    echo ""
    echo "This script automatically detects session activity and prompts"
    echo "intelligently about saving the session before exit."
}

# Main logic
case "${1:-}" in
    "--force-prompt")
        echo -e "${CYAN}🔧 Force prompt mode${NC}"
        prompt_save_session "forced"
        ;;
    "--safe-mode")
        echo -e "${CYAN}🔒 Safe mode - minimal operations only${NC}"
        echo -e "${BLUE}💾 Running safe exit operations...${NC}"
        
        # Mark graceful exit
        mark_graceful_exit
        echo -e "${GREEN}✅ Exit marked as graceful${NC}"
        
        # Trigger smart sync if available (safe operation)
        if [[ -f "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" ]]; then
            echo -e "${CYAN}🔄 Triggering safe sync...${NC}"
            timeout 15 "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" sync "Safe mode checkpoint" 2>/dev/null || {
                echo -e "${YELLOW}⚠️ Safe sync timeout/error - continuing${NC}"
            }
        fi
        
        echo -e "${GREEN}✅ Safe mode operations completed${NC}"
        echo -e "${BLUE}🔒 Claude Code session preserved${NC}"
        
        # Return without terminating Claude Code
        return 0
        ;;
    "--auto")
        echo -e "${CYAN}🤖 Auto-save mode${NC}"
        analysis_output=$(analyze_session_activity)
        recommendation=$(echo "$analysis_output" | grep "^RECOMMENDATION:" | cut -d: -f2)
        if [[ "$recommendation" == "STRONGLY_RECOMMEND" || "$recommendation" == "RECOMMEND" ]]; then
            auto_note=$(generate_auto_note)
            echo -e "${GREEN}🤖 Auto-saving session with note: $auto_note${NC}"
            save_session "$auto_note"
        else
            echo -e "${YELLOW}💡 Insufficient activity for auto-save${NC}"
            echo -e "${CYAN}🔄 Performing graceful exit operations...${NC}"
            
            # Still trigger smart sync on exit
            if [[ -f "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" ]]; then
                echo -e "${CYAN}🔄 Triggering exit sync...${NC}"
                "$WORKSPACE_DIR/scripts/claude-smart-sync.sh" sync "Exit checkpoint (minimal activity)"
                echo -e "${GREEN}✅ Smart sync completed${NC}"
            fi
            
            mark_graceful_exit
            echo -e "${GREEN}✅ Exit type marked as graceful${NC}"
            echo -e "${GREEN}✅ Graceful exit operations completed!${NC}"
            
            if terminate_claude_code "" "auto_mode"; then
                exit 0
            else
                return 0
            fi
        fi
        ;;
    "--analyze-only")
        analyze_session_activity
        exit 0
        ;;
    "--help"|"-h")
        show_help
        exit 0
        ;;
    "")
        smart_exit_prompt
        ;;
    *)
        echo -e "${RED}❌ Unknown option: $1${NC}"
        show_help
        exit 1
        ;;
esac