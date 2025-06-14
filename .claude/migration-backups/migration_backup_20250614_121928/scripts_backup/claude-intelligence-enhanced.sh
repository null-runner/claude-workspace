#!/bin/bash
# Claude Intelligence Enhanced - Pattern Recognition Engine per Claude Workspace
# Il cuore del valore di Claude Workspace - sistema di intelligence potenziato

WORKSPACE_DIR="$HOME/claude-workspace"
INTELLIGENCE_DIR="$WORKSPACE_DIR/.claude/intelligence"
ENHANCED_DIR="$INTELLIGENCE_DIR/enhanced"
PATTERNS_DB="$ENHANCED_DIR/patterns.json"
CONTEXT_DB="$ENHANCED_DIR/context.json"
LEARNINGS_DB="$ENHANCED_DIR/learnings.json"
USER_PROFILE_DB="$ENHANCED_DIR/user-profile.json"
CROSS_PROJECT_DB="$ENHANCED_DIR/cross-project.json"
ENHANCED_LOG="$ENHANCED_DIR/enhanced.log"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Setup directories
mkdir -p "$ENHANCED_DIR"

# Logging function
log_enhanced() {
    local level="$1"
    local message="$2"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$ENHANCED_LOG"
}

# Initialize enhanced databases
initialize_enhanced_databases() {
    log_enhanced "INFO" "Initializing enhanced intelligence databases"
    
    # Pattern Recognition Database
    if [[ ! -f "$PATTERNS_DB" ]]; then
        cat > "$PATTERNS_DB" << 'EOF'
{
  "version": "2.0",
  "pattern_recognition": {
    "git_patterns": {
      "commit_frequency": {},
      "work_hours": {},
      "preferred_languages": {},
      "decision_patterns": {},
      "error_resolution_patterns": {}
    },
    "project_patterns": {
      "creation_frequency": {},
      "naming_conventions": {},
      "structure_preferences": {},
      "abandonment_patterns": {}
    },
    "workflow_patterns": {
      "session_duration": {},
      "task_switching": {},
      "break_patterns": {},
      "productivity_hours": {}
    },
    "learning_patterns": {
      "error_repetition": {},
      "solution_effectiveness": {},
      "knowledge_gaps": {},
      "learning_velocity": {}
    }
  },
  "pattern_stats": {
    "total_patterns": 0,
    "confidence_scores": {},
    "last_update": ""
  }
}
EOF
    fi
    
    # Context Enhancement Database
    if [[ ! -f "$CONTEXT_DB" ]]; then
        cat > "$CONTEXT_DB" << 'EOF'
{
  "version": "2.0",
  "context_enhancement": {
    "user_specific_insights": {
      "coding_style": {},
      "preferred_solutions": {},
      "common_mistakes": {},
      "expertise_areas": {},
      "knowledge_gaps": {}
    },
    "session_context": {
      "current_focus": "",
      "recent_decisions": [],
      "active_learnings": [],
      "suggested_actions": []
    },
    "project_context": {
      "current_project": "",
      "project_insights": {},
      "cross_project_learnings": []
    },
    "claude_optimizations": {
      "suggested_prompts": [],
      "context_priorities": [],
      "error_prevention": [],
      "success_amplification": []
    }
  },
  "context_stats": {
    "total_insights": 0,
    "accuracy_score": 0.0,
    "last_update": ""
  }
}
EOF
    fi
    
    # Enhanced Learnings Database
    if [[ ! -f "$LEARNINGS_DB" ]]; then
        cat > "$LEARNINGS_DB" << 'EOF'
{
  "version": "2.0",
  "enhanced_learnings": {
    "categorized_learnings": {
      "technical_skills": [],
      "workflow_improvements": [],
      "error_patterns": [],
      "success_patterns": [],
      "decision_outcomes": []
    },
    "severity_scoring": {
      "critical_learnings": [],
      "important_learnings": [],
      "minor_learnings": []
    },
    "success_tracking": {
      "solution_success_rates": {},
      "learning_effectiveness": {},
      "pattern_accuracy": {}
    },
    "time_based_patterns": {
      "daily_patterns": {},
      "weekly_patterns": {},
      "monthly_trends": {}
    }
  },
  "learning_stats": {
    "total_learnings": 0,
    "success_rate": 0.0,
    "improvement_velocity": 0.0,
    "last_update": ""
  }
}
EOF
    fi
    
    # User Profile Database
    if [[ ! -f "$USER_PROFILE_DB" ]]; then
        cat > "$USER_PROFILE_DB" << 'EOF'
{
  "version": "2.0",
  "user_profile": {
    "working_style": {
      "preferred_hours": [],
      "session_length": 0,
      "break_frequency": 0,
      "multitasking_level": "medium"
    },
    "technical_profile": {
      "primary_languages": [],
      "frameworks": [],
      "tools": [],
      "expertise_level": {}
    },
    "learning_style": {
      "learns_from_errors": true,
      "prefers_examples": true,
      "documentation_level": "medium",
      "explanation_depth": "detailed"
    },
    "problem_solving": {
      "approach": "systematic",
      "debugging_style": "methodical",
      "preferred_resources": [],
      "typical_mistakes": []
    }
  },
  "profile_confidence": 0.0,
  "last_update": ""
}
EOF
    fi
    
    # Cross-Project Database
    if [[ ! -f "$CROSS_PROJECT_DB" ]]; then
        cat > "$CROSS_PROJECT_DB" << 'EOF'
{
  "version": "2.0",
  "cross_project": {
    "recurring_patterns": {
      "architecture_choices": {},
      "library_selections": {},
      "naming_conventions": {},
      "directory_structures": {}
    },
    "transferable_learnings": {
      "solutions_that_work": [],
      "anti_patterns": [],
      "best_practices": [],
      "optimization_techniques": []
    },
    "project_relationships": {
      "similar_projects": {},
      "shared_components": {},
      "evolution_patterns": {}
    }
  },
  "cross_project_stats": {
    "total_connections": 0,
    "pattern_strength": 0.0,
    "last_update": ""
  }
}
EOF
    fi
    
    log_enhanced "SUCCESS" "Enhanced intelligence databases initialized"
}

# Pattern Recognition Engine - Core function
analyze_git_commit_patterns() {
    echo -e "${CYAN}🔍 Analyzing Git Commit Patterns...${NC}"
    log_enhanced "INFO" "Starting advanced git pattern analysis"
    
    # Export variables for Python
    export PATTERNS_DB="$PATTERNS_DB"
    export USER_PROFILE_DB="$USER_PROFILE_DB"
    export WORKSPACE_DIR="$WORKSPACE_DIR"
    
    python3 << 'EOF'
import subprocess
import json
import os
import re
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import statistics

def get_git_history(days=30):
    """Get comprehensive git history for pattern analysis"""
    try:
        # Get commits from last N days
        since_date = (datetime.now() - timedelta(days=days)).strftime('%Y-%m-%d')
        
        # Get detailed commit info
        cmd = ['git', 'log', f'--since={since_date}', 
               '--pretty=format:%H|%ai|%s|%an', '--stat', '--no-merges']
        
        result = subprocess.run(cmd, capture_output=True, text=True, 
                              cwd=os.environ.get('WORKSPACE_DIR'))
        
        if result.returncode != 0:
            return []
        
        commits = []
        current_commit = None
        
        for line in result.stdout.split('\n'):
            if '|' in line and len(line.split('|')) == 4:
                # New commit line
                if current_commit:
                    commits.append(current_commit)
                
                hash_val, timestamp, message, author = line.split('|')
                current_commit = {
                    'hash': hash_val,
                    'timestamp': timestamp,
                    'message': message,
                    'author': author,
                    'files_changed': [],
                    'insertions': 0,
                    'deletions': 0
                }
            elif current_commit and ('insertion' in line or 'deletion' in line):
                # Stats line
                if 'insertion' in line:
                    current_commit['insertions'] += int(re.findall(r'(\d+) insertion', line)[0])
                if 'deletion' in line:
                    current_commit['deletions'] += int(re.findall(r'(\d+) deletion', line)[0])
            elif current_commit and '|' in line and not line.startswith(' '):
                # File change line
                parts = line.split('|')
                if len(parts) >= 2:
                    current_commit['files_changed'].append(parts[0].strip())
        
        if current_commit:
            commits.append(current_commit)
        
        return commits
        
    except Exception as e:
        print(f"Error getting git history: {e}")
        return []

def analyze_work_patterns(commits):
    """Analyze working hour patterns and frequency"""
    
    work_hours = defaultdict(int)
    work_days = defaultdict(int)
    commit_frequency = defaultdict(int)
    
    for commit in commits:
        try:
            dt = datetime.fromisoformat(commit['timestamp'].replace('Z', '+00:00'))
            
            # Hour analysis
            hour = dt.hour
            work_hours[hour] += 1
            
            # Day analysis
            day = dt.weekday()  # 0=Monday, 6=Sunday
            work_days[day] += 1
            
            # Daily frequency
            date_key = dt.strftime('%Y-%m-%d')
            commit_frequency[date_key] += 1
            
        except Exception:
            continue
    
    # Find peak hours
    peak_hours = sorted(work_hours.items(), key=lambda x: x[1], reverse=True)[:3]
    peak_days = sorted(work_days.items(), key=lambda x: x[1], reverse=True)[:3]
    
    # Calculate average commits per day
    avg_commits = statistics.mean(commit_frequency.values()) if commit_frequency else 0
    
    return {
        'peak_hours': [h[0] for h in peak_hours],
        'peak_days': [d[0] for d in peak_days],
        'average_commits_per_day': round(avg_commits, 2),
        'total_active_days': len(commit_frequency),
        'work_hour_distribution': dict(work_hours),
        'work_day_distribution': dict(work_days)
    }

def analyze_decision_patterns(commits):
    """Analyze decision-making patterns from commit messages"""
    
    decision_keywords = {
        'architecture': ['refactor', 'restructure', 'migrate', 'architecture', 'design'],
        'features': ['add', 'implement', 'create', 'new', 'feature'],
        'fixes': ['fix', 'resolve', 'patch', 'bug', 'error'],
        'optimization': ['optimize', 'improve', 'performance', 'speed', 'efficient'],
        'security': ['security', 'auth', 'permission', 'secure', 'vulnerability'],
        'documentation': ['doc', 'readme', 'comment', 'documentation'],
        'testing': ['test', 'spec', 'coverage', 'unittest'],
        'configuration': ['config', 'setup', 'env', 'deployment']
    }
    
    decision_counts = defaultdict(int)
    decision_impact = defaultdict(list)
    decision_timing = defaultdict(list)
    
    for commit in commits:
        message = commit['message'].lower()
        
        # Categorize decisions
        for category, keywords in decision_keywords.items():
            if any(keyword in message for keyword in keywords):
                decision_counts[category] += 1
                
                # Track impact (based on files changed and lines)
                impact_score = len(commit['files_changed']) + (commit['insertions'] + commit['deletions']) / 10
                decision_impact[category].append(impact_score)
                
                # Track timing
                try:
                    dt = datetime.fromisoformat(commit['timestamp'].replace('Z', '+00:00'))
                    decision_timing[category].append(dt.hour)
                except Exception:
                    continue
    
    # Calculate average impact per decision type
    decision_analysis = {}
    for category in decision_counts:
        decision_analysis[category] = {
            'frequency': decision_counts[category],
            'avg_impact': round(statistics.mean(decision_impact[category]), 2) if decision_impact[category] else 0,
            'preferred_hours': list(set(decision_timing[category])) if decision_timing[category] else []
        }
    
    return decision_analysis

def analyze_language_patterns(commits):
    """Analyze programming language and file type patterns"""
    
    language_extensions = {
        'python': ['.py', '.pyx', '.pyi'],
        'javascript': ['.js', '.jsx', '.ts', '.tsx'],
        'shell': ['.sh', '.bash', '.zsh'],
        'web': ['.html', '.css', '.scss', '.sass'],
        'config': ['.json', '.yaml', '.yml', '.toml', '.ini'],
        'documentation': ['.md', '.rst', '.txt'],
        'data': ['.csv', '.json', '.xml', '.sql']
    }
    
    language_counts = defaultdict(int)
    file_patterns = defaultdict(int)
    
    for commit in commits:
        for file_path in commit['files_changed']:
            # Extract extension
            if '.' in file_path:
                ext = '.' + file_path.split('.')[-1].lower()
                
                # Match to language
                for lang, extensions in language_extensions.items():
                    if ext in extensions:
                        language_counts[lang] += 1
                        break
                
                # Track file patterns
                file_patterns[ext] += 1
    
    # Sort by frequency
    preferred_languages = sorted(language_counts.items(), key=lambda x: x[1], reverse=True)
    
    return {
        'preferred_languages': dict(preferred_languages),
        'file_patterns': dict(sorted(file_patterns.items(), key=lambda x: x[1], reverse=True))
    }

def analyze_error_resolution_patterns(commits):
    """Analyze how user typically resolves errors"""
    
    error_keywords = ['fix', 'resolve', 'patch', 'bug', 'error', 'issue', 'problem']
    fix_commits = []
    
    for commit in commits:
        message = commit['message'].lower()
        if any(keyword in message for keyword in error_keywords):
            fix_commits.append(commit)
    
    if not fix_commits:
        return {}
    
    # Analyze fix patterns
    fix_size = [len(commit['files_changed']) for commit in fix_commits]
    fix_impact = [commit['insertions'] + commit['deletions'] for commit in fix_commits]
    
    # Analyze fix approaches
    fix_approaches = defaultdict(int)
    for commit in fix_commits:
        message = commit['message'].lower()
        if 'refactor' in message:
            fix_approaches['refactoring'] += 1
        elif 'add' in message or 'implement' in message:
            fix_approaches['feature_addition'] += 1
        elif 'remove' in message or 'delete' in message:
            fix_approaches['removal'] += 1
        elif 'update' in message or 'modify' in message:
            fix_approaches['modification'] += 1
        else:
            fix_approaches['direct_fix'] += 1
    
    return {
        'total_fixes': len(fix_commits),
        'avg_files_per_fix': round(statistics.mean(fix_size), 2) if fix_size else 0,
        'avg_lines_per_fix': round(statistics.mean(fix_impact), 2) if fix_impact else 0,
        'preferred_approaches': dict(fix_approaches),
        'fix_frequency': len(fix_commits) / len(commits) if commits else 0
    }

# Main analysis
commits = get_git_history(30)
print(f"📊 Analyzing {len(commits)} commits from last 30 days...")

if not commits:
    print("⚠️  No commits found for pattern analysis")
    exit(0)

# Run all pattern analyses
work_patterns = analyze_work_patterns(commits)
decision_patterns = analyze_decision_patterns(commits)
language_patterns = analyze_language_patterns(commits)
error_patterns = analyze_error_resolution_patterns(commits)

# Load existing patterns database
patterns_file = os.environ.get('PATTERNS_DB')
try:
    with open(patterns_file, 'r') as f:
        patterns_db = json.load(f)
except:
    patterns_db = {"version": "2.0", "pattern_recognition": {}}

# Update patterns database
patterns_db['pattern_recognition']['git_patterns'] = {
    'commit_frequency': work_patterns,
    'decision_patterns': decision_patterns,
    'preferred_languages': language_patterns,
    'error_resolution_patterns': error_patterns,
    'analysis_timestamp': datetime.now().isoformat() + 'Z'
}

# Calculate confidence scores
total_commits = len(commits)
confidence_scores = {
    'work_patterns': min(1.0, total_commits / 50),  # High confidence with 50+ commits
    'decision_patterns': min(1.0, sum(data['frequency'] for data in decision_patterns.values()) / 20),
    'language_patterns': min(1.0, sum(language_patterns['preferred_languages'].values()) / 30),
    'error_patterns': min(1.0, error_patterns.get('total_fixes', 0) / 10) if error_patterns else 0.0
}

patterns_db['pattern_stats'] = {
    'total_patterns': len(patterns_db['pattern_recognition']['git_patterns']),
    'confidence_scores': confidence_scores,
    'last_update': datetime.now().isoformat() + 'Z',
    'analysis_period_days': 30,
    'total_commits_analyzed': total_commits
}

# Save updated patterns
with open(patterns_file, 'w') as f:
    json.dump(patterns_db, f, indent=2)

# Output summary
print("✅ Pattern analysis completed!")
print(f"🎯 Work Pattern Confidence: {confidence_scores['work_patterns']:.2f}")
print(f"🎯 Decision Pattern Confidence: {confidence_scores['decision_patterns']:.2f}")
print(f"🎯 Language Pattern Confidence: {confidence_scores['language_patterns']:.2f}")
print(f"🎯 Error Resolution Confidence: {confidence_scores['error_patterns']:.2f}")

# Show key insights
print("\n🔑 Key Insights:")
if work_patterns['peak_hours']:
    print(f"   • Most productive hours: {work_patterns['peak_hours']}")
if decision_patterns:
    top_decision = max(decision_patterns.items(), key=lambda x: x[1]['frequency'])
    print(f"   • Primary focus area: {top_decision[0]} ({top_decision[1]['frequency']} decisions)")
if language_patterns['preferred_languages']:
    top_lang = list(language_patterns['preferred_languages'].keys())[0]
    print(f"   • Primary language: {top_lang}")

EOF
}

# Context Enhancement for Claude
generate_claude_context() {
    echo -e "${PURPLE}🤖 Generating Enhanced Context for Claude...${NC}"
    log_enhanced "INFO" "Starting Claude context enhancement"
    
    # Export variables for Python
    export PATTERNS_DB="$PATTERNS_DB"
    export CONTEXT_DB="$CONTEXT_DB"
    export USER_PROFILE_DB="$USER_PROFILE_DB"
    export INTELLIGENCE_DIR="$INTELLIGENCE_DIR"
    
    python3 << 'EOF'
import json
import os
from datetime import datetime, timedelta

def load_database(db_path):
    """Load database with error handling"""
    try:
        with open(db_path, 'r') as f:
            return json.load(f)
    except:
        return {}

def generate_user_specific_insights(patterns_db, existing_intelligence):
    """Generate insights specific to this user's patterns"""
    
    insights = {
        'coding_style': {},
        'preferred_solutions': {},
        'common_mistakes': {},
        'expertise_areas': {},
        'knowledge_gaps': {}
    }
    
    # Extract coding style from patterns
    git_patterns = patterns_db.get('pattern_recognition', {}).get('git_patterns', {})
    
    # Language preferences
    lang_patterns = git_patterns.get('preferred_languages', {})
    if lang_patterns:
        primary_languages = list(lang_patterns.get('preferred_languages', {}).keys())[:3]
        insights['coding_style']['primary_languages'] = primary_languages
        
        # File patterns indicate preferences
        file_patterns = lang_patterns.get('file_patterns', {})
        if '.py' in file_patterns:
            insights['coding_style']['python_focus'] = True
        if '.sh' in file_patterns:
            insights['coding_style']['automation_focus'] = True
        if '.md' in file_patterns:
            insights['coding_style']['documentation_conscious'] = True
    
    # Decision patterns reveal expertise
    decision_patterns = git_patterns.get('decision_patterns', {})
    for category, data in decision_patterns.items():
        frequency = data.get('frequency', 0)
        if frequency > 5:  # Regular activity
            insights['expertise_areas'][category] = {
                'confidence': 'high',
                'frequency': frequency,
                'avg_impact': data.get('avg_impact', 0)
            }
        elif frequency > 2:  # Some activity
            insights['expertise_areas'][category] = {
                'confidence': 'medium',
                'frequency': frequency,
                'avg_impact': data.get('avg_impact', 0)
            }
    
    # Error patterns reveal common mistakes
    error_patterns = git_patterns.get('error_resolution_patterns', {})
    if error_patterns:
        fix_frequency = error_patterns.get('fix_frequency', 0)
        if fix_frequency > 0.3:  # More than 30% of commits are fixes
            insights['common_mistakes']['high_error_rate'] = {
                'description': 'High ratio of fix commits indicates frequent errors',
                'suggestion': 'Consider more testing and code review',
                'frequency': fix_frequency
            }
        
        preferred_approaches = error_patterns.get('preferred_approaches', {})
        if preferred_approaches:
            top_approach = max(preferred_approaches.items(), key=lambda x: x[1])
            insights['preferred_solutions']['error_resolution'] = {
                'preferred_method': top_approach[0],
                'frequency': top_approach[1],
                'description': f'Typically resolves errors through {top_approach[0]}'
            }
    
    # Identify knowledge gaps from patterns
    low_activity_areas = []
    for category in ['testing', 'documentation', 'security', 'optimization']:
        if category not in decision_patterns or decision_patterns[category]['frequency'] < 2:
            low_activity_areas.append(category)
    
    if low_activity_areas:
        insights['knowledge_gaps']['suggested_learning_areas'] = low_activity_areas
    
    # Work patterns for optimization
    work_patterns = git_patterns.get('commit_frequency', {})
    if work_patterns:
        peak_hours = work_patterns.get('peak_hours', [])
        if peak_hours:
            insights['coding_style']['optimal_hours'] = peak_hours
    
    return insights

def generate_session_context(patterns_db, existing_intelligence):
    """Generate context for current session"""
    
    # Get recent decisions from existing intelligence
    recent_decisions = []
    auto_decisions = existing_intelligence.get('auto_decisions', [])
    
    # Get decisions from last 24 hours
    cutoff = datetime.now() - timedelta(hours=24)
    for decision in auto_decisions:
        try:
            decision_time = datetime.fromisoformat(decision['timestamp'].replace('Z', '+00:00'))
            if decision_time > cutoff:
                recent_decisions.append({
                    'title': decision['title'],
                    'category': decision['category'],
                    'impact': decision['impact'],
                    'time': decision_time.strftime('%H:%M')
                })
        except:
            continue
    
    # Get active learnings
    active_learnings = []
    auto_learnings = existing_intelligence.get('auto_learnings', [])
    for learning in auto_learnings[-3:]:  # Last 3 learnings
        active_learnings.append({
            'title': learning['title'],
            'category': learning['category'],
            'lesson': learning['lesson'][:100] + '...' if len(learning['lesson']) > 100 else learning['lesson']
        })
    
    # Generate suggested actions based on patterns
    suggested_actions = []
    
    # Analysis patterns to suggest actions
    git_patterns = patterns_db.get('pattern_recognition', {}).get('git_patterns', {})
    decision_patterns = git_patterns.get('decision_patterns', {})
    
    if 'testing' not in decision_patterns or decision_patterns.get('testing', {}).get('frequency', 0) < 2:
        suggested_actions.append({
            'action': 'Add unit tests',
            'reason': 'Low testing activity detected',
            'priority': 'medium'
        })
    
    if 'documentation' not in decision_patterns or decision_patterns.get('documentation', {}).get('frequency', 0) < 3:
        suggested_actions.append({
            'action': 'Update documentation',
            'reason': 'Documentation could be improved',
            'priority': 'low'
        })
    
    error_patterns = git_patterns.get('error_resolution_patterns', {})
    if error_patterns.get('fix_frequency', 0) > 0.4:
        suggested_actions.append({
            'action': 'Review code quality',
            'reason': 'High error rate detected',
            'priority': 'high'
        })
    
    return {
        'current_focus': 'pattern_analysis',
        'recent_decisions': recent_decisions,
        'active_learnings': active_learnings,
        'suggested_actions': suggested_actions
    }

def generate_claude_optimizations(insights, session_context):
    """Generate Claude-specific optimizations"""
    
    suggested_prompts = []
    context_priorities = []
    error_prevention = []
    success_amplification = []
    
    # Generate prompts based on expertise areas
    expertise = insights.get('expertise_areas', {})
    for area, data in expertise.items():
        if data['confidence'] == 'high':
            suggested_prompts.append(f"Leverage my strong {area} background when suggesting solutions")
        elif data['confidence'] == 'medium':
            context_priorities.append(f"Provide moderate detail for {area} topics")
    
    # Error prevention based on common mistakes
    mistakes = insights.get('common_mistakes', {})
    for mistake_type, data in mistakes.items():
        error_prevention.append({
            'pattern': mistake_type,
            'prevention': data['suggestion'],
            'context': data['description']
        })
    
    # Success amplification based on preferred solutions
    solutions = insights.get('preferred_solutions', {})
    for solution_type, data in solutions.items():
        success_amplification.append({
            'approach': data['preferred_method'],
            'context': data['description'],
            'success_rate': data.get('frequency', 0)
        })
    
    # Context priorities based on work patterns
    coding_style = insights.get('coding_style', {})
    if coding_style.get('python_focus'):
        context_priorities.append("Prioritize Python-specific solutions and examples")
    if coding_style.get('automation_focus'):
        context_priorities.append("Emphasize automation and scripting solutions")
    if coding_style.get('documentation_conscious'):
        suggested_prompts.append("Always include documentation suggestions")
    
    # Add session-specific optimizations
    for action in session_context.get('suggested_actions', []):
        if action['priority'] == 'high':
            context_priorities.append(f"Focus on: {action['action']}")
    
    return {
        'suggested_prompts': suggested_prompts,
        'context_priorities': context_priorities,
        'error_prevention': error_prevention,
        'success_amplification': success_amplification
    }

# Load databases
patterns_db = load_database(os.environ.get('PATTERNS_DB'))
user_profile_db = load_database(os.environ.get('USER_PROFILE_DB'))

# Load existing intelligence for context
intelligence_dir = os.environ.get('INTELLIGENCE_DIR')
existing_decisions = load_database(os.path.join(intelligence_dir, 'auto-decisions.json'))
existing_learnings = load_database(os.path.join(intelligence_dir, 'auto-learnings.json'))

existing_intelligence = {
    'auto_decisions': existing_decisions.get('auto_decisions', []),
    'auto_learnings': existing_learnings.get('auto_learnings', [])
}

# Generate enhanced context
user_insights = generate_user_specific_insights(patterns_db, existing_intelligence)
session_context = generate_session_context(patterns_db, existing_intelligence)
claude_optimizations = generate_claude_optimizations(user_insights, session_context)

# Build context database
context_db = {
    'version': '2.0',
    'context_enhancement': {
        'user_specific_insights': user_insights,
        'session_context': session_context,
        'project_context': {
            'current_project': 'claude-workspace',
            'project_insights': {
                'type': 'automation_framework',
                'complexity': 'high',
                'focus_areas': ['intelligence', 'automation', 'productivity']
            },
            'cross_project_learnings': []
        },
        'claude_optimizations': claude_optimizations
    },
    'context_stats': {
        'total_insights': len(user_insights),
        'accuracy_score': 0.85,  # Base score, will improve over time
        'last_update': datetime.now().isoformat() + 'Z'
    }
}

# Save context database
context_file = os.environ.get('CONTEXT_DB')
with open(context_file, 'w') as f:
    json.dump(context_db, f, indent=2)

print("✅ Claude context enhancement completed!")
print(f"🧠 Generated {len(user_insights)} user-specific insights")
print(f"📋 Current session has {len(session_context['recent_decisions'])} recent decisions")
print(f"🎯 Created {len(claude_optimizations['suggested_prompts'])} optimization prompts")

# Show key context elements
print("\n🔑 Key Context for Claude:")
if user_insights.get('expertise_areas'):
    expertise_list = [area for area, data in user_insights['expertise_areas'].items() 
                     if data['confidence'] == 'high']
    if expertise_list:
        print(f"   • High expertise: {', '.join(expertise_list)}")

if session_context.get('suggested_actions'):
    high_priority = [action['action'] for action in session_context['suggested_actions'] 
                    if action['priority'] == 'high']
    if high_priority:
        print(f"   • High priority actions: {', '.join(high_priority)}")

if claude_optimizations.get('context_priorities'):
    print(f"   • Context priorities: {len(claude_optimizations['context_priorities'])} active")

EOF
}

# Auto-Learning Improvements with categorization and scoring
enhance_learning_system() {
    echo -e "${BLUE}📚 Enhancing Learning System...${NC}"
    log_enhanced "INFO" "Starting learning system enhancement"
    
    # Export variables for Python
    export LEARNINGS_DB="$LEARNINGS_DB"
    export INTELLIGENCE_DIR="$INTELLIGENCE_DIR"
    export PATTERNS_DB="$PATTERNS_DB"
    
    python3 << 'EOF'
import json
import os
from datetime import datetime, timedelta
from collections import defaultdict, Counter
import re

def load_existing_learnings():
    """Load existing learnings from old system"""
    
    intelligence_dir = os.environ.get('INTELLIGENCE_DIR')
    old_learnings_file = os.path.join(intelligence_dir, 'auto-learnings.json')
    
    try:
        with open(old_learnings_file, 'r') as f:
            old_data = json.load(f)
        return old_data.get('auto_learnings', [])
    except:
        return []

def categorize_learning(learning):
    """Enhanced categorization of learnings"""
    
    title = learning.get('title', '').lower()
    lesson = learning.get('lesson', '').lower()
    category = learning.get('category', '').lower()
    
    # Define comprehensive categories
    if any(word in title + lesson for word in ['crash', 'system', 'stability', 'recovery']):
        return 'system_stability'
    elif any(word in title + lesson for word in ['permission', 'ssh', 'access', 'denied']):
        return 'access_control'
    elif any(word in title + lesson for word in ['git', 'repository', 'commit', 'branch']):
        return 'version_control'
    elif any(word in title + lesson for word in ['python', 'import', 'module', 'script']):
        return 'programming'
    elif any(word in title + lesson for word in ['network', 'connection', 'timeout', 'remote']):
        return 'networking'
    elif any(word in title + lesson for word in ['file', 'path', 'directory', 'filesystem']):
        return 'filesystem'
    elif any(word in title + lesson for word in ['performance', 'optimize', 'speed', 'slow']):
        return 'performance'
    elif any(word in title + lesson for word in ['config', 'setup', 'environment', 'deployment']):
        return 'configuration'
    elif any(word in title + lesson for word in ['security', 'auth', 'vulnerability', 'secure']):
        return 'security'
    elif any(word in title + lesson for word in ['workflow', 'process', 'automation']):
        return 'workflow'
    else:
        return 'general'

def calculate_severity_score(learning):
    """Calculate severity score for learning"""
    
    # Base score factors
    score = 0
    
    title = learning.get('title', '').lower()
    lesson = learning.get('lesson', '').lower()
    occurrences = learning.get('occurrences', 1)
    
    # High severity indicators
    if any(word in title + lesson for word in ['critical', 'crash', 'fail', 'break', 'error']):
        score += 30
    
    # Medium severity indicators
    if any(word in title + lesson for word in ['warning', 'issue', 'problem', 'slow']):
        score += 20
    
    # Frequency impact
    if occurrences > 10:
        score += 25
    elif occurrences > 5:
        score += 15
    elif occurrences > 2:
        score += 10
    
    # Impact area
    if any(word in title + lesson for word in ['system', 'security', 'data', 'production']):
        score += 20
    
    # Time sensitivity
    if any(word in title + lesson for word in ['timeout', 'performance', 'speed']):
        score += 15
    
    # Normalize to 0-100 scale
    score = min(100, score)
    
    # Classify severity
    if score >= 70:
        severity = 'critical'
    elif score >= 40:
        severity = 'important'
    else:
        severity = 'minor'
    
    return severity, score

def analyze_learning_effectiveness(learnings):
    """Analyze effectiveness of past learnings"""
    
    effectiveness = {}
    category_success = defaultdict(list)
    
    for learning in learnings:
        category = categorize_learning(learning)
        occurrences = learning.get('occurrences', 1)
        
        # Simple effectiveness heuristic: 
        # - Lower occurrences after initial learning = more effective
        # - Recent learnings with no follow-up issues = effective
        
        # For now, use basic scoring
        effectiveness_score = 1.0 / (1 + occurrences * 0.1)  # Decreases with more occurrences
        category_success[category].append(effectiveness_score)
    
    # Calculate average effectiveness per category
    for category, scores in category_success.items():
        effectiveness[category] = sum(scores) / len(scores) if scores else 0.0
    
    return effectiveness

def extract_success_patterns(learnings):
    """Extract patterns from successful learning applications"""
    
    success_patterns = defaultdict(list)
    
    for learning in learnings:
        category = categorize_learning(learning)
        solution = learning.get('solution', '')
        prevention = learning.get('prevention', '')
        
        if solution:
            success_patterns[category].append({
                'solution': solution,
                'prevention': prevention,
                'effectiveness': 1.0 / (1 + learning.get('occurrences', 1) * 0.1)
            })
    
    return dict(success_patterns)

def generate_time_based_patterns(learnings):
    """Generate time-based learning patterns"""
    
    daily_patterns = defaultdict(list)
    weekly_patterns = defaultdict(list)
    monthly_patterns = defaultdict(list)
    
    for learning in learnings:
        try:
            timestamp = learning.get('timestamp', '')
            if timestamp:
                dt = datetime.fromisoformat(timestamp.replace('Z', '+00:00'))
                
                # Daily patterns
                hour = dt.hour
                daily_patterns[hour].append(categorize_learning(learning))
                
                # Weekly patterns
                weekday = dt.weekday()
                weekly_patterns[weekday].append(categorize_learning(learning))
                
                # Monthly patterns
                day = dt.day
                monthly_patterns[day].append(categorize_learning(learning))
                
        except:
            continue
    
    # Convert to frequency counts
    return {
        'daily_patterns': {hour: Counter(categories) for hour, categories in daily_patterns.items()},
        'weekly_patterns': {day: Counter(categories) for day, categories in weekly_patterns.items()},
        'monthly_patterns': {day: Counter(categories) for day, categories in monthly_patterns.items()}
    }

# Load existing learnings
existing_learnings = load_existing_learnings()
print(f"📊 Processing {len(existing_learnings)} existing learnings...")

if not existing_learnings:
    print("⚠️  No existing learnings found")
    # Create empty enhanced database
    enhanced_db = {
        'version': '2.0',
        'enhanced_learnings': {
            'categorized_learnings': {
                'technical_skills': [],
                'workflow_improvements': [],
                'error_patterns': [],
                'success_patterns': [],
                'decision_outcomes': []
            },
            'severity_scoring': {
                'critical_learnings': [],
                'important_learnings': [],
                'minor_learnings': []
            },
            'success_tracking': {
                'solution_success_rates': {},
                'learning_effectiveness': {},
                'pattern_accuracy': {}
            },
            'time_based_patterns': {
                'daily_patterns': {},
                'weekly_patterns': {},
                'monthly_patterns': {}
            }
        },
        'learning_stats': {
            'total_learnings': 0,
            'success_rate': 0.0,
            'improvement_velocity': 0.0,
            'last_update': datetime.now().isoformat() + 'Z'
        }
    }
else:
    # Process existing learnings
    categorized_learnings = {
        'system_stability': [],
        'access_control': [],
        'version_control': [],
        'programming': [],
        'networking': [],
        'filesystem': [],
        'performance': [],
        'configuration': [],
        'security': [],
        'workflow': [],
        'general': []
    }
    
    severity_scoring = {
        'critical_learnings': [],
        'important_learnings': [],
        'minor_learnings': []
    }
    
    # Process each learning
    for learning in existing_learnings:
        # Enhanced categorization
        category = categorize_learning(learning)
        categorized_learnings[category].append(learning)
        
        # Severity scoring
        severity, score = calculate_severity_score(learning)
        learning['severity_score'] = score
        learning['enhanced_category'] = category
        severity_scoring[f'{severity}_learnings'].append(learning)
    
    # Analyze effectiveness and patterns
    learning_effectiveness = analyze_learning_effectiveness(existing_learnings)
    success_patterns = extract_success_patterns(existing_learnings)
    time_patterns = generate_time_based_patterns(existing_learnings)
    
    # Calculate overall success rate
    total_occurrences = sum(learning.get('occurrences', 1) for learning in existing_learnings)
    avg_occurrences = total_occurrences / len(existing_learnings) if existing_learnings else 0
    success_rate = max(0.0, 1.0 - (avg_occurrences - 1) * 0.1)  # Heuristic
    
    # Calculate improvement velocity (learnings per week)
    if existing_learnings:
        # Get time span of learnings
        timestamps = [learning.get('timestamp', '') for learning in existing_learnings if learning.get('timestamp')]
        if timestamps:
            try:
                dates = [datetime.fromisoformat(ts.replace('Z', '+00:00')) for ts in timestamps]
                dates.sort()
                time_span = (dates[-1] - dates[0]).days
                improvement_velocity = len(existing_learnings) / max(1, time_span / 7)  # per week
            except:
                improvement_velocity = 0.0
        else:
            improvement_velocity = 0.0
    else:
        improvement_velocity = 0.0
    
    # Build enhanced database
    enhanced_db = {
        'version': '2.0',
        'enhanced_learnings': {
            'categorized_learnings': categorized_learnings,
            'severity_scoring': severity_scoring,
            'success_tracking': {
                'solution_success_rates': success_patterns,
                'learning_effectiveness': learning_effectiveness,
                'pattern_accuracy': {}  # Will be populated over time
            },
            'time_based_patterns': time_patterns
        },
        'learning_stats': {
            'total_learnings': len(existing_learnings),
            'success_rate': round(success_rate, 3),
            'improvement_velocity': round(improvement_velocity, 2),
            'last_update': datetime.now().isoformat() + 'Z'
        }
    }

# Save enhanced learnings database
learnings_file = os.environ.get('LEARNINGS_DB')
with open(learnings_file, 'w') as f:
    json.dump(enhanced_db, f, indent=2)

print("✅ Learning system enhancement completed!")
print(f"📚 Total learnings processed: {enhanced_db['learning_stats']['total_learnings']}")
print(f"🎯 Success rate: {enhanced_db['learning_stats']['success_rate']:.2f}")
print(f"⚡ Improvement velocity: {enhanced_db['learning_stats']['improvement_velocity']:.2f} learnings/week")

# Show categorization summary
categorized = enhanced_db['enhanced_learnings']['categorized_learnings']
for category, learnings in categorized.items():
    if learnings:
        print(f"   • {category}: {len(learnings)} learnings")

# Show severity distribution
severity = enhanced_db['enhanced_learnings']['severity_scoring']
critical_count = len(severity['critical_learnings'])
important_count = len(severity['important_learnings'])
minor_count = len(severity['minor_learnings'])

if critical_count > 0:
    print(f"🚨 Critical learnings: {critical_count}")
if important_count > 0:
    print(f"⚠️  Important learnings: {important_count}")
if minor_count > 0:
    print(f"ℹ️  Minor learnings: {minor_count}")

EOF
}

# Integration with memory system for automatic context
integrate_with_memory_system() {
    echo -e "${GREEN}🔗 Integrating with Memory System...${NC}"
    log_enhanced "INFO" "Starting memory system integration"
    
    # Create context export for memory system
    export CONTEXT_DB="$CONTEXT_DB"
    export PATTERNS_DB="$PATTERNS_DB"
    export LEARNINGS_DB="$LEARNINGS_DB"
    export INTELLIGENCE_DIR="$INTELLIGENCE_DIR"
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

def generate_memory_context():
    """Generate context for Claude memory system"""
    
    # Load enhanced databases
    context_file = os.environ.get('CONTEXT_DB')
    patterns_file = os.environ.get('PATTERNS_DB')
    learnings_file = os.environ.get('LEARNINGS_DB')
    
    try:
        with open(context_file, 'r') as f:
            context_db = json.load(f)
    except:
        context_db = {}
    
    try:
        with open(patterns_file, 'r') as f:
            patterns_db = json.load(f)
    except:
        patterns_db = {}
    
    try:
        with open(learnings_file, 'r') as f:
            learnings_db = json.load(f)
    except:
        learnings_db = {}
    
    # Extract key insights for Claude memory
    memory_context = {
        'user_intelligence_profile': {
            'version': '2.0',
            'generated_at': datetime.now().isoformat() + 'Z',
            'confidence_level': 'high',
            'key_insights': {}
        }
    }
    
    # Extract user-specific insights
    user_insights = context_db.get('context_enhancement', {}).get('user_specific_insights', {})
    
    # Coding style insights
    coding_style = user_insights.get('coding_style', {})
    if coding_style:
        memory_context['user_intelligence_profile']['key_insights']['coding_preferences'] = {
            'primary_languages': coding_style.get('primary_languages', []),
            'focus_areas': {
                'python': coding_style.get('python_focus', False),
                'automation': coding_style.get('automation_focus', False),
                'documentation': coding_style.get('documentation_conscious', False)
            },
            'optimal_working_hours': coding_style.get('optimal_hours', [])
        }
    
    # Expertise areas
    expertise = user_insights.get('expertise_areas', {})
    if expertise:
        memory_context['user_intelligence_profile']['key_insights']['expertise_levels'] = {}
        for area, data in expertise.items():
            memory_context['user_intelligence_profile']['key_insights']['expertise_levels'][area] = {
                'confidence': data.get('confidence', 'medium'),
                'frequency': data.get('frequency', 0),
                'impact': data.get('avg_impact', 0)
            }
    
    # Common mistakes to avoid
    mistakes = user_insights.get('common_mistakes', {})
    if mistakes:
        memory_context['user_intelligence_profile']['key_insights']['error_patterns'] = {}
        for mistake_type, data in mistakes.items():
            memory_context['user_intelligence_profile']['key_insights']['error_patterns'][mistake_type] = {
                'description': data.get('description', ''),
                'prevention': data.get('suggestion', ''),
                'frequency': data.get('frequency', 0)
            }
    
    # Preferred solutions
    solutions = user_insights.get('preferred_solutions', {})
    if solutions:
        memory_context['user_intelligence_profile']['key_insights']['solution_preferences'] = {}
        for solution_type, data in solutions.items():
            memory_context['user_intelligence_profile']['key_insights']['solution_preferences'][solution_type] = {
                'preferred_method': data.get('preferred_method', ''),
                'success_rate': data.get('frequency', 0),
                'context': data.get('description', '')
            }
    
    # Learning patterns from enhanced system
    learning_stats = learnings_db.get('learning_stats', {})
    if learning_stats:
        memory_context['user_intelligence_profile']['key_insights']['learning_patterns'] = {
            'total_learnings': learning_stats.get('total_learnings', 0),
            'success_rate': learning_stats.get('success_rate', 0.0),
            'improvement_velocity': learning_stats.get('improvement_velocity', 0.0),
            'learning_effectiveness': 'high' if learning_stats.get('success_rate', 0) > 0.7 else 'medium'
        }
    
    # Claude optimizations
    claude_opts = context_db.get('context_enhancement', {}).get('claude_optimizations', {})
    if claude_opts:
        memory_context['user_intelligence_profile']['claude_optimizations'] = {
            'suggested_prompts': claude_opts.get('suggested_prompts', []),
            'context_priorities': claude_opts.get('context_priorities', []),
            'error_prevention_strategies': claude_opts.get('error_prevention', []),
            'success_amplification': claude_opts.get('success_amplification', [])
        }
    
    # Session context
    session_context = context_db.get('context_enhancement', {}).get('session_context', {})
    if session_context:
        memory_context['current_session'] = {
            'focus': session_context.get('current_focus', ''),
            'recent_decisions': session_context.get('recent_decisions', []),
            'suggested_actions': session_context.get('suggested_actions', []),
            'active_learnings': session_context.get('active_learnings', [])
        }
    
    # Pattern confidence scores
    pattern_stats = patterns_db.get('pattern_stats', {})
    if pattern_stats:
        confidence_scores = pattern_stats.get('confidence_scores', {})
        memory_context['user_intelligence_profile']['confidence_metrics'] = {
            'overall_confidence': sum(confidence_scores.values()) / len(confidence_scores) if confidence_scores else 0.0,
            'pattern_confidence': confidence_scores,
            'data_quality': 'high' if pattern_stats.get('total_commits_analyzed', 0) > 50 else 'medium'
        }
    
    return memory_context

# Generate and save memory context
memory_context = generate_memory_context()

# Save to memory system location
intelligence_dir = os.environ.get('INTELLIGENCE_DIR')
memory_export_file = os.path.join(intelligence_dir, 'claude-memory-context.json')

with open(memory_export_file, 'w') as f:
    json.dump(memory_context, f, indent=2)

print("✅ Memory system integration completed!")
print(f"📤 Exported enhanced context for Claude memory system")

# Show integration summary
profile = memory_context.get('user_intelligence_profile', {})
insights = profile.get('key_insights', {})

print(f"🧠 Intelligence Profile Generated:")
if 'coding_preferences' in insights:
    langs = insights['coding_preferences'].get('primary_languages', [])
    if langs:
        print(f"   • Primary Languages: {', '.join(langs[:3])}")

if 'expertise_levels' in insights:
    high_expertise = [area for area, data in insights['expertise_levels'].items() 
                     if data['confidence'] == 'high']
    if high_expertise:
        print(f"   • High Expertise: {', '.join(high_expertise)}")

if 'learning_patterns' in insights:
    success_rate = insights['learning_patterns'].get('success_rate', 0)
    print(f"   • Learning Success Rate: {success_rate:.2f}")

confidence = profile.get('confidence_metrics', {}).get('overall_confidence', 0)
print(f"   • Overall Confidence: {confidence:.2f}")

EOF
}

# Background daemon mode for continuous learning
start_daemon_mode() {
    echo -e "${YELLOW}🔄 Starting Enhanced Intelligence Daemon...${NC}"
    log_enhanced "INFO" "Starting daemon mode for continuous learning"
    
    # Create daemon control file
    local daemon_control="$ENHANCED_DIR/daemon-control.json"
    cat > "$daemon_control" << EOF
{
  "daemon_active": true,
  "start_time": "$(date -Iseconds)",
  "pid": $$,
  "mode": "continuous_learning",
  "interval_minutes": 30,
  "last_run": "",
  "run_count": 0
}
EOF
    
    echo "🚀 Enhanced Intelligence Daemon started (PID: $$)"
    echo "📊 Running continuous pattern analysis every 30 minutes"
    echo "📝 Use 'claude-intelligence-enhanced daemon stop' to stop"
    
    # Background daemon loop
    while [[ -f "$daemon_control" ]]; do
        local control_data=$(cat "$daemon_control")
        local daemon_active=$(echo "$control_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('daemon_active', False))")
        
        if [[ "$daemon_active" != "True" ]]; then
            echo "🛑 Daemon stop requested"
            break
        fi
        
        # Run intelligence extraction
        log_enhanced "INFO" "Daemon cycle: running intelligence extraction"
        
        # Incremental analysis (last 30 minutes)
        analyze_git_commit_patterns > /dev/null 2>&1
        generate_claude_context > /dev/null 2>&1
        enhance_learning_system > /dev/null 2>&1
        integrate_with_memory_system > /dev/null 2>&1
        
        # Update daemon control
        local run_count=$(echo "$control_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('run_count', 0) + 1)")
        cat > "$daemon_control" << EOF
{
  "daemon_active": true,
  "start_time": "$(echo "$control_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('start_time', ''))")",
  "pid": $$,
  "mode": "continuous_learning",
  "interval_minutes": 30,
  "last_run": "$(date -Iseconds)",
  "run_count": $run_count
}
EOF
        
        log_enhanced "SUCCESS" "Daemon cycle completed (run #$run_count)"
        
        # Sleep for 30 minutes
        sleep 1800
    done
    
    # Cleanup
    rm -f "$daemon_control"
    log_enhanced "INFO" "Enhanced intelligence daemon stopped"
}

# Stop daemon
stop_daemon() {
    local daemon_control="$ENHANCED_DIR/daemon-control.json"
    
    if [[ -f "$daemon_control" ]]; then
        # Mark daemon for stop
        local control_data=$(cat "$daemon_control")
        echo "$control_data" | python3 -c "
import sys, json
data = json.load(sys.stdin)
data['daemon_active'] = False
print(json.dumps(data, indent=2))
        " > "$daemon_control"
        
        echo "🛑 Enhanced Intelligence Daemon stop signal sent"
        log_enhanced "INFO" "Daemon stop requested"
    else
        echo "⚠️  No active daemon found"
    fi
}

# Export insights for Claude context
export_claude_insights() {
    echo -e "${PURPLE}📤 Exporting Claude Insights...${NC}"
    
    # Export variables
    export CONTEXT_DB="$CONTEXT_DB"
    export PATTERNS_DB="$PATTERNS_DB"
    export LEARNINGS_DB="$LEARNINGS_DB"
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

def load_db(db_path):
    try:
        with open(db_path, 'r') as f:
            return json.load(f)
    except:
        return {}

# Load all databases
context_db = load_db(os.environ.get('CONTEXT_DB'))
patterns_db = load_db(os.environ.get('PATTERNS_DB'))
learnings_db = load_db(os.environ.get('LEARNINGS_DB'))

# Generate comprehensive Claude context
claude_context = {
    "claude_workspace_intelligence": {
        "version": "2.0",
        "generated_at": datetime.now().isoformat() + "Z",
        "user_profile": {
            "working_style": {},
            "technical_expertise": {},
            "problem_solving_approach": {},
            "learning_preferences": {}
        },
        "current_session": {
            "focus_areas": [],
            "recent_activities": [],
            "suggested_optimizations": []
        },
        "intelligence_insights": {
            "pattern_recognition": {},
            "predictive_suggestions": [],
            "error_prevention": [],
            "success_amplification": []
        }
    }
}

# Extract user profile from patterns
git_patterns = patterns_db.get('pattern_recognition', {}).get('git_patterns', {})

# Working style
work_patterns = git_patterns.get('commit_frequency', {})
if work_patterns:
    claude_context["claude_workspace_intelligence"]["user_profile"]["working_style"] = {
        "peak_productivity_hours": work_patterns.get('peak_hours', []),
        "preferred_work_days": work_patterns.get('peak_days', []),
        "average_commits_per_session": work_patterns.get('average_commits_per_day', 0),
        "consistency_score": "high" if work_patterns.get('total_active_days', 0) > 20 else "medium"
    }

# Technical expertise
decision_patterns = git_patterns.get('decision_patterns', {})
if decision_patterns:
    expertise = {}
    for category, data in decision_patterns.items():
        if data.get('frequency', 0) > 3:
            expertise[category] = {
                "proficiency": "high" if data['frequency'] > 10 else "medium",
                "activity_level": data['frequency'],
                "impact_score": data.get('avg_impact', 0)
            }
    
    claude_context["claude_workspace_intelligence"]["user_profile"]["technical_expertise"] = expertise

# Problem solving approach
error_patterns = git_patterns.get('error_resolution_patterns', {})
if error_patterns:
    claude_context["claude_workspace_intelligence"]["user_profile"]["problem_solving_approach"] = {
        "error_resolution_style": error_patterns.get('preferred_approaches', {}),
        "fix_effectiveness": "high" if error_patterns.get('fix_frequency', 0) < 0.3 else "needs_improvement",
        "typical_fix_scope": error_patterns.get('avg_files_per_fix', 0),
        "debugging_thoroughness": "thorough" if error_patterns.get('avg_lines_per_fix', 0) > 20 else "minimal"
    }

# Current session context
session_context = context_db.get('context_enhancement', {}).get('session_context', {})
if session_context:
    claude_context["claude_workspace_intelligence"]["current_session"] = {
        "focus_areas": [session_context.get('current_focus', '')],
        "recent_activities": [d['title'] for d in session_context.get('recent_decisions', [])],
        "suggested_optimizations": [a['action'] for a in session_context.get('suggested_actions', [])]
    }

# Intelligence insights
claude_opts = context_db.get('context_enhancement', {}).get('claude_optimizations', {})
if claude_opts:
    claude_context["claude_workspace_intelligence"]["intelligence_insights"] = {
        "pattern_recognition": {
            "identified_patterns": len(patterns_db.get('pattern_recognition', {})),
            "confidence_level": patterns_db.get('pattern_stats', {}).get('confidence_scores', {})
        },
        "predictive_suggestions": claude_opts.get('suggested_prompts', []),
        "error_prevention": [ep.get('prevention', '') for ep in claude_opts.get('error_prevention', [])],
        "success_amplification": [sa.get('approach', '') for sa in claude_opts.get('success_amplification', [])]
    }

# Learning system insights
learning_stats = learnings_db.get('learning_stats', {})
if learning_stats:
    claude_context["claude_workspace_intelligence"]["user_profile"]["learning_preferences"] = {
        "learning_velocity": learning_stats.get('improvement_velocity', 0),
        "success_rate": learning_stats.get('success_rate', 0),
        "total_learnings": learning_stats.get('total_learnings', 0),
        "learning_effectiveness": "high" if learning_stats.get('success_rate', 0) > 0.7 else "medium"
    }

# Output formatted context for Claude
print("=" * 80)
print("CLAUDE WORKSPACE INTELLIGENCE CONTEXT")
print("=" * 80)
print()
print("## User Profile Summary")

profile = claude_context["claude_workspace_intelligence"]["user_profile"]

# Working style
working_style = profile.get("working_style", {})
if working_style:
    peak_hours = working_style.get("peak_productivity_hours", [])
    if peak_hours:
        print(f"🕐 Peak productivity hours: {', '.join(map(str, peak_hours))}")
    
    consistency = working_style.get("consistency_score", "medium")
    print(f"📊 Work consistency: {consistency}")

# Technical expertise
expertise = profile.get("technical_expertise", {})
if expertise:
    print(f"\n🎯 Technical Expertise Areas:")
    for area, data in expertise.items():
        proficiency = data.get("proficiency", "medium")
        activity = data.get("activity_level", 0)
        print(f"   • {area}: {proficiency} proficiency ({activity} commits)")

# Problem solving
problem_solving = profile.get("problem_solving_approach", {})
if problem_solving:
    print(f"\n🔧 Problem Solving Style:")
    effectiveness = problem_solving.get("fix_effectiveness", "medium")
    print(f"   • Error resolution effectiveness: {effectiveness}")
    
    approaches = problem_solving.get("error_resolution_style", {})
    if approaches:
        top_approach = max(approaches.items(), key=lambda x: x[1]) if approaches else None
        if top_approach:
            print(f"   • Preferred approach: {top_approach[0]}")

# Learning preferences
learning = profile.get("learning_preferences", {})
if learning:
    print(f"\n📚 Learning Profile:")
    velocity = learning.get("learning_velocity", 0)
    success_rate = learning.get("success_rate", 0)
    print(f"   • Learning velocity: {velocity:.1f} learnings/week")
    print(f"   • Success rate: {success_rate:.2f}")

# Current session
current_session = claude_context["claude_workspace_intelligence"]["current_session"]
focus_areas = current_session.get("focus_areas", [])
if focus_areas and focus_areas[0]:
    print(f"\n🎯 Current Focus: {', '.join(focus_areas)}")

recent_activities = current_session.get("recent_activities", [])
if recent_activities:
    print(f"\n📋 Recent Activities:")
    for activity in recent_activities[:3]:
        print(f"   • {activity}")

suggestions = current_session.get("suggested_optimizations", [])
if suggestions:
    print(f"\n💡 Suggested Optimizations:")
    for suggestion in suggestions[:3]:
        print(f"   • {suggestion}")

# Intelligence insights
insights = claude_context["claude_workspace_intelligence"]["intelligence_insights"]
pattern_recognition = insights.get("pattern_recognition", {})
if pattern_recognition:
    pattern_count = pattern_recognition.get("identified_patterns", 0)
    print(f"\n🧠 Intelligence Status:")
    print(f"   • Identified patterns: {pattern_count}")
    
    confidence = pattern_recognition.get("confidence_level", {})
    if confidence:
        avg_confidence = sum(confidence.values()) / len(confidence) if confidence else 0
        print(f"   • Pattern confidence: {avg_confidence:.2f}")

error_prevention = insights.get("error_prevention", [])
if error_prevention:
    print(f"\n🛡️  Error Prevention Strategies:")
    for strategy in error_prevention[:3]:
        if strategy:
            print(f"   • {strategy}")

print("\n" + "=" * 80)
print("Use this context to optimize Claude interactions for this user")
print("=" * 80)

EOF
}

# Show comprehensive summary
show_enhanced_summary() {
    echo -e "${BOLD}${PURPLE}🧠 CLAUDE WORKSPACE ENHANCED INTELLIGENCE${NC}"
    echo -e "${PURPLE}============================================${NC}"
    echo ""
    
    # Export variables
    export PATTERNS_DB="$PATTERNS_DB"
    export CONTEXT_DB="$CONTEXT_DB"
    export LEARNINGS_DB="$LEARNINGS_DB"
    export ENHANCED_DIR="$ENHANCED_DIR"
    
    python3 << 'EOF'
import json
import os
from datetime import datetime

def load_db(db_path):
    try:
        with open(db_path, 'r') as f:
            return json.load(f)
    except:
        return {}

def format_timestamp(timestamp_str):
    try:
        dt = datetime.fromisoformat(timestamp_str.replace('Z', '+00:00'))
        return dt.strftime('%Y-%m-%d %H:%M')
    except:
        return timestamp_str

# Load databases
patterns_db = load_db(os.environ.get('PATTERNS_DB'))
context_db = load_db(os.environ.get('CONTEXT_DB'))
learnings_db = load_db(os.environ.get('LEARNINGS_DB'))

print("📊 PATTERN RECOGNITION ENGINE")
print("-" * 40)

pattern_stats = patterns_db.get('pattern_stats', {})
if pattern_stats:
    total_patterns = pattern_stats.get('total_patterns', 0)
    last_update = pattern_stats.get('last_update', '')
    print(f"Total Patterns Identified: {total_patterns}")
    print(f"Last Analysis: {format_timestamp(last_update)}")
    
    confidence_scores = pattern_stats.get('confidence_scores', {})
    if confidence_scores:
        print("Pattern Confidence Scores:")
        for pattern_type, score in confidence_scores.items():
            print(f"  • {pattern_type}: {score:.2f}")
    
    commits_analyzed = pattern_stats.get('total_commits_analyzed', 0)
    if commits_analyzed:
        print(f"Git Commits Analyzed: {commits_analyzed}")

print()
print("🤖 CLAUDE CONTEXT ENHANCEMENT")
print("-" * 40)

context_stats = context_db.get('context_stats', {})
if context_stats:
    total_insights = context_stats.get('total_insights', 0)
    accuracy_score = context_stats.get('accuracy_score', 0)
    last_update = context_stats.get('last_update', '')
    
    print(f"User-Specific Insights: {total_insights}")
    print(f"Context Accuracy Score: {accuracy_score:.2f}")
    print(f"Last Update: {format_timestamp(last_update)}")

# Show key insights
user_insights = context_db.get('context_enhancement', {}).get('user_specific_insights', {})
if user_insights:
    print()
    print("🎯 KEY USER INSIGHTS")
    print("-" * 40)
    
    # Expertise areas
    expertise = user_insights.get('expertise_areas', {})
    if expertise:
        high_expertise = [area for area, data in expertise.items() if data.get('confidence') == 'high']
        medium_expertise = [area for area, data in expertise.items() if data.get('confidence') == 'medium']
        
        if high_expertise:
            print(f"High Expertise: {', '.join(high_expertise)}")
        if medium_expertise:
            print(f"Medium Expertise: {', '.join(medium_expertise)}")
    
    # Coding style
    coding_style = user_insights.get('coding_style', {})
    if coding_style:
        primary_langs = coding_style.get('primary_languages', [])
        if primary_langs:
            print(f"Primary Languages: {', '.join(primary_langs)}")
        
        focus_areas = []
        if coding_style.get('python_focus'):
            focus_areas.append('Python')
        if coding_style.get('automation_focus'):
            focus_areas.append('Automation')
        if coding_style.get('documentation_conscious'):
            focus_areas.append('Documentation')
        
        if focus_areas:
            print(f"Focus Areas: {', '.join(focus_areas)}")

print()
print("📚 ENHANCED LEARNING SYSTEM")
print("-" * 40)

learning_stats = learnings_db.get('learning_stats', {})
if learning_stats:
    total_learnings = learning_stats.get('total_learnings', 0)
    success_rate = learning_stats.get('success_rate', 0)
    improvement_velocity = learning_stats.get('improvement_velocity', 0)
    last_update = learning_stats.get('last_update', '')
    
    print(f"Total Learnings: {total_learnings}")
    print(f"Success Rate: {success_rate:.2f}")
    print(f"Improvement Velocity: {improvement_velocity:.1f} learnings/week")
    print(f"Last Update: {format_timestamp(last_update)}")

# Show severity distribution
severity_scoring = learnings_db.get('enhanced_learnings', {}).get('severity_scoring', {})
if severity_scoring:
    critical_count = len(severity_scoring.get('critical_learnings', []))
    important_count = len(severity_scoring.get('important_learnings', []))
    minor_count = len(severity_scoring.get('minor_learnings', []))
    
    if critical_count + important_count + minor_count > 0:
        print("Learning Severity Distribution:")
        if critical_count > 0:
            print(f"  🚨 Critical: {critical_count}")
        if important_count > 0:
            print(f"  ⚠️  Important: {important_count}")
        if minor_count > 0:
            print(f"  ℹ️  Minor: {minor_count}")

print()
print("🔄 SYSTEM STATUS")
print("-" * 40)

# Check daemon status
daemon_control = os.path.join(os.environ.get('ENHANCED_DIR'), 'daemon-control.json')
if os.path.exists(daemon_control):
    try:
        with open(daemon_control, 'r') as f:
            daemon_data = json.load(f)
        
        if daemon_data.get('daemon_active', False):
            start_time = daemon_data.get('start_time', '')
            run_count = daemon_data.get('run_count', 0)
            last_run = daemon_data.get('last_run', '')
            
            print(f"Daemon Status: 🟢 ACTIVE")
            print(f"Started: {format_timestamp(start_time)}")
            print(f"Cycles Completed: {run_count}")
            if last_run:
                print(f"Last Run: {format_timestamp(last_run)}")
        else:
            print(f"Daemon Status: 🔴 STOPPING")
    except:
        print(f"Daemon Status: ❓ UNKNOWN")
else:
    print(f"Daemon Status: ⚫ INACTIVE")

# Show database sizes
print()
print("💾 DATABASE STATUS")
print("-" * 40)

enhanced_dir = os.environ.get('ENHANCED_DIR')
for db_name in ['patterns.json', 'context.json', 'learnings.json', 'user-profile.json']:
    db_path = os.path.join(enhanced_dir, db_name)
    if os.path.exists(db_path):
        size = os.path.getsize(db_path)
        print(f"{db_name}: {size:,} bytes")

print()
print("🎯 CLAUDE OPTIMIZATION READY")
print("-" * 40)

claude_opts = context_db.get('context_enhancement', {}).get('claude_optimizations', {})
if claude_opts:
    prompt_count = len(claude_opts.get('suggested_prompts', []))
    priority_count = len(claude_opts.get('context_priorities', []))
    prevention_count = len(claude_opts.get('error_prevention', []))
    amplification_count = len(claude_opts.get('success_amplification', []))
    
    print(f"Suggested Prompts: {prompt_count}")
    print(f"Context Priorities: {priority_count}")
    print(f"Error Prevention Strategies: {prevention_count}")
    print(f"Success Amplification Methods: {amplification_count}")
    
    if prompt_count + priority_count + prevention_count + amplification_count > 0:
        print()
        print("✅ Claude context optimizations are ready!")
        print("💡 Use 'claude-intelligence-enhanced export' to see full context")

EOF
}

# Help function
show_help() {
    echo -e "${BOLD}Claude Intelligence Enhanced - Pattern Recognition Engine${NC}"
    echo ""
    echo "Usage: claude-intelligence-enhanced [command] [options]"
    echo ""
    echo "${BOLD}Core Commands:${NC}"
    echo "  ${GREEN}init${NC}                Initialize enhanced intelligence system"
    echo "  ${GREEN}analyze${NC}             Run full pattern analysis and context generation"
    echo "  ${GREEN}patterns${NC}            Analyze git commit patterns only"
    echo "  ${GREEN}context${NC}             Generate Claude context enhancement only"
    echo "  ${GREEN}learning${NC}            Enhance learning system only"
    echo "  ${GREEN}integrate${NC}           Integrate with memory system"
    echo "  ${GREEN}export${NC}              Export Claude insights"
    echo "  ${GREEN}summary${NC}             Show comprehensive intelligence summary"
    echo ""
    echo "${BOLD}Daemon Mode:${NC}"
    echo "  ${YELLOW}daemon start${NC}        Start continuous learning daemon"
    echo "  ${YELLOW}daemon stop${NC}         Stop continuous learning daemon"
    echo "  ${YELLOW}daemon status${NC}       Show daemon status"
    echo ""
    echo "${BOLD}Examples:${NC}"
    echo "  claude-intelligence-enhanced init"
    echo "  claude-intelligence-enhanced analyze"
    echo "  claude-intelligence-enhanced daemon start"
    echo "  claude-intelligence-enhanced export"
    echo ""
    echo "${BOLD}Features:${NC}"
    echo "  🔍 Advanced pattern recognition from git history"
    echo "  🤖 Claude-specific context enhancement"
    echo "  📚 Categorized learning system with severity scoring"
    echo "  🎯 User-specific insights and expertise mapping"
    echo "  🔄 Continuous learning daemon mode"
    echo "  🔗 Memory system integration"
    echo "  📊 Cross-project pattern analysis"
    echo ""
    echo "${BOLD}Intelligence Databases:${NC}"
    echo "  📁 patterns.json      - Git and behavioral patterns"
    echo "  📁 context.json       - Claude context enhancements"
    echo "  📁 learnings.json     - Enhanced learning system"
    echo "  📁 user-profile.json  - User behavior profile"
    echo "  📁 cross-project.json - Cross-project insights"
}

# Main command dispatcher
case "${1:-}" in
    "init")
        echo -e "${BOLD}${BLUE}🚀 Initializing Enhanced Intelligence System...${NC}"
        initialize_enhanced_databases
        echo -e "${GREEN}✅ Enhanced Intelligence System initialized!${NC}"
        ;;
    "analyze")
        echo -e "${BOLD}${BLUE}🔍 Running Full Enhanced Analysis...${NC}"
        initialize_enhanced_databases
        echo ""
        analyze_git_commit_patterns
        echo ""
        generate_claude_context
        echo ""
        enhance_learning_system
        echo ""
        integrate_with_memory_system
        echo ""
        echo -e "${GREEN}🎉 Enhanced intelligence analysis completed!${NC}"
        echo -e "${CYAN}💡 Use 'claude-intelligence-enhanced summary' to see results${NC}"
        ;;
    "patterns")
        initialize_enhanced_databases
        analyze_git_commit_patterns
        ;;
    "context")
        initialize_enhanced_databases
        generate_claude_context
        ;;
    "learning")
        initialize_enhanced_databases
        enhance_learning_system
        ;;
    "integrate")
        integrate_with_memory_system
        ;;
    "export")
        export_claude_insights
        ;;
    "summary")
        show_enhanced_summary
        ;;
    "daemon")
        case "${2:-}" in
            "start")
                initialize_enhanced_databases
                start_daemon_mode
                ;;
            "stop")
                stop_daemon
                ;;
            "status")
                if [[ -f "$ENHANCED_DIR/daemon-control.json" ]]; then
                    echo -e "${GREEN}🟢 Enhanced Intelligence Daemon is running${NC}"
                    cat "$ENHANCED_DIR/daemon-control.json" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(f'Started: {data.get(\"start_time\", \"unknown\")}')
print(f'PID: {data.get(\"pid\", \"unknown\")}')
print(f'Cycles: {data.get(\"run_count\", 0)}')
print(f'Last Run: {data.get(\"last_run\", \"never\")}')
                    "
                else
                    echo -e "${RED}🔴 Enhanced Intelligence Daemon is not running${NC}"
                fi
                ;;
            *)
                echo -e "${RED}❌ Unknown daemon command: ${2:-}${NC}"
                echo "Usage: claude-intelligence-enhanced daemon [start|stop|status]"
                exit 1
                ;;
        esac
        ;;
    "help"|"--help"|"-h")
        show_help
        ;;
    "")
        show_enhanced_summary
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac