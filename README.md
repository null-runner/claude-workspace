# 🚀 Claude Workspace

**🇬🇧 English | [🇮🇹 Italiano](README_IT.md)**

> 🎯 **An intelligent workspace that syncs your projects and remembers everything across devices**

---

## 🤔 What is this?

Claude Workspace is your **personal coding assistant's memory** that works everywhere! 

Think of it as:
- 📁 **Smart folders** that sync between all your computers
- 🧠 **A brain** that remembers what you were working on
- 🔄 **Magic sync** that just works in the background
- 🛡️ **Fort Knox security** but easy as pie to use

Perfect for:
- 👩‍💻 **Developers** tired of "where did I leave that code?"
- 🎨 **Vibe coders** who just want things to work
- 🚀 **Anyone** working on projects across multiple devices

---

## 🎯 Quick Start (10 Steps Max!)

### 1️⃣ Check Prerequisites
```bash
# Run this to check if you're ready
curl -s https://raw.githubusercontent.com/null-runner/claude-workspace/main/check.sh | bash
```

### 2️⃣ Create GitHub Account
- Go to [github.com](https://github.com) → Sign up
- Create a new repository called `claude-workspace`
- Make it private (recommended)

### 3️⃣ Install on Main Computer
```bash
cd ~
git clone https://github.com/YOURUSERNAME/claude-workspace.git
cd claude-workspace
./scripts/setup.sh
```

### 4️⃣ Generate SSH Key
```bash
ssh-keygen -t ed25519 -f ~/.ssh/claude_workspace_key
```

### 5️⃣ Add Key to GitHub
- Copy the key: `cat ~/.ssh/claude_workspace_key.pub`
- GitHub → Settings → Deploy keys → Add new
- Paste and save

### 6️⃣ Test Everything
```bash
./scripts/claude-status.sh
```

### 7️⃣ Add Your Laptop
```bash
# On laptop:
curl -o setup.sh https://github.com/YOURUSERNAME/claude-workspace/raw/main/scripts/setup-laptop.sh
chmod +x setup.sh && ./setup.sh
```

### 8️⃣ Create First Project
```bash
cd ~/claude-workspace/projects/active
mkdir my-awesome-project
cd my-awesome-project
claude-save "Started my awesome project!"
```

### 9️⃣ Sync Magic
```bash
# Everything syncs automatically every 5 minutes!
# Or force it: git push origin main
```

### 🔟 Switch Devices & Continue
```bash
# On any device:
cd ~/claude-workspace
claude-resume  # See what you were doing!
```

---

## 🌈 For Beginners & Vibe Coders

### "I'm not a programmer!"
No problem! Claude Workspace is for everyone who:
- 📝 Works on documents across devices
- 🎨 Creates projects of any kind
- 🤯 Forgets what they were doing yesterday
- 💡 Wants their computer to be smarter

### How it works (in human language)
```
🖥️ Your Desktop          ☁️ GitHub Cloud         💻 Your Laptop
     |                         |                        |
     |-----> Push magic ------>|<------ Pull magic ----|
     |                         |                        |
   [Your work]            [Safe backup]           [Your work]
```

### Basic Commands You'll Love
```bash
claude-save "Remember to finish the logo tomorrow"  # Save a thought
claude-resume                                       # See what you were thinking
claude-todo add "Call mom"                          # Add a TODO
claude-todo list                                    # See all TODOs
```

---

## 📊 Visual System Overview

```
🏠 claude-workspace/
├── 📁 projects/
│   ├── 🔥 active/       ← Your current work
│   ├── 🧪 sandbox/      ← Experiments & play
│   └── ✅ production/   ← Finished stuff
├── 🧠 .claude/memory/   ← Your workspace's brain
├── 📜 scripts/          ← Helpful tools
└── 📚 docs/            ← Detailed guides
```

---

## 🛠️ Core Features

**🧠 Smart Memory** - Remembers everything, tracks TODOs, cleans itself
**🔄 Auto-Sync** - Every 5 minutes between all devices, just works™️  
**🔐 Security** - SSH keys, private repos, only you can access

---

## 📖 Need More Details?

Check out our detailed docs:

| Topic | Description | Link |
|-------|-------------|------|
| 🚀 **Setup** | Complete installation guide | [docs/SETUP_EN.md](docs/SETUP_EN.md) |
| 🧠 **Memory** | How the smart memory works | [docs/MEMORY-SYSTEM_EN.md](docs/MEMORY-SYSTEM_EN.md) |
| 🔄 **Workflow** | Daily usage patterns | [docs/WORKFLOW_EN.md](docs/WORKFLOW_EN.md) |
| 🔐 **Security** | Keep your work safe | [docs/SECURITY_EN.md](docs/SECURITY_EN.md) |
| 🧪 **Sandbox** | Experiment freely | [docs/SANDBOX-SYSTEM_EN.md](docs/SANDBOX-SYSTEM_EN.md) |

---

## 🆘 Quick Troubleshooting

```bash
# Not syncing? Force it:
git pull origin main && git push origin main

# Can't see memory? Refresh:
claude-resume

# Commands not working? Fix permissions:
chmod +x scripts/*.sh && source ~/.bashrc
```

---

## 💝 Community & Support

🐛 [Report bugs](https://github.com/null-runner/claude-workspace/issues) | 💡 [Share ideas](https://github.com/null-runner/claude-workspace/discussions) | 🤝 PRs welcome!

---

## 🎉 You're Ready!

That's it! You now have:
- ✅ Projects that sync everywhere
- ✅ A system that remembers everything
- ✅ Automatic backups
- ✅ Peace of mind

**Happy coding! 🚀**

---

<p align="center">
  Made with ❤️ for developers and vibe coders alike<br>
  <em>Because your computer should work for you, not against you</em>
</p>