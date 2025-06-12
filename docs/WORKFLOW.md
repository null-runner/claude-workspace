# Workflow di Sviluppo - Claude Workspace

Questa guida descrive come utilizzare efficacemente Claude Workspace per i tuoi progetti di sviluppo.

## Come creare progetti

### 1. Struttura base di un progetto

Ogni progetto dovrebbe seguire questa organizzazione:

```
my-awesome-project/
├── README.md          # Descrizione del progetto
├── src/              # Codice sorgente
│   ├── main.py       # Entry point
│   └── modules/      # Moduli del progetto
├── tests/            # Test unitari e di integrazione
├── docs/             # Documentazione dettagliata
├── data/             # Dati di esempio o dataset
├── scripts/          # Script di utility
├── requirements.txt  # Dipendenze Python
└── .gitignore       # File da escludere da git
```

### 2. Creare un nuovo progetto

**Sul laptop** (workflow consigliato):
```bash
# Navigare nella directory appropriata
cd ~/claude-workspace/projects/active  # Per progetti in sviluppo
# oppure
cd ~/claude-workspace/projects/sandbox  # Per esperimenti

# Creare il progetto
mkdir my-new-project
cd my-new-project

# Inizializzare struttura base
mkdir -p src tests docs data scripts
touch README.md requirements.txt .gitignore

# Creare README iniziale
cat > README.md << EOF
# My New Project

## Descrizione
Breve descrizione del progetto.

## Setup
\`\`\`bash
pip install -r requirements.txt
\`\`\`

## Uso
\`\`\`bash
python src/main.py
\`\`\`

## Status
- [ ] Setup iniziale
- [ ] Implementazione core
- [ ] Testing
- [ ] Documentazione
EOF

# Sincronizzare immediatamente
~/claude-workspace/scripts/sync-now.sh
```

### 3. Tipi di progetti e dove metterli

**active/** - Progetti in sviluppo attivo
- Progetti su cui stai lavorando attualmente
- Necessitano sincronizzazione frequente
- Esempio: app web in sviluppo, script di automazione

**sandbox/** - Progetti sperimentali
- Test e proof of concept
- Codice usa e getta
- Esempio: test di nuove librerie, esperimenti

**production/** - Progetti completati/stabili
- Codice pronto per produzione
- Cambiamenti poco frequenti
- Esempio: tool completati, progetti deployati

## Workflow di sviluppo

### Workflow 1: Sviluppo Mobile-First (Laptop → Desktop)

Ideale quando inizi a lavorare fuori casa e vuoi continuare sul PC fisso.

```bash
# 1. Sul laptop - iniziare sviluppo
cd ~/claude-workspace/projects/active/my-project
# ... sviluppo codice ...

# 2. Commit locale (opzionale ma consigliato)
git add .
git commit -m "WIP: feature implementation"

# 3. Sincronizzare con desktop
~/claude-workspace/scripts/sync-now.sh

# 4. Sul desktop - continuare sviluppo
cd ~/claude-workspace/projects/active/my-project
# ... continuare sviluppo ...

# 5. Sincronizzare di nuovo se torni al laptop
# Dal laptop:
~/claude-workspace/scripts/sync-now.sh
```

### Workflow 2: Sviluppo Desktop-First (Desktop → Laptop)

Quando il lavoro principale è sul desktop ma vuoi portarti il codice.

```bash
# 1. Sul desktop - sviluppo principale
cd ~/claude-workspace/projects/active/big-project
# ... sviluppo intensivo ...

# 2. Dal laptop - sincronizzare prima di uscire
~/claude-workspace/scripts/sync-now.sh

# 3. Sul laptop - lavorare offline
cd ~/claude-workspace/projects/active/big-project
# ... modifiche e fix ...

# 4. Quando torni online - sincronizzare
~/claude-workspace/scripts/sync-now.sh
```

### Workflow 3: Sviluppo Collaborativo con Claude

Ottimizzato per sessioni di pair programming con Claude AI.

```bash
# 1. Preparare il progetto per Claude
cd ~/claude-workspace/projects/active/ai-assisted-project

# 2. Creare context file per Claude
cat > .claude-context.md << EOF
## Project Context
- Language: Python 3.9
- Framework: FastAPI
- Database: PostgreSQL
- Current task: Implement user authentication

## Project Structure
\`\`\`
$(tree -L 2)
\`\`\`

## Recent Changes
$(git log --oneline -10)
EOF

# 3. Sviluppare con Claude
# ... sessione di coding ...

# 4. Sincronizzare dopo la sessione
~/claude-workspace/scripts/sync-now.sh

# 5. Sul desktop - review del codice
cd ~/claude-workspace/projects/active/ai-assisted-project
git diff
```

## Esempi pratici

### Esempio 1: Web Scraper Python

```bash
# Creare progetto
cd ~/claude-workspace/projects/active
mkdir web-scraper
cd web-scraper

# Setup struttura
mkdir -p src/{scrapers,utils} tests data/raw data/processed

# File principale
cat > src/main.py << 'EOF'
#!/usr/bin/env python3
"""
Web Scraper - Main entry point
"""
import argparse
from scrapers.base import BaseScraper

def main():
    parser = argparse.ArgumentParser(description='Web Scraper')
    parser.add_argument('url', help='URL to scrape')
    parser.add_argument('--output', '-o', default='data/raw/output.json')
    args = parser.parse_args()
    
    scraper = BaseScraper()
    data = scraper.scrape(args.url)
    scraper.save(data, args.output)

if __name__ == '__main__':
    main()
EOF

# Requirements
cat > requirements.txt << EOF
requests>=2.28.0
beautifulsoup4>=4.11.0
pandas>=1.5.0
pytest>=7.2.0
EOF

# Gitignore
cat > .gitignore << EOF
__pycache__/
*.pyc
.pytest_cache/
data/raw/*
data/processed/*
!data/raw/.gitkeep
!data/processed/.gitkeep
.env
*.log
EOF

# Creare .gitkeep per mantenere directory vuote
touch data/raw/.gitkeep data/processed/.gitkeep

# Sincronizzare
~/claude-workspace/scripts/sync-now.sh
```

### Esempio 2: API REST con Node.js

```bash
# Creare progetto
cd ~/claude-workspace/projects/active
mkdir rest-api
cd rest-api

# Inizializzare npm
npm init -y

# Installare dipendenze
npm install express cors dotenv
npm install -D nodemon jest supertest

# Struttura
mkdir -p src/{routes,controllers,models,middleware} tests

# Server principale
cat > src/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.get('/health', (req, res) => {
    res.json({ status: 'ok', timestamp: new Date() });
});

// Start server
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});

module.exports = app;
EOF

# Package.json scripts
npm pkg set scripts.start="node src/server.js"
npm pkg set scripts.dev="nodemon src/server.js"
npm pkg set scripts.test="jest"

# Environment file
cat > .env.example << EOF
PORT=3000
NODE_ENV=development
DATABASE_URL=postgresql://user:pass@localhost/dbname
EOF

cp .env.example .env

# Sincronizzare
~/claude-workspace/scripts/sync-now.sh
```

### Esempio 3: Data Analysis con Jupyter

```bash
# Creare progetto
cd ~/claude-workspace/projects/active
mkdir data-analysis
cd data-analysis

# Setup ambiente Python
python -m venv venv
source venv/bin/activate

# Installare dipendenze
pip install jupyter pandas numpy matplotlib seaborn scikit-learn

# Salvare requirements
pip freeze > requirements.txt

# Struttura
mkdir -p notebooks data/{raw,processed,figures} src

# Notebook iniziale
cat > notebooks/01_exploratory_analysis.ipynb << 'EOF'
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Exploratory Data Analysis\n",
    "## Project: Data Analysis\n",
    "### Date: $(date +%Y-%m-%d)"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import pandas as pd\n",
    "import numpy as np\n",
    "import matplotlib.pyplot as plt\n",
    "import seaborn as sns\n",
    "\n",
    "# Configuration\n",
    "sns.set_style('whitegrid')\n",
    "plt.rcParams['figure.figsize'] = (10, 6)"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EOF

# Script di utility
cat > src/data_loader.py << 'EOF'
"""
Data loading utilities
"""
import pandas as pd
from pathlib import Path

DATA_DIR = Path(__file__).parent.parent / 'data'

def load_raw_data(filename):
    """Load data from raw directory"""
    filepath = DATA_DIR / 'raw' / filename
    return pd.read_csv(filepath)

def save_processed_data(df, filename):
    """Save processed data"""
    filepath = DATA_DIR / 'processed' / filename
    df.to_csv(filepath, index=False)
    print(f"Data saved to {filepath}")
EOF

# Sincronizzare
~/claude-workspace/scripts/sync-now.sh
```

## Best Practices per i Workflow

### 1. Sincronizzazione

**Quando sincronizzare**:
- Prima di cambiare dispositivo
- Dopo modifiche significative
- Prima di sessioni con Claude AI
- A fine giornata lavorativa

**Verificare sync**:
```bash
# Controllare ultimo sync
tail -10 ~/claude-workspace/logs/sync.log

# Dry run per vedere cosa verrà sincronizzato
rsync -avzn ~/claude-workspace/projects/ nullrunner@192.168.1.106:~/claude-workspace/projects/
```

### 2. Organizzazione progetti

**Naming conventions**:
```
# Buono
web-scraper-python
api-rest-nodejs
ml-classification-project

# Evitare
progetto1
test
nuovo-progetto-finale-v2-FINAL
```

**Documentazione minima**:
- README.md con setup e uso
- requirements.txt o package.json
- .gitignore appropriato
- Commenti nel codice

### 3. Version Control

**Git workflow consigliato**:
```bash
# Inizializzare git in ogni progetto
git init
git add .
git commit -m "Initial commit"

# Branch per feature
git checkout -b feature/user-auth

# Commit frequenti
git add -p  # Per review interattivo
git commit -m "Add user authentication endpoint"

# Prima di sincronizzare
git status  # Verificare stato
```

### 4. Gestione dipendenze

**Python**:
```bash
# Ambiente virtuale sempre
python -m venv venv
source venv/bin/activate  # Linux/Mac
# o
venv\Scripts\activate  # Windows

# Freeze esatto delle versioni
pip freeze > requirements.txt
```

**Node.js**:
```bash
# Lock file sempre committato
npm ci  # Invece di npm install per build reproducibili

# Separare dev dependencies
npm install --save express
npm install --save-dev jest
```

### 5. Testing

**Struttura test consigliata**:
```
tests/
├── unit/           # Test unitari
├── integration/    # Test di integrazione
├── fixtures/       # Dati di test
└── conftest.py    # Config pytest (Python)
```

**Eseguire test prima di sync**:
```bash
# Python
pytest

# Node.js
npm test

# Sincronizzare solo se i test passano
if npm test; then
    ~/claude-workspace/scripts/sync-now.sh
else
    echo "Fix tests before syncing!"
fi
```

## Automazioni utili

### Pre-sync hook

Creare `~/claude-workspace/scripts/pre-sync-hook.sh`:
```bash
#!/bin/bash
# Eseguito automaticamente prima di ogni sync

echo "Running pre-sync checks..."

# Cercare file temporanei
find ~/claude-workspace/projects -name "*.tmp" -o -name "*.swp" | while read f; do
    echo "Warning: Temporary file found: $f"
done

# Verificare spazio disco
USED=$(df ~/claude-workspace | tail -1 | awk '{print $5}' | sed 's/%//')
if [ $USED -gt 80 ]; then
    echo "Warning: Disk usage is ${USED}%"
fi

# Controllare file grandi
find ~/claude-workspace/projects -size +100M -type f | while read f; do
    echo "Warning: Large file: $f ($(du -h "$f" | cut -f1))"
done
```

### Post-sync notification

Per notifiche desktop dopo sync:
```bash
# Aggiungere a sync-now.sh
if command -v notify-send &> /dev/null; then
    notify-send "Claude Workspace" "Sync completed successfully"
fi
```

### Project template generator

Script per creare nuovi progetti: `~/claude-workspace/scripts/new-project.sh`:
```bash
#!/bin/bash
# Usage: new-project.sh <name> <type>

NAME=$1
TYPE=$2

if [ -z "$NAME" ] || [ -z "$TYPE" ]; then
    echo "Usage: $0 <project-name> <python|node|data>"
    exit 1
fi

BASE_DIR="$HOME/claude-workspace/projects/active/$NAME"

case $TYPE in
    python)
        mkdir -p "$BASE_DIR"/{src,tests,docs}
        # ... setup Python project
        ;;
    node)
        mkdir -p "$BASE_DIR"/{src,tests}
        cd "$BASE_DIR" && npm init -y
        ;;
    data)
        mkdir -p "$BASE_DIR"/{notebooks,data/{raw,processed},src}
        # ... setup data project
        ;;
    *)
        echo "Unknown project type: $TYPE"
        exit 1
        ;;
esac

echo "Project $NAME created at $BASE_DIR"
```

## Risoluzione problemi comuni

### Conflitti di sincronizzazione

**Problema**: File modificati su entrambi i dispositivi

**Soluzione**:
```bash
# Backup locale
cp ~/claude-workspace/projects/active/my-project/conflicted-file.py ~/backup/

# Forzare sync da una direzione
rsync -avz --delete nullrunner@192.168.1.106:~/claude-workspace/projects/ ~/claude-workspace/projects/

# O manualmente risolvere
vimdiff local-file.py remote-file.py
```

### Progetti rotti dopo sync

**Problema**: Dipendenze o ambiente non sincronizzati

**Soluzione**:
```bash
# Python - ricreare ambiente
cd project-dir
rm -rf venv
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt

# Node.js - reinstallare dipendenze
rm -rf node_modules package-lock.json
npm install
```

### Performance lenta con progetti grandi

**Soluzione 1**: Escludere file non necessari

```bash
# In .rsync-exclude
node_modules/
venv/
*.pyc
__pycache__/
.git/objects/
*.log
coverage/
dist/
build/
```

**Soluzione 2**: Sync incrementale solo di certi file
```bash
# Sync solo codice sorgente
rsync -avz --include="*.py" --include="*.js" --include="*/" --exclude="*" \
    ~/claude-workspace/projects/big-project/ \
    nullrunner@192.168.1.106:~/claude-workspace/projects/big-project/
```