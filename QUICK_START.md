# 🚀 Quick Start Guide - Claude Workspace

**⏱️ Setup time: 2 minutes** | **💻 Works on: Linux, macOS, Windows (WSL)**

---

## 🎯 **One-Command Installation**

### **Option 1: Full Auto-Install (Recommended)**
```bash
bash <(curl -sSL https://raw.githubusercontent.com/YOUR-USERNAME/claude-workspace/main/install.sh)
```

### **Option 2: Manual Steps**
If you prefer to see what's happening:

#### **Step 1: Prerequisites**
- **Linux/WSL**: `sudo apt update && sudo apt install python3 nodejs npm git curl`
- **macOS**: Install [Homebrew](https://brew.sh/), then `brew install python node git`

#### **Step 2: Install Claude Code**
```bash
npm install -g @anthropic-ai/claude-code
```

#### **Step 3: Get Workspace**
```bash
git clone https://github.com/YOUR-USERNAME/claude-workspace.git ~/claude-workspace
cd ~/claude-workspace
chmod +x scripts/*.sh
./scripts/claude-startup.sh
```

---

## 🎯 **How to Use**

### **Daily Workflow**

1. **Start Claude Code**
   ```bash
   claude
   ```

2. **Activate Workspace** (first command in Claude)
   ```bash
   cw
   ```
   Or manually:
   ```bash
   cd ~/claude-workspace && ./scripts/claude-startup.sh
   ```

3. **Work normally** - everything is automatically saved!

4. **Exit cleanly** (when done)
   ```bash
   cexit
   ```

### **Useful Commands**
```bash
cws     # Check system status
cwm     # Memory management  
cexit   # Smart exit (saves & closes Claude)
```

---

## 🛠️ **Where Am I? (Environment Guide)**

### **Windows Users**
- ✅ **Use WSL** (Windows Subsystem for Linux)
- ❌ **Don't use**: Command Prompt or PowerShell
- **Setup WSL**: `wsl --install` in PowerShell as Admin

### **Terminal Locations**
- **WSL**: Windows Terminal, Ubuntu app, or VS Code terminal
- **macOS**: Terminal.app, iTerm2, or VS Code terminal  
- **Linux**: Any terminal emulator

### **Directory Structure**
```
/home/yourusername/claude-workspace/    # Your workspace
├── scripts/                            # All the magic scripts
├── README.md                          # Full documentation
└── install.sh                         # The installer
```

---

## 🔧 **Prerequisites Explained**

### **What You Need**
1. **Python 3.8+** - For system scripts
2. **Node.js 18+** - For Claude Code
3. **Git** - For version control and sync
4. **curl/wget** - For downloads

### **Auto-Detection**
The installer automatically:
- 🔍 Detects your OS (Linux/macOS/WSL)
- 📦 Installs missing dependencies
- ⚙️ Configures everything correctly
- 🔗 Creates convenient aliases
- ✅ Verifies everything works

---

## 🚨 **Troubleshooting**

### **"claude: command not found"**
```bash
# Restart terminal, then:
source ~/.bashrc    # or ~/.zshrc
```

### **"Permission denied"**
```bash
chmod +x ~/claude-workspace/scripts/*.sh
```

### **"npm not found"**
- **Install Node.js first**, then retry installer

### **Windows Issues**
- **Use WSL**, not Windows native terminal
- **Don't install in C:/ drive paths**

---

## 🎉 **You're Ready!**

After installation:

1. **Open new terminal** (to load new PATH)
2. **Run `claude`** to start Claude Code
3. **Type `cw`** in Claude to activate workspace
4. **Start coding!** Everything is auto-saved

**🆘 Need help?** Open an [issue](https://github.com/YOUR-USERNAME/claude-workspace/issues)

---

## 📋 **What the Installer Does**

### **System Setup**
- ✅ Installs Python 3.8+ (if missing)
- ✅ Installs Node.js 18+ (if missing)  
- ✅ Installs Git (if missing)
- ✅ Installs Claude Code globally

### **Workspace Setup**
- ✅ Clones workspace to `~/claude-workspace`
- ✅ Makes all scripts executable
- ✅ Starts autonomous system
- ✅ Creates convenience aliases

### **Shell Configuration**
Adds to your `.bashrc`/`.zshrc`:
```bash
alias cw='cd ~/claude-workspace && ./scripts/claude-startup.sh'
alias cws='cd ~/claude-workspace && ./scripts/claude-autonomous-system.sh status'
alias cwm='cd ~/claude-workspace && ./scripts/claude-simplified-memory.sh'
alias cexit='~/claude-workspace/scripts/cexit'
```

**Everything just works!** 🚀