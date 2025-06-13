# 🚀 Claude Workspace

**[🇬🇧 English](README.md) | 🇮🇹 Italiano**

> 🎯 **Un workspace intelligente e autonomo che non dimentica mai e sincronizza tutto tra dispositivi**

---

## 🤔 Cos'è questo?

Claude Workspace è la **memoria completamente autonoma del tuo assistente di coding** che funziona ovunque! 

Pensalo come:
- 📁 **Cartelle intelligenti** che si sincronizzano tra tutti i tuoi computer
- 🧠 **Memoria persistente** che ricorda tutto tra le sessioni
- 🔄 **Auto-sync magico** che funziona in background
- 🤖 **Sistemi autonomi** che salvano e recuperano automaticamente
- 🛡️ **Sicurezza Fort Knox** ma facile come bere un bicchier d'acqua

Perfetto per:
- 👩‍💻 **Sviluppatori** stanchi di "dove ho lasciato quel codice?"
- 🎨 **Coder creativi** che vogliono tutto funzioni in autonomia
- 🚀 **Chiunque** lavori su progetti su più dispositivi
- 🧠 **Utenti** che vogliono che Claude ricordi tutto tra le sessioni

---

## ✨ **NUOVO: Sistema Completamente Autonomo (2025)**

### 🤖 **Memoria Semplificata & Context**
- **Ripristino context puro per Claude** senza scoring complesso
- **Auto-save basato su modifiche git** e tempo (intervalli 30min)  
- **Uscita autonoma senza prompt** che salva solo quando necessario
- **Continuità sessione a prova di crash** con recupero automatico
- **Formato context ultra-minimale** focalizzato su ciò che serve a Claude

### 🎯 **Auto Rilevamento Progetti**
- **Riconoscimento intelligente progetti** quando entri nelle directory
- **Auto-start activity tracking** per projects/active/, projects/sandbox/
- **Cambio progetto senza soluzione di continuità** con gestione automatica stato
- **Zero configurazione richiesta** - funziona per convenzione

### 🧠 **Estrazione Intelligence**
- **Auto-apprendimento da git commits** (modifiche significative, feature, fix)
- **Analisi pattern errori** dai log per prevenire problemi ricorrenti  
- **Rilevamento pattern creazione file** (nuovi progetti, script, docs)
- **Generazione automatica insights** con categorizzazione e valutazione impatto

### 🤖 **Master Daemon Autonomo**
- **Sistema background unificato** che gestisce tutti i servizi
- **Monitoraggio salute** con rilevamento servizi degradati
- **Orchestrazione servizi** (context, progetti, intelligence, salute)
- **Shutdown elegante** con salvataggio context finale
- **Log decisioni** con Architecture Decision Records (ADR)
- **Tracker apprendimento** che previene errori ripetuti
- **Auto-testing** con rilevamento framework
- **Aggregazione errori** e analisi pattern
- **Report produttività settimanali**

---

## 🎯 Avvio Rapido (Massimo 10 Passi!)

### 1️⃣ Verifica Prerequisiti
```bash
# Esegui questo per verificare se sei pronto
curl -s https://raw.githubusercontent.com/null-runner/claude-workspace/main/check.sh | bash
```

### 2️⃣ Crea Account GitHub
- Vai su [github.com](https://github.com) → Registrati
- Crea un nuovo repository chiamato `claude-workspace`
- Rendilo privato (consigliato)

### 3️⃣ Installa sul Computer Principale
```bash
cd ~
git clone https://github.com/TUOUSERNAME/claude-workspace.git
cd claude-workspace
./scripts/setup.sh
```

### 4️⃣ Genera Chiave SSH
```bash
ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key
```

### 5️⃣ Aggiungi Chiave a GitHub
- Copia la chiave: `cat ~/.ssh/claude_workspace_key.pub`
- GitHub → Impostazioni → Deploy keys → Aggiungi nuova
- Incolla e salva

### 6️⃣ Testa Tutto
```bash
./scripts/claude-startup.sh                    # Avvia servizi autonomi
./scripts/claude-autonomous-system.sh status   # Verifica che tutto funzioni
```

### 7️⃣ Aggiungi il Tuo Laptop
```bash
# Sul laptop:
curl -o setup.sh https://github.com/TUOUSERNAME/claude-workspace/raw/main/scripts/setup-laptop.sh
chmod +x setup.sh && ./setup.sh
```

### 8️⃣ Crea il Primo Progetto
```bash
cd ~/claude-workspace/projects/active
mkdir mio-progetto-fantastico
cd mio-progetto-fantastico
# Auto-memory salverà automaticamente!
```

### 9️⃣ Cambio Dispositivo e Continuità
```bash
# Su qualsiasi dispositivo - Claude carica automaticamente il tuo context!
# Avvia semplicemente una nuova sessione Claude e ricorda tutto
```

### 🔟 Cambia Dispositivo e Continua
```bash
# Su qualsiasi dispositivo:
cd ~/claude-workspace
claude-resume  # Vedi cosa stavi facendo!
```

---

## 🌈 Per Principianti e Vibe Coder

### "Non sono un programmatore!"
Nessun problema! Claude Workspace è per tutti quelli che:
- 📝 Lavorano su documenti con diversi dispositivi
- 🎨 Creano progetti di qualsiasi tipo
- 🤯 Dimenticano cosa stavano facendo ieri
- 💡 Vogliono che il loro computer sia più intelligente

### Come funziona (in linguaggio umano)
```
🖥️ Il tuo Desktop       ☁️ Cloud GitHub        💻 Il tuo Laptop
       |                        |                       |
       |-----> Push magico ---->|<----- Pull magico ---|
       |                        |                       |
   [Il tuo lavoro]         [Backup sicuro]        [Il tuo lavoro]
```

### Comandi che Amerai
```bash
# Tutto avviene automaticamente, ma puoi comunque:
./scripts/claude-autonomous-exit.sh           # Uscita intelligente senza prompt
./scripts/claude-simplified-memory.sh load    # Carica/salva context
./scripts/claude-autonomous-system.sh status  # Controlla servizi autonomi
./scripts/claude-auto-project-detector.sh     # Test rilevamento progetti
./scripts/claude-intelligence-extractor.sh    # Vedi insights auto-estratti
```

---

## 📊 Panoramica Visiva del Sistema

```
🏠 claude-workspace/
├── 📁 projects/
│   ├── 🔥 active/       ← Il tuo lavoro attuale
│   ├── 🧪 sandbox/      ← Esperimenti e gioco
│   └── ✅ production/   ← Cose finite
├── 🧠 .claude/memory/   ← Il cervello del workspace
├── 📜 scripts/          ← Strumenti utili
└── 📚 docs/            ← Guide dettagliate
```

---

## 🛠️ Funzionalità Principali

**🧠 Memoria Smart** - Ricorda tutto, traccia TODO, si pulisce da sola
**🔄 Auto-Sync** - Ogni 5 minuti tra tutti i dispositivi, funziona e basta™️  
**🔐 Sicurezza** - Chiavi SSH, repo privati, solo tu puoi accedere

---

## 📖 Serve Più Dettaglio?

Consulta la nostra documentazione dettagliata:

| Argomento | Descrizione | Link |
|-----------|-------------|------|
| 🚀 **Setup** | Guida completa installazione | [docs/SETUP_IT.md](docs/SETUP_IT.md) |
| 🧠 **Memoria** | Come funziona la memoria smart | [docs/MEMORY-SYSTEM_IT.md](docs/MEMORY-SYSTEM_IT.md) |
| 🔄 **Workflow** | Utilizzo quotidiano | [docs/WORKFLOW_IT.md](docs/WORKFLOW_IT.md) |
| 🔐 **Sicurezza** | Mantieni il lavoro al sicuro | [docs/SECURITY_IT.md](docs/SECURITY_IT.md) |
| 🧪 **Sandbox** | Sperimenta liberamente | [docs/SANDBOX-SYSTEM_IT.md](docs/SANDBOX-SYSTEM_IT.md) |

---

## 🆘 Risoluzione Problemi Rapida

```bash
# Non si sincronizza? Forzalo:
git pull origin main && git push origin main

# Non vedi la memoria? Aggiorna:
claude-resume

# Comandi non funzionano? Sistema i permessi:
chmod +x scripts/*.sh && source ~/.bashrc
```

---

## 💝 Community e Supporto

🐛 [Segnala bug](https://github.com/null-runner/claude-workspace/issues) | 💡 [Condividi idee](https://github.com/null-runner/claude-workspace/discussions) | 🤝 PR benvenute!

---

## 🎉 Sei Pronto!

Ecco fatto! Ora hai:
- ✅ Progetti che si sincronizzano ovunque
- ✅ Un sistema che ricorda tutto
- ✅ Backup automatici
- ✅ Tranquillità mentale

**Buona programmazione! 🚀**

---

<p align="center">
  Fatto con ❤️ per sviluppatori e vibe coder<br>
  <em>Perché il tuo computer dovrebbe lavorare per te, non contro di te</em>
</p>