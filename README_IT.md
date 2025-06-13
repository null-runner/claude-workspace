# 🚀 Claude Workspace

**[🇬🇧 English](README.md) | 🇮🇹 Italiano**

> 🎯 **Un workspace intelligente che sincronizza i tuoi progetti e ricorda tutto tra dispositivi**

---

## 🤔 Cos'è questo?

Claude Workspace è la **memoria del tuo assistente di programmazione personale** che funziona ovunque!

Immaginalo come:
- 📁 **Cartelle intelligenti** che si sincronizzano tra tutti i tuoi computer
- 🧠 **Un cervello** che ricorda su cosa stavi lavorando
- 🔄 **Sincronizzazione magica** che funziona in background
- 🛡️ **Sicurezza da Fort Knox** ma facile come bere un bicchier d'acqua

Perfetto per:
- 👩‍💻 **Sviluppatori** stanchi di "dove ho lasciato quel codice?"
- 🎨 **Vibe coder** che vogliono solo che le cose funzionino
- 🚀 **Chiunque** lavori su progetti con più dispositivi

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
./scripts/claude-status.sh
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
claude-save "Iniziato il mio progetto fantastico!"
```

### 9️⃣ Magia della Sincronizzazione
```bash
# Tutto si sincronizza automaticamente ogni 5 minuti!
# O forzalo: git push origin main
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

### Comandi Base che Amerai
```bash
claude-save "Ricordati di finire il logo domani"  # Salva un pensiero
claude-resume                                      # Vedi cosa stavi pensando
claude-todo add "Chiamare mamma"                   # Aggiungi un TODO
claude-todo list                                   # Vedi tutti i TODO
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