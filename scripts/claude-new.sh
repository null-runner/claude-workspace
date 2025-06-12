#!/bin/bash
# claude-new.sh - Crea nuovo progetto con template

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
TEMPLATES_DIR="${WORKSPACE_DIR}/templates"
PROJECTS_DIR="${WORKSPACE_DIR}/projects"
LOG_FILE="${WORKSPACE_DIR}/logs/project-creation.log"

# Crea directory se non esistono
mkdir -p "$TEMPLATES_DIR" "$PROJECTS_DIR"/{active,sandbox,production} "$(dirname "$LOG_FILE")"

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

# Mostra banner
show_banner() {
    echo -e "${BLUE}${BOLD}"
    cat << 'EOF'
   _____ _                 _        _   _               
  / ____| |               | |      | \ | |              
 | |    | | __ _ _   _  __| | ___  |  \| | _____      __
 | |    | |/ _` | | | |/ _` |/ _ \ | . ` |/ _ \ \ /\ / /
 | |____| | (_| | |_| | (_| |  __/ | |\  |  __/\ V  V / 
  \_____|_|\__,_|\__,_|\__,_|\___| |_| \_|\___| \_/\_/  
                                                         
EOF
    echo -e "${NC}"
    echo -e "${CYAN}Create New Claude Project with Templates${NC}"
    echo
}

# Funzione per generare nome progetto univoco
generate_project_name() {
    local base_name="$1"
    local project_type="$2"
    local timestamp=$(date +%Y%m%d-%H%M%S)
    
    if [[ -z "$base_name" ]]; then
        case "$project_type" in
            "sandbox")
                echo "sandbox-${timestamp}"
                ;;
            "active")
                echo "project-${timestamp}"
                ;;
            "production")
                echo "prod-${timestamp}"
                ;;
            *)
                echo "project-${timestamp}"
                ;;
        esac
    else
        # Sanitizza il nome del progetto
        local clean_name=$(echo "$base_name" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
        
        # Aggiungi prefisso in base al tipo
        case "$project_type" in
            "sandbox")
                echo "sandbox-${clean_name}"
                ;;
            "production")
                echo "prod-${clean_name}"
                ;;
            *)
                echo "${clean_name}"
                ;;
        esac
    fi
}

# Lista template disponibili
list_templates() {
    info "Template disponibili:"
    echo
    
    local template_count=0
    
    # Template built-in
    echo -e "${BLUE}Built-in Templates:${NC}"
    echo "  • ${GREEN}python-basic${NC}     - Progetto Python base con venv e requirements"
    echo "  • ${GREEN}nodejs-api${NC}       - API REST con Node.js ed Express"
    echo "  • ${GREEN}react-app${NC}        - Applicazione React con Vite"
    echo "  • ${GREEN}empty${NC}            - Progetto vuoto con struttura minima"
    template_count=4
    
    # Template custom
    if [[ -d "$TEMPLATES_DIR" ]]; then
        local custom_templates=$(find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
        if [[ $custom_templates -gt 0 ]]; then
            echo
            echo -e "${BLUE}Custom Templates:${NC}"
            while IFS= read -r template_dir; do
                local template_name=$(basename "$template_dir")
                local description="Custom template"
                
                # Leggi descrizione se esiste
                if [[ -f "$template_dir/.template-info" ]]; then
                    description=$(head -n1 "$template_dir/.template-info" 2>/dev/null || echo "Custom template")
                fi
                
                echo "  • ${GREEN}${template_name}${NC} - ${description}"
                template_count=$((template_count + 1))
            done < <(find "$TEMPLATES_DIR" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)
        fi
    fi
    
    echo
    info "Totale template disponibili: ${template_count}"
}

# Crea struttura base del progetto
create_base_structure() {
    local project_path="$1"
    
    mkdir -p "$project_path"/{src,tests,docs,.claude}
    
    # .gitignore base
    cat > "$project_path/.gitignore" << 'EOF'
# Claude workspace
.claude/cache/
.claude/logs/
*.tmp

# OS files
.DS_Store
Thumbs.db

# Editor files
.vscode/
.idea/
*.swp
*~

# Environment
.env
.env.local
EOF
    
    # File di metadata Claude
    cat > "$project_path/.claude/project.json" << EOF
{
    "name": "$(basename "$project_path")",
    "created": "$(date -Iseconds)",
    "created_by": "$(whoami)@$(hostname)",
    "template": "${TEMPLATE:-none}",
    "type": "${PROJECT_TYPE}",
    "version": "1.0.0",
    "status": "active"
}
EOF
    
    # README base
    cat > "$project_path/README.md" << EOF
# $(basename "$project_path")

Created: $(date)
Template: ${TEMPLATE:-none}
Type: ${PROJECT_TYPE}

## Description

[Project description here]

## Setup

[Setup instructions here]

## Usage

[Usage instructions here]

---
*Generated by Claude Workspace*
EOF
}

# Applica template Python
apply_python_template() {
    local project_path="$1"
    
    info "Applicando template Python..."
    
    # Struttura Python
    mkdir -p "$project_path"/{src,tests,scripts,data}
    
    # requirements.txt
    cat > "$project_path/requirements.txt" << 'EOF'
# Core dependencies
python-dotenv>=1.0.0
requests>=2.31.0

# Development dependencies
pytest>=7.4.0
black>=23.0.0
flake8>=6.0.0
mypy>=1.0.0

# Data processing (optional)
# pandas>=2.0.0
# numpy>=1.24.0

# Web framework (optional)
# flask>=3.0.0
# fastapi>=0.100.0
# uvicorn>=0.23.0
EOF
    
    # setup.py
    cat > "$project_path/setup.py" << EOF
from setuptools import setup, find_packages

setup(
    name="$(basename "$project_path")",
    version="0.1.0",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    python_requires=">=3.8",
    install_requires=[
        line.strip()
        for line in open("requirements.txt")
        if line.strip() and not line.startswith("#")
    ],
)
EOF
    
    # Main Python file
    cat > "$project_path/src/__init__.py" << 'EOF'
"""Main package for the project."""

__version__ = "0.1.0"
EOF
    
    cat > "$project_path/src/main.py" << 'EOF'
#!/usr/bin/env python3
"""Main entry point for the application."""

import logging
import os
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


def main():
    """Main function."""
    logger.info("Starting application...")
    
    # Your code here
    print("Hello from Claude Project!")
    
    logger.info("Application finished.")


if __name__ == "__main__":
    main()
EOF
    
    # Test file
    mkdir -p "$project_path/tests"
    cat > "$project_path/tests/test_main.py" << 'EOF'
"""Tests for main module."""

import pytest
from src.main import main


def test_main():
    """Test main function."""
    # Basic test to ensure main runs without error
    main()
    assert True  # Add actual tests here
EOF
    
    # Makefile
    cat > "$project_path/Makefile" << 'EOF'
.PHONY: help install test lint format clean

help:
	@echo "Available commands:"
	@echo "  make install  - Install dependencies"
	@echo "  make test     - Run tests"
	@echo "  make lint     - Run linters"
	@echo "  make format   - Format code"
	@echo "  make clean    - Clean cache files"

install:
	python -m pip install --upgrade pip
	pip install -r requirements.txt
	pip install -e .

test:
	pytest tests/ -v

lint:
	flake8 src/ tests/
	mypy src/

format:
	black src/ tests/

clean:
	find . -type d -name "__pycache__" -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	rm -rf .pytest_cache/
	rm -rf .mypy_cache/
EOF
    
    # .env.example
    cat > "$project_path/.env.example" << 'EOF'
# Environment variables
DEBUG=true
LOG_LEVEL=INFO

# API Keys (if needed)
# API_KEY=your-api-key-here

# Database (if needed)
# DATABASE_URL=sqlite:///data/app.db
EOF
    
    # Update .gitignore for Python
    cat >> "$project_path/.gitignore" << 'EOF'

# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
env/
venv/
ENV/
.venv
pip-log.txt
pip-delete-this-directory.txt
.pytest_cache/
.mypy_cache/
*.egg-info/
dist/
build/
EOF
    
    chmod +x "$project_path/src/main.py"
    
    log "Template Python applicato con successo"
}

# Applica template Node.js API
apply_nodejs_template() {
    local project_path="$1"
    
    info "Applicando template Node.js API..."
    
    # Struttura Node.js
    mkdir -p "$project_path"/{src/{routes,controllers,models,middleware,utils},tests,config}
    
    # package.json
    cat > "$project_path/package.json" << EOF
{
  "name": "$(basename "$project_path")",
  "version": "1.0.0",
  "description": "Node.js API created with Claude",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest",
    "lint": "eslint src/",
    "format": "prettier --write src/"
  },
  "keywords": ["api", "nodejs", "express"],
  "author": "Claude Assistant",
  "license": "MIT",
  "dependencies": {
    "express": "^4.18.0",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "morgan": "^1.10.0",
    "dotenv": "^16.0.0",
    "express-rate-limit": "^6.0.0",
    "express-validator": "^7.0.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0",
    "supertest": "^6.3.0",
    "eslint": "^8.0.0",
    "prettier": "^3.0.0"
  },
  "engines": {
    "node": ">=16.0.0"
  }
}
EOF
    
    # Main server file
    cat > "$project_path/src/index.js" << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(helmet());
app.use(cors());
app.use(morgan('dev'));
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100 // limit each IP to 100 requests per windowMs
});
app.use('/api/', limiter);

// Routes
app.get('/', (req, res) => {
  res.json({
    message: 'Welcome to Claude API',
    version: '1.0.0',
    endpoints: {
      health: '/health',
      api: '/api/v1'
    }
  });
});

app.get('/health', (req, res) => {
  res.json({
    status: 'ok',
    timestamp: new Date().toISOString()
  });
});

// API routes
const apiRouter = require('./routes/api');
app.use('/api/v1', apiRouter);

// Error handling middleware
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(err.status || 500).json({
    error: {
      message: err.message || 'Internal Server Error',
      status: err.status || 500
    }
  });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: {
      message: 'Not Found',
      status: 404
    }
  });
});

// Start server
app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
});

module.exports = app;
EOF
    
    # API router
    cat > "$project_path/src/routes/api.js" << 'EOF'
const express = require('express');
const router = express.Router();

// Example controller
const exampleController = require('../controllers/exampleController');

// Example routes
router.get('/examples', exampleController.getAll);
router.get('/examples/:id', exampleController.getById);
router.post('/examples', exampleController.create);
router.put('/examples/:id', exampleController.update);
router.delete('/examples/:id', exampleController.delete);

module.exports = router;
EOF
    
    # Example controller
    cat > "$project_path/src/controllers/exampleController.js" << 'EOF'
// Example controller with basic CRUD operations

const examples = [];

exports.getAll = (req, res) => {
  res.json({
    data: examples,
    count: examples.length
  });
};

exports.getById = (req, res) => {
  const { id } = req.params;
  const example = examples.find(e => e.id === id);
  
  if (!example) {
    return res.status(404).json({
      error: { message: 'Not found' }
    });
  }
  
  res.json({ data: example });
};

exports.create = (req, res) => {
  const newExample = {
    id: Date.now().toString(),
    ...req.body,
    createdAt: new Date()
  };
  
  examples.push(newExample);
  res.status(201).json({ data: newExample });
};

exports.update = (req, res) => {
  const { id } = req.params;
  const index = examples.findIndex(e => e.id === id);
  
  if (index === -1) {
    return res.status(404).json({
      error: { message: 'Not found' }
    });
  }
  
  examples[index] = {
    ...examples[index],
    ...req.body,
    updatedAt: new Date()
  };
  
  res.json({ data: examples[index] });
};

exports.delete = (req, res) => {
  const { id } = req.params;
  const index = examples.findIndex(e => e.id === id);
  
  if (index === -1) {
    return res.status(404).json({
      error: { message: 'Not found' }
    });
  }
  
  examples.splice(index, 1);
  res.status(204).send();
};
EOF
    
    # Test file
    cat > "$project_path/tests/api.test.js" << 'EOF'
const request = require('supertest');
const app = require('../src/index');

describe('API Tests', () => {
  test('GET / should return welcome message', async () => {
    const response = await request(app).get('/');
    expect(response.status).toBe(200);
    expect(response.body).toHaveProperty('message');
  });
  
  test('GET /health should return ok status', async () => {
    const response = await request(app).get('/health');
    expect(response.status).toBe(200);
    expect(response.body.status).toBe('ok');
  });
});
EOF
    
    # .env file
    cat > "$project_path/.env.example" << 'EOF'
# Server configuration
PORT=3000
NODE_ENV=development

# Database (if needed)
# DATABASE_URL=mongodb://localhost:27017/myapp

# API Keys
# API_SECRET=your-secret-key

# External services
# REDIS_URL=redis://localhost:6379
EOF
    
    # ESLint config
    cat > "$project_path/.eslintrc.json" << 'EOF'
{
  "env": {
    "node": true,
    "es2021": true,
    "jest": true
  },
  "extends": "eslint:recommended",
  "parserOptions": {
    "ecmaVersion": 12
  },
  "rules": {
    "indent": ["error", 2],
    "quotes": ["error", "single"],
    "semi": ["error", "always"]
  }
}
EOF
    
    # Update .gitignore for Node.js
    cat >> "$project_path/.gitignore" << 'EOF'

# Node.js
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*
.npm
package-lock.json
yarn.lock
EOF
    
    log "Template Node.js API applicato con successo"
}

# Applica template React
apply_react_template() {
    local project_path="$1"
    
    info "Applicando template React con Vite..."
    
    # Struttura React
    mkdir -p "$project_path"/{src/{components,pages,hooks,utils,styles},public,tests}
    
    # package.json
    cat > "$project_path/package.json" << EOF
{
  "name": "$(basename "$project_path")",
  "private": true,
  "version": "0.0.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "lint": "eslint . --ext js,jsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview",
    "test": "vitest"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "react-router-dom": "^6.0.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "@types/react-dom": "^18.2.0",
    "@vitejs/plugin-react": "^4.0.0",
    "eslint": "^8.0.0",
    "eslint-plugin-react": "^7.32.0",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.0",
    "vite": "^4.4.0",
    "vitest": "^0.34.0"
  }
}
EOF
    
    # Vite config
    cat > "$project_path/vite.config.js" << 'EOF'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    open: true
  },
  build: {
    outDir: 'dist',
    sourcemap: true
  }
})
EOF
    
    # index.html
    cat > "$project_path/index.html" << EOF
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>$(basename "$project_path")</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOF
    
    # Main entry
    cat > "$project_path/src/main.jsx" << 'EOF'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'
import './index.css'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
EOF
    
    # App component
    cat > "$project_path/src/App.jsx" << 'EOF'
import { useState } from 'react'
import './App.css'

function App() {
  const [count, setCount] = useState(0)

  return (
    <>
      <div className="app">
        <header className="app-header">
          <h1>Claude React Project</h1>
          <p>Edit <code>src/App.jsx</code> and save to test HMR</p>
        </header>
        
        <main className="app-main">
          <div className="card">
            <button onClick={() => setCount((count) => count + 1)}>
              count is {count}
            </button>
          </div>
          
          <p className="read-the-docs">
            Click on the Vite and React logos to learn more
          </p>
        </main>
      </div>
    </>
  )
}

export default App
EOF
    
    # Basic CSS
    cat > "$project_path/src/index.css" << 'EOF'
:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;

  color-scheme: light dark;
  color: rgba(255, 255, 255, 0.87);
  background-color: #242424;

  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  -webkit-text-size-adjust: 100%;
}

body {
  margin: 0;
  display: flex;
  place-items: center;
  min-width: 320px;
  min-height: 100vh;
}

h1 {
  font-size: 3.2em;
  line-height: 1.1;
}

button {
  border-radius: 8px;
  border: 1px solid transparent;
  padding: 0.6em 1.2em;
  font-size: 1em;
  font-weight: 500;
  font-family: inherit;
  background-color: #1a1a1a;
  cursor: pointer;
  transition: border-color 0.25s;
}

button:hover {
  border-color: #646cff;
}

button:focus,
button:focus-visible {
  outline: 4px auto -webkit-focus-ring-color;
}

@media (prefers-color-scheme: light) {
  :root {
    color: #213547;
    background-color: #ffffff;
  }
  button {
    background-color: #f9f9f9;
  }
}
EOF
    
    cat > "$project_path/src/App.css" << 'EOF'
#root {
  max-width: 1280px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}

.app {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  min-height: 100vh;
}

.app-header {
  margin-bottom: 2rem;
}

.app-main {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 2rem;
}

.card {
  padding: 2em;
}

.read-the-docs {
  color: #888;
}
EOF
    
    # Example component
    mkdir -p "$project_path/src/components"
    cat > "$project_path/src/components/Example.jsx" << 'EOF'
import React from 'react'

const Example = ({ title, children }) => {
  return (
    <div className="example">
      <h2>{title}</h2>
      <div className="example-content">
        {children}
      </div>
    </div>
  )
}

export default Example
EOF
    
    # ESLint config
    cat > "$project_path/.eslintrc.cjs" << 'EOF'
module.exports = {
  root: true,
  env: { browser: true, es2020: true },
  extends: [
    'eslint:recommended',
    'plugin:react/recommended',
    'plugin:react/jsx-runtime',
    'plugin:react-hooks/recommended',
  ],
  ignorePatterns: ['dist', '.eslintrc.cjs'],
  parserOptions: { ecmaVersion: 'latest', sourceType: 'module' },
  settings: { react: { version: '18.2' } },
  plugins: ['react-refresh'],
  rules: {
    'react-refresh/only-export-components': [
      'warn',
      { allowConstantExport: true },
    ],
  },
}
EOF
    
    # Update .gitignore for React
    cat >> "$project_path/.gitignore" << 'EOF'

# React/Vite
dist/
dist-ssr/
*.local
.eslintcache
EOF
    
    log "Template React applicato con successo"
}

# Crea progetto con template
create_project() {
    local project_name="$1"
    local template="$2"
    local project_type="$3"
    local project_path="$PROJECTS_DIR/$project_type/$project_name"
    
    # Verifica se il progetto esiste già
    if [[ -d "$project_path" ]]; then
        error "Il progetto '$project_name' esiste già in $project_type"
    fi
    
    info "Creando progetto: $project_name"
    info "Template: $template"
    info "Tipo: $project_type"
    info "Path: $project_path"
    
    # Crea struttura base
    create_base_structure "$project_path"
    
    # Applica template
    case "$template" in
        "python-basic")
            apply_python_template "$project_path"
            ;;
        "nodejs-api")
            apply_nodejs_template "$project_path"
            ;;
        "react-app")
            apply_react_template "$project_path"
            ;;
        "empty")
            info "Creato progetto vuoto con struttura base"
            ;;
        *)
            # Controlla se è un template custom
            if [[ -d "$TEMPLATES_DIR/$template" ]]; then
                info "Applicando template custom: $template"
                cp -r "$TEMPLATES_DIR/$template/"* "$project_path/" 2>/dev/null || true
                cp -r "$TEMPLATES_DIR/$template/".* "$project_path/" 2>/dev/null || true
                rm -rf "$project_path/.git" 2>/dev/null || true
            else
                warn "Template '$template' non trovato, usando struttura base"
            fi
            ;;
    esac
    
    # Inizializza git
    cd "$project_path"
    git init --quiet
    git add -A
    git commit -m "Initial commit: $project_name created from $template template" --quiet
    
    log "Progetto '$project_name' creato con successo!"
    
    # Mostra informazioni finali
    echo
    echo -e "${GREEN}✨ Progetto creato con successo!${NC}"
    echo -e "${BLUE}📁 Path:${NC} $project_path"
    echo
    echo -e "${CYAN}Prossimi passi:${NC}"
    echo "  cd $project_path"
    
    case "$template" in
        "python-basic")
            echo "  python -m venv venv"
            echo "  source venv/bin/activate  # o 'venv\\Scripts\\activate' su Windows"
            echo "  make install"
            echo "  python src/main.py"
            ;;
        "nodejs-api")
            echo "  npm install"
            echo "  npm run dev"
            ;;
        "react-app")
            echo "  npm install"
            echo "  npm run dev"
            ;;
    esac
    
    echo
    echo -e "${YELLOW}💡 Suggerimento:${NC} Usa 'claude-list.sh' per vedere tutti i progetti"
}

# Modalità interattiva
interactive_mode() {
    show_banner
    
    # Nome del progetto
    echo -e "${CYAN}Nome del progetto (lascia vuoto per generare automaticamente):${NC}"
    read -p "> " project_name
    
    # Tipo di progetto
    echo
    echo -e "${CYAN}Tipo di progetto:${NC}"
    echo "  1) active     - Progetto in sviluppo attivo"
    echo "  2) sandbox    - Progetto temporaneo/esperimento"
    echo "  3) production - Progetto pronto per produzione"
    echo
    read -p "Seleziona [1-3] (default: 1): " type_choice
    
    case "$type_choice" in
        2) PROJECT_TYPE="sandbox" ;;
        3) PROJECT_TYPE="production" ;;
        *) PROJECT_TYPE="active" ;;
    esac
    
    # Genera nome se necessario
    if [[ -z "$project_name" ]]; then
        project_name=$(generate_project_name "" "$PROJECT_TYPE")
        info "Nome generato: $project_name"
    else
        project_name=$(generate_project_name "$project_name" "$PROJECT_TYPE")
    fi
    
    # Lista template
    echo
    list_templates
    echo
    echo -e "${CYAN}Seleziona un template (o inserisci il nome di un template custom):${NC}"
    read -p "> " template
    
    # Default template
    if [[ -z "$template" ]]; then
        template="empty"
    fi
    
    # Conferma
    echo
    echo -e "${YELLOW}Riepilogo:${NC}"
    echo "  Nome: $project_name"
    echo "  Tipo: $PROJECT_TYPE"
    echo "  Template: $template"
    echo
    read -p "Procedere con la creazione? [Y/n]: " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        create_project "$project_name" "$template" "$PROJECT_TYPE"
    else
        warn "Creazione annullata"
    fi
}

# Help
show_help() {
    cat << EOF
Uso: $(basename "$0") [OPZIONI] [NOME] [TEMPLATE] [TIPO]

Crea un nuovo progetto Claude con template predefiniti.

ARGOMENTI:
    NOME      Nome del progetto (opzionale, verrà generato se omesso)
    TEMPLATE  Template da usare (default: empty)
    TIPO      Tipo di progetto: active|sandbox|production (default: active)

OPZIONI:
    -h, --help        Mostra questo messaggio
    -l, --list        Lista tutti i template disponibili
    -i, --interactive Modalità interattiva (default se nessun argomento)
    -t, --type TYPE   Specifica il tipo di progetto
    -T, --template    Specifica il template da usare

TEMPLATE DISPONIBILI:
    python-basic  - Progetto Python con struttura standard
    nodejs-api    - API REST con Node.js ed Express
    react-app     - Applicazione React con Vite
    empty         - Progetto vuoto con struttura minima
    [custom]      - Qualsiasi template in $TEMPLATES_DIR

ESEMPI:
    # Modalità interattiva
    $(basename "$0")
    
    # Crea progetto sandbox Python
    $(basename "$0") my-experiment python-basic sandbox
    
    # Crea progetto con nome auto-generato
    $(basename "$0") "" nodejs-api active
    
    # Lista template disponibili
    $(basename "$0") --list

EOF
}

# Main
main() {
    local project_name=""
    local template="empty"
    local interactive=false
    
    # Se nessun argomento, usa modalità interattiva
    if [[ $# -eq 0 ]]; then
        interactive=true
    fi
    
    # Parse argomenti
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                list_templates
                exit 0
                ;;
            -i|--interactive)
                interactive=true
                shift
                ;;
            -t|--type)
                PROJECT_TYPE="$2"
                shift 2
                ;;
            -T|--template)
                template="$2"
                shift 2
                ;;
            *)
                if [[ -z "$project_name" ]]; then
                    project_name="$1"
                elif [[ "$template" == "empty" ]]; then
                    template="$1"
                elif [[ "$PROJECT_TYPE" == "active" ]]; then
                    PROJECT_TYPE="$1"
                fi
                shift
                ;;
        esac
    done
    
    # Validazione tipo progetto
    if [[ ! "$PROJECT_TYPE" =~ ^(active|sandbox|production)$ ]]; then
        error "Tipo di progetto non valido: $PROJECT_TYPE. Usa: active, sandbox, o production"
    fi
    
    # Modalità interattiva o diretta
    if [[ "$interactive" == true ]]; then
        interactive_mode
    else
        # Genera nome se necessario
        if [[ -z "$project_name" ]]; then
            project_name=$(generate_project_name "" "$PROJECT_TYPE")
        else
            project_name=$(generate_project_name "$project_name" "$PROJECT_TYPE")
        fi
        
        create_project "$project_name" "$template" "$PROJECT_TYPE"
    fi
}

# Variabili globali
PROJECT_TYPE="${PROJECT_TYPE:-active}"
TEMPLATE="${TEMPLATE:-empty}"

# Esegui main
main "$@"