#!/bin/bash
# Claude Intelligence Extractor - Auto-extract insights from git, logs, patterns
# Autonomous decision and learning extraction

WORKSPACE_DIR="$HOME/claude-workspace"
INTELLIGENCE_DIR="$WORKSPACE_DIR/.claude/intelligence"
AUTO_DECISIONS_FILE="$INTELLIGENCE_DIR/auto-decisions.json"
AUTO_LEARNINGS_FILE="$INTELLIGENCE_DIR/auto-learnings.json"
EXTRACTION_LOG="$INTELLIGENCE_DIR/extraction.log"
LAST_EXTRACTION_FILE="$INTELLIGENCE_DIR/last-extraction.json"

# Colori
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Setup
mkdir -p "$INTELLIGENCE_DIR"

# Logging function
log_extraction() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$EXTRACTION_LOG"
}

# Initialize databases se non esistono
initialize_databases() {
    if [[ ! -f "$AUTO_DECISIONS_FILE" ]]; then
        cat > "$AUTO_DECISIONS_FILE" << 'EOF'
{
  "version": "1.0",
  "auto_decisions": [],
  "extraction_stats": {
    "total_extracted": 0,
    "by_source": {
      "git_commits": 0,
      "file_patterns": 0,
      "project_creation": 0
    }
  }
}
EOF
    fi
    
    if [[ ! -f "$AUTO_LEARNINGS_FILE" ]]; then
        cat > "$AUTO_LEARNINGS_FILE" << 'EOF'
{
  "version": "1.0", 
  "auto_learnings": [],
  "pattern_stats": {
    "total_patterns": 0,
    "by_category": {
      "errors": 0,
      "performance": 0,
      "workflow": 0
    }
  }
}
EOF
    fi
    
    if [[ ! -f "$LAST_EXTRACTION_FILE" ]]; then
        cat > "$LAST_EXTRACTION_FILE" << 'EOF'
{
  "last_git_commit": "",
  "last_check_time": "1970-01-01T00:00:00Z",
  "last_log_position": {}
}
EOF
    fi
}

# Extract decisions from git commits
extract_decisions_from_commits() {
    local since_time="${1:-15 minutes ago}"
    
    echo -e "${CYAN}🔍 Extracting decisions from git commits...${NC}"
    log_extraction "INFO" "Starting git commit analysis since: $since_time"
    
    # Export variables BEFORE python call
    export since_time="$since_time"
    export AUTO_DECISIONS_FILE="$AUTO_DECISIONS_FILE"
    export WORKSPACE_DIR="$WORKSPACE_DIR"
    
    python3 << 'EOF'
import subprocess
import json
import os
import re
from datetime import datetime

def analyze_commits(since_time):
    try:
        # Get commits since last extraction
        cmd = ['git', 'log', f'--since={since_time}', '--oneline', '--no-merges']
        result = subprocess.run(cmd, capture_output=True, text=True, 
                              cwd=os.environ.get('WORKSPACE_DIR'))
        
        if result.returncode != 0:
            return []
        
        commits = []
        for line in result.stdout.strip().split('\n'):
            if line:
                # Parse commit hash and message
                parts = line.split(' ', 1)
                if len(parts) == 2:
                    commit_hash, message = parts
                    commits.append({
                        'hash': commit_hash,
                        'message': message,
                        'timestamp': datetime.now().isoformat() + 'Z'
                    })
        
        return commits
        
    except Exception as e:
        print(f"Error analyzing commits: {e}")
        return []

def is_significant_commit(message):
    """Determine if commit message indicates a significant decision"""
    
    # Keywords that indicate significant decisions
    significant_keywords = [
        'feat:', 'feature:', 'add:', 'implement:', 'create:',
        'refactor:', 'restructure:', 'migrate:', 'switch:',
        'fix:', 'resolve:', 'solve:', 'patch:',
        'perf:', 'optimize:', 'improve:',
        'breaking:', 'BREAKING CHANGE',
        'security:', 'auth:', 'authentication:',
        'config:', 'configure:', 'setup:'
    ]
    
    # Anti-patterns (not significant)
    trivial_keywords = [
        'typo', 'format', 'style', 'whitespace', 'indent',
        'comment', 'doc update', 'minor', 'small',
        'cleanup', 'remove unused', 'update readme'
    ]
    
    message_lower = message.lower()
    
    # Check for trivial patterns first
    for trivial in trivial_keywords:
        if trivial in message_lower:
            return False
    
    # Check for significant patterns
    for keyword in significant_keywords:
        if keyword in message_lower:
            return True
    
    # Check length (longer messages are more likely to be significant)
    if len(message) > 50:
        return True
    
    return False

def extract_decision_info(commit):
    """Extract structured decision information from commit"""
    message = commit['message']
    
    # Category detection
    category = "general"
    if any(word in message.lower() for word in ['auth', 'security', 'permission']):
        category = "security"
    elif any(word in message.lower() for word in ['api', 'endpoint', 'route']):
        category = "architecture"  
    elif any(word in message.lower() for word in ['database', 'db', 'migrate', 'schema']):
        category = "architecture"
    elif any(word in message.lower() for word in ['test', 'spec', 'coverage']):
        category = "process"
    elif any(word in message.lower() for word in ['config', 'setup', 'env']):
        category = "tool"
    elif any(word in message.lower() for word in ['perf', 'optimize', 'speed']):
        category = "performance"
    
    # Impact detection
    impact = "medium"
    if any(word in message.lower() for word in ['breaking', 'major', 'critical']):
        impact = "high"
    elif any(word in message.lower() for word in ['minor', 'small', 'tweak']):
        impact = "low"
    
    # Clean title (remove conventional commit prefixes)
    title = message
    for prefix in ['feat:', 'fix:', 'refactor:', 'perf:', 'docs:', 'style:', 'test:']:
        if title.lower().startswith(prefix):
            title = title[len(prefix):].strip()
            break
    
    # Capitalize first letter
    if title:
        title = title[0].upper() + title[1:]
    
    return {
        "id": f"auto-{commit['hash']}-{int(datetime.now().timestamp())}",
        "title": title[:100],  # Limit title length
        "decision": f"Auto-extracted from commit: {message}",
        "reasoning": "Automatically detected from git commit pattern",
        "category": category,
        "impact": impact,
        "source": "git_commit",
        "commit_hash": commit['hash'],
        "timestamp": commit['timestamp'],
        "auto_extracted": True
    }

# Main extraction logic
since_time = os.environ.get('since_time', '15 minutes ago')
commits = analyze_commits(since_time)

significant_decisions = []
for commit in commits:
    if is_significant_commit(commit['message']):
        decision = extract_decision_info(commit)
        significant_decisions.append(decision)

# Load existing auto-decisions
auto_decisions_file = os.environ.get('AUTO_DECISIONS_FILE')
try:
    with open(auto_decisions_file, 'r') as f:
        decisions_db = json.load(f)
except:
    decisions_db = {
        "version": "1.0",
        "auto_decisions": [],
        "extraction_stats": {"total_extracted": 0, "by_source": {"git_commits": 0}}
    }

# Add new decisions
new_count = 0
for decision in significant_decisions:
    # Check for duplicates (same commit hash)
    existing = any(d.get('commit_hash') == decision['commit_hash'] 
                  for d in decisions_db['auto_decisions'])
    
    if not existing:
        decisions_db['auto_decisions'].append(decision)
        new_count += 1

# Update stats
decisions_db['extraction_stats']['total_extracted'] += new_count
decisions_db['extraction_stats']['by_source']['git_commits'] += new_count

# Save updated database
with open(auto_decisions_file, 'w') as f:
    json.dump(decisions_db, f, indent=2)

print(f"✅ Extracted {new_count} decisions from {len(commits)} commits")
if new_count > 0:
    print("📋 New decisions:")
    for decision in significant_decisions:
        if not any(d.get('commit_hash') == decision['commit_hash'] 
                  for d in decisions_db['auto_decisions'][:-new_count]):
            print(f"   • {decision['title']} ({decision['category']}, {decision['impact']} impact)")

EOF
}

# Extract learnings from error patterns
extract_learnings_from_logs() {
    echo -e "${CYAN}🧠 Extracting learnings from error patterns...${NC}"
    log_extraction "INFO" "Starting error pattern analysis"
    
    # Export variables BEFORE python call
    export AUTO_LEARNINGS_FILE="$AUTO_LEARNINGS_FILE"
    export WORKSPACE_DIR="$WORKSPACE_DIR"
    
    python3 << 'EOF'
import os
import json
import re
from collections import defaultdict, Counter
from datetime import datetime
from pathlib import Path

def analyze_log_files():
    """Analyze log files for error patterns"""
    
    error_patterns = defaultdict(list)
    
    # Log files to analyze
    log_files = [
        Path(os.environ.get('WORKSPACE_DIR')) / 'logs' / 'sync.log',
        Path(os.environ.get('WORKSPACE_DIR')) / '.claude' / 'activity' / 'activity.log',
        Path(os.environ.get('WORKSPACE_DIR')) / '.claude' / 'auto-memory' / 'auto-memory.log',
        Path(os.environ.get('WORKSPACE_DIR')) / '.claude' / 'auto-projects' / 'detector.log'
    ]
    
    error_keywords = ['error', 'fail', 'exception', 'crash', 'timeout', 'denied', 'not found']
    
    for log_file in log_files:
        if log_file.exists():
            try:
                content = log_file.read_text()
                lines = content.split('\n')
                
                for line in lines:
                    line_lower = line.lower()
                    if any(keyword in line_lower for keyword in error_keywords):
                        # Extract error pattern
                        pattern = extract_error_pattern(line)
                        if pattern:
                            error_patterns[pattern['type']].append({
                                'message': pattern['message'],
                                'file': str(log_file.name),
                                'line': line.strip()
                            })
            except Exception as e:
                continue
    
    return error_patterns

def extract_error_pattern(error_line):
    """Extract structured pattern from error line"""
    
    line_lower = error_line.lower()
    
    # Common error patterns
    if 'permission denied' in line_lower:
        return {
            'type': 'permission_issues',
            'message': 'Permission denied errors',
            'category': 'system'
        }
    elif 'no such file' in line_lower or 'not found' in line_lower:
        return {
            'type': 'file_not_found',
            'message': 'File not found errors',
            'category': 'filesystem'
        }
    elif 'python' in line_lower and ('import' in line_lower or 'module' in line_lower):
        return {
            'type': 'python_import_errors',
            'message': 'Python import/module errors',
            'category': 'dependencies'
        }
    elif 'git' in line_lower and ('fail' in line_lower or 'error' in line_lower):
        return {
            'type': 'git_errors',
            'message': 'Git operation errors',
            'category': 'version_control'
        }
    elif 'timeout' in line_lower:
        return {
            'type': 'timeout_errors',
            'message': 'Timeout/performance issues',
            'category': 'performance'
        }
    elif 'network' in line_lower or 'connection' in line_lower:
        return {
            'type': 'network_errors',
            'message': 'Network connectivity issues',
            'category': 'network'
        }
    
    return None

def generate_learnings(error_patterns):
    """Generate learning entries from error patterns"""
    
    learnings = []
    
    for pattern_type, occurrences in error_patterns.items():
        if len(occurrences) >= 2:  # Pattern must occur at least twice
            # Generate learning based on pattern
            learning = create_learning_from_pattern(pattern_type, occurrences)
            if learning:
                learnings.append(learning)
    
    return learnings

def create_learning_from_pattern(pattern_type, occurrences):
    """Create structured learning from error pattern"""
    
    learning_templates = {
        'permission_issues': {
            'title': 'SSH/File Permission Issues Pattern',
            'lesson': 'Recurring permission denied errors suggest SSH key or file permission configuration issues',
            'solution': 'Check SSH key permissions (chmod 600) and file ownership',
            'prevention': 'Add permission checks to setup scripts',
            'category': 'system_config'
        },
        'python_import_errors': {
            'title': 'Python Import/Module Errors Pattern', 
            'lesson': 'Missing Python module imports causing script failures',
            'solution': 'Add proper import statements and dependency checks',
            'prevention': 'Use virtual environments and requirements.txt',
            'category': 'development'
        },
        'git_errors': {
            'title': 'Git Operation Failures Pattern',
            'lesson': 'Git operations failing repeatedly, possibly due to repository state or permissions',
            'solution': 'Check repository integrity and remote access',
            'prevention': 'Add git status checks before operations',
            'category': 'version_control'
        },
        'file_not_found': {
            'title': 'File/Path Not Found Pattern',
            'lesson': 'Scripts trying to access non-existent files or paths',
            'solution': 'Add existence checks before file operations',
            'prevention': 'Use absolute paths and validate inputs',
            'category': 'filesystem'
        },
        'timeout_errors': {
            'title': 'Timeout/Performance Issues Pattern',
            'lesson': 'Operations timing out, indicating performance bottlenecks',
            'solution': 'Increase timeouts or optimize operations',
            'prevention': 'Add progress indicators and timeout handling',
            'category': 'performance'
        }
    }
    
    template = learning_templates.get(pattern_type)
    if not template:
        return None
    
    return {
        'id': f'auto-pattern-{pattern_type}-{int(datetime.now().timestamp())}',
        'timestamp': datetime.now().isoformat() + 'Z',
        'title': template['title'],
        'lesson': template['lesson'],
        'solution': template['solution'],
        'prevention': template['prevention'],
        'category': template['category'],
        'severity': 'medium',
        'source': 'error_pattern_analysis',
        'occurrences': len(occurrences),
        'auto_extracted': True,
        'pattern_details': {
            'type': pattern_type,
            'frequency': len(occurrences),
            'files_affected': list(set(occ['file'] for occ in occurrences))
        }
    }

# Main extraction logic
error_patterns = analyze_log_files()
new_learnings = generate_learnings(error_patterns)

# Load existing auto-learnings
auto_learnings_file = os.environ.get('AUTO_LEARNINGS_FILE')
try:
    with open(auto_learnings_file, 'r') as f:
        learnings_db = json.load(f)
except:
    learnings_db = {
        "version": "1.0",
        "auto_learnings": [],
        "pattern_stats": {"total_patterns": 0, "by_category": {}}
    }

# Add new learnings (avoid duplicates)
new_count = 0
for learning in new_learnings:
    # Check for existing similar pattern
    existing = any(l.get('pattern_details', {}).get('type') == learning['pattern_details']['type']
                  for l in learnings_db['auto_learnings'])
    
    if not existing:
        learnings_db['auto_learnings'].append(learning)
        new_count += 1
        
        # Update category stats
        category = learning['category']
        if category not in learnings_db['pattern_stats']['by_category']:
            learnings_db['pattern_stats']['by_category'][category] = 0
        learnings_db['pattern_stats']['by_category'][category] += 1

# Update stats
learnings_db['pattern_stats']['total_patterns'] += new_count

# Save updated database
with open(auto_learnings_file, 'w') as f:
    json.dump(learnings_db, f, indent=2)

print(f"✅ Extracted {new_count} learnings from {len(error_patterns)} error patterns")
if new_count > 0:
    print("📚 New learnings:")
    for learning in new_learnings:
        if not any(l.get('pattern_details', {}).get('type') == learning['pattern_details']['type']
                  for l in learnings_db['auto_learnings'][:-new_count]):
            print(f"   • {learning['title']} ({learning['occurrences']} occurrences)")

EOF
}

# Extract insights from file creation patterns
extract_insights_from_file_patterns() {
    local since_time="${1:-15 minutes ago}"
    
    echo -e "${CYAN}📁 Analyzing file creation patterns...${NC}"
    log_extraction "INFO" "Starting file pattern analysis since: $since_time"
    
    # Export variables BEFORE python call
    export AUTO_DECISIONS_FILE="$AUTO_DECISIONS_FILE"
    export WORKSPACE_DIR="$WORKSPACE_DIR"
    export since_minutes="${since_minutes:-15}"
    
    python3 << 'EOF'
import os
import subprocess
from datetime import datetime, timedelta
from pathlib import Path
import json

def analyze_file_patterns(since_minutes=15):
    """Analyze recent file creation/modification patterns"""
    
    insights = []
    workspace_dir = Path(os.environ.get('WORKSPACE_DIR'))
    
    # Find files modified in the last N minutes
    cutoff_time = datetime.now() - timedelta(minutes=since_minutes)
    
    significant_patterns = []
    
    # Check for new project creation
    projects_dir = workspace_dir / 'projects'
    if projects_dir.exists():
        for project_type_dir in projects_dir.iterdir():
            if project_type_dir.is_dir() and project_type_dir.name in ['active', 'sandbox', 'production']:
                for project_dir in project_type_dir.iterdir():
                    if project_dir.is_dir():
                        # Check if project was created recently
                        creation_time = datetime.fromtimestamp(project_dir.stat().st_ctime)
                        if creation_time > cutoff_time:
                            significant_patterns.append({
                                'type': 'new_project',
                                'name': project_dir.name,
                                'project_type': project_type_dir.name,
                                'path': str(project_dir),
                                'creation_time': creation_time.isoformat()
                            })
    
    # Check for new script creation
    scripts_dir = workspace_dir / 'scripts'
    if scripts_dir.exists():
        for script_file in scripts_dir.glob('*.sh'):
            creation_time = datetime.fromtimestamp(script_file.stat().st_ctime)
            if creation_time > cutoff_time:
                significant_patterns.append({
                    'type': 'new_script',
                    'name': script_file.name,
                    'path': str(script_file),
                    'creation_time': creation_time.isoformat()
                })
    
    # Check for new documentation
    for doc_file in workspace_dir.rglob('*.md'):
        if '/.git/' not in str(doc_file):
            creation_time = datetime.fromtimestamp(doc_file.stat().st_ctime)
            if creation_time > cutoff_time:
                significant_patterns.append({
                    'type': 'new_documentation',
                    'name': doc_file.name,
                    'path': str(doc_file.relative_to(workspace_dir)),
                    'creation_time': creation_time.isoformat()
                })
    
    return significant_patterns

def create_decision_from_pattern(pattern):
    """Create auto-decision from file pattern"""
    
    pattern_type = pattern['type']
    
    if pattern_type == 'new_project':
        return {
            'id': f"auto-project-{pattern['name']}-{int(datetime.now().timestamp())}",
            'title': f"Started new {pattern['project_type']} project: {pattern['name']}",
            'decision': f"Created new project '{pattern['name']}' in {pattern['project_type']} workspace",
            'reasoning': f"Auto-detected from project directory creation at {pattern['creation_time']}",
            'category': 'project_management',
            'impact': 'medium',
            'source': 'file_pattern_analysis',
            'timestamp': datetime.now().isoformat() + 'Z',
            'auto_extracted': True,
            'pattern_details': pattern
        }
    
    elif pattern_type == 'new_script':
        return {
            'id': f"auto-script-{pattern['name']}-{int(datetime.now().timestamp())}",
            'title': f"Added new workspace tool: {pattern['name']}",
            'decision': f"Created new script '{pattern['name']}' for workspace automation",
            'reasoning': f"Auto-detected from script creation at {pattern['creation_time']}",
            'category': 'tool',
            'impact': 'low',
            'source': 'file_pattern_analysis', 
            'timestamp': datetime.now().isoformat() + 'Z',
            'auto_extracted': True,
            'pattern_details': pattern
        }
    
    elif pattern_type == 'new_documentation':
        return {
            'id': f"auto-docs-{pattern['name']}-{int(datetime.now().timestamp())}",
            'title': f"Added documentation: {pattern['name']}",
            'decision': f"Created new documentation file '{pattern['name']}'",
            'reasoning': f"Auto-detected from documentation creation at {pattern['creation_time']}",
            'category': 'process',
            'impact': 'low',
            'source': 'file_pattern_analysis',
            'timestamp': datetime.now().isoformat() + 'Z',
            'auto_extracted': True,
            'pattern_details': pattern
        }
    
    return None

# Main extraction logic
since_minutes = int(os.environ.get('since_minutes', '15'))
patterns = analyze_file_patterns(since_minutes)

new_decisions = []
for pattern in patterns:
    decision = create_decision_from_pattern(pattern)
    if decision:
        new_decisions.append(decision)

# Load and update auto-decisions database
auto_decisions_file = os.environ.get('AUTO_DECISIONS_FILE')
try:
    with open(auto_decisions_file, 'r') as f:
        decisions_db = json.load(f)
except:
    decisions_db = {
        "version": "1.0",
        "auto_decisions": [],
        "extraction_stats": {"total_extracted": 0, "by_source": {"file_patterns": 0}}
    }

# Add new decisions (avoid duplicates based on pattern details)
new_count = 0
for decision in new_decisions:
    # Check for duplicates based on pattern path
    pattern_path = decision['pattern_details']['path']
    existing = any(d.get('pattern_details', {}).get('path') == pattern_path
                  for d in decisions_db['auto_decisions'])
    
    if not existing:
        decisions_db['auto_decisions'].append(decision)
        new_count += 1

# Update stats
if 'by_source' not in decisions_db['extraction_stats']:
    decisions_db['extraction_stats']['by_source'] = {}
if 'file_patterns' not in decisions_db['extraction_stats']['by_source']:
    decisions_db['extraction_stats']['by_source']['file_patterns'] = 0

decisions_db['extraction_stats']['total_extracted'] += new_count
decisions_db['extraction_stats']['by_source']['file_patterns'] += new_count

# Save updated database
with open(auto_decisions_file, 'w') as f:
    json.dump(decisions_db, f, indent=2)

print(f"✅ Extracted {new_count} decisions from {len(patterns)} file patterns")
if new_count > 0:
    print("📋 New pattern-based decisions:")
    for decision in new_decisions:
        pattern_path = decision['pattern_details']['path']
        if not any(d.get('pattern_details', {}).get('path') == pattern_path
                  for d in decisions_db['auto_decisions'][:-new_count]):
            print(f"   • {decision['title']}")

EOF
}

# Run full extraction cycle
run_full_extraction() {
    local since_time="${1:-15 minutes ago}"
    
    echo -e "${PURPLE}🤖 Running full intelligence extraction...${NC}"
    log_extraction "INFO" "Starting full extraction cycle"
    
    initialize_databases
    
    echo ""
    extract_decisions_from_commits "$since_time"
    echo ""
    extract_learnings_from_logs
    echo ""
    
    # Convert time to minutes for file pattern analysis
    local since_minutes=15
    if [[ "$since_time" == *"hour"* ]]; then
        since_minutes=60
    elif [[ "$since_time" == *"day"* ]]; then
        since_minutes=1440
    fi
    
    export since_minutes
    extract_insights_from_file_patterns
    
    # Update last extraction timestamp
    python3 -c "
import json
from datetime import datetime
last_extraction = {
    'last_check_time': datetime.now().isoformat() + 'Z',
    'extraction_type': 'full_cycle'
}
with open('$LAST_EXTRACTION_FILE', 'w') as f:
    json.dump(last_extraction, f, indent=2)
"
    
    echo ""
    echo -e "${GREEN}🎉 Intelligence extraction completed!${NC}"
    log_extraction "SUCCESS" "Full extraction cycle completed"
}

# Show extracted intelligence
show_intelligence_summary() {
    echo -e "${PURPLE}🧠 INTELLIGENCE SUMMARY${NC}"
    echo ""
    
    # Export variables BEFORE python call
    export AUTO_DECISIONS_FILE="$AUTO_DECISIONS_FILE"
    export AUTO_LEARNINGS_FILE="$AUTO_LEARNINGS_FILE"
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

# Load auto-decisions
try:
    with open(os.environ.get('AUTO_DECISIONS_FILE'), 'r') as f:
        decisions = json.load(f)
    
    print("📋 AUTO-EXTRACTED DECISIONS:")
    print(f"   Total: {decisions['extraction_stats']['total_extracted']}")
    
    # Show recent decisions
    recent_decisions = sorted(decisions['auto_decisions'], 
                            key=lambda x: x['timestamp'], reverse=True)[:5]
    
    for decision in recent_decisions:
        print(f"   • {decision['title']} ({decision['category']}, {decision['source']})")
    
except Exception as e:
    print("📋 AUTO-EXTRACTED DECISIONS: None found")

print()

# Load auto-learnings  
try:
    with open(os.environ.get('AUTO_LEARNINGS_FILE'), 'r') as f:
        learnings = json.load(f)
    
    print("📚 AUTO-EXTRACTED LEARNINGS:")
    print(f"   Total patterns: {learnings['pattern_stats']['total_patterns']}")
    
    # Show recent learnings
    recent_learnings = sorted(learnings['auto_learnings'],
                            key=lambda x: x['timestamp'], reverse=True)[:3]
    
    for learning in recent_learnings:
        print(f"   • {learning['title']} ({learning['occurrences']} occurrences)")
        
except Exception as e:
    print("📚 AUTO-EXTRACTED LEARNINGS: None found")

EOF
}

# Help
show_help() {
    echo "Claude Intelligence Extractor - Autonomous insight extraction"
    echo ""
    echo "Usage: claude-intelligence-extractor [command] [options]"
    echo ""
    echo "Commands:"
    echo "  extract [since]              Run full extraction (default: 15 minutes ago)"
    echo "  commits [since]              Extract decisions from git commits only"
    echo "  logs                         Extract learnings from error patterns only"
    echo "  files [minutes]              Extract insights from file patterns only"
    echo "  summary                      Show intelligence summary"
    echo "  init                         Initialize extraction databases"
    echo ""
    echo "Examples:"
    echo "  claude-intelligence-extractor extract"
    echo "  claude-intelligence-extractor extract '1 hour ago'"
    echo "  claude-intelligence-extractor commits '1 day ago'"
    echo "  claude-intelligence-extractor summary"
    echo ""
    echo "Auto-extraction sources:"
    echo "  • Git commits (significant changes, features, fixes)"
    echo "  • Log files (error patterns, recurring issues)"
    echo "  • File patterns (new projects, scripts, documentation)"
}

# Main logic
case "${1:-}" in
    "extract")
        run_full_extraction "${2:-15 minutes ago}"
        ;;
    "commits")
        initialize_databases
        extract_decisions_from_commits "${2:-15 minutes ago}"
        ;;
    "logs")
        initialize_databases
        extract_learnings_from_logs
        ;;
    "files")
        initialize_databases
        export since_minutes="${2:-15}"
        extract_insights_from_file_patterns
        ;;
    "summary")
        show_intelligence_summary
        ;;
    "init")
        initialize_databases
        echo -e "${GREEN}✅ Intelligence databases initialized${NC}"
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_intelligence_summary
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac