# HyperInit 🚀

**HyperInit** is a cyberpunk-themed, interactive Linux post-installation script designed to rapidly set up your development environment. It supports **Debian/Ubuntu**, **RHEL/CentOS**, and **Arch Linux**.

## ✨ Features

- **Interactive TUI**: A cool, neon-styled menu system.
- **System Initialization**:
  - 🇨🇳 **Smart Mirrors**: Integrated with [LinuxMirrors](https://linuxmirrors.cn) for fast domestic mirror switching.
  - 🔒 **Security**: SSH hardening, UFW firewall configuration.
- **Dev Environment**:
  - 🐳 **Docker**: Optimized installation via LinuxMirrors.
  - 🐍 **Python**: `uv` + `miniconda`.
  - 🦀 **Rust**: `rustup`.
  - 🟢 **Node.js**: `nvm` + LTS.
- **AI Agents**:
  - 🤖 **OpenCode**: Terminal-based coding agent.
  - 🧠 **Claude Code**: Anthropic's CLI tool.
  - 🦞 **OpenClaw**: Autonomous AI agent.
- **Shell Experience**:
  - 🐚 **Zsh** + **Oh My Zsh**.
  - ⚡ **Powerlevel10k** theme.
  - 🔌 **Plugins**: Autosuggestions, Syntax Highlighting.
- **Desktop Apps**: Chrome, VS Code, Nerd Fonts.

## 🚀 Usage

### 1. Manual Installation
Clone the repository and run the script:

```bash
git clone https://github.com/chujiaqi900102/hyper-init.git ~/.hyper-init
cd ~/.hyper-init
bash main.sh
```

### 2. One-Line Install (Bootstrap)
**Debian/Ubuntu/WSL (Recommended for minimal systems):**
```bash
sudo apt update && sudo apt install -y curl && bash <(curl -sL https://raw.githubusercontent.com/chujiaqi900102/hyper-init/main/bootstrap.sh)
```

**Standard (if `curl` is already installed):**
```bash
bash <(curl -sL https://raw.githubusercontent.com/chujiaqi900102/hyper-init/main/bootstrap.sh)
```
```

## 📂 Project Structure

```
hyper-init/
├── bootstrap.sh       # Remote loader script
├── main.sh            # Main entry point
├── lib/
│   ├── utils.sh       # Colors, Spinner, Banner
│   ├── os.sh          # OS Detection & Abstraction
│   └── tui.sh         # Interactive Menu System
└── modules/
    ├── system.sh      # Mirrors, Update, Security
    ├── ai.sh          # AI Tools (OpenCode, Claude, OpenClaw)
    ├── dev.sh         # Docker, Languages
    ├── shell.sh       # Zsh & Plugins
    └── desktop.sh     # GUI Apps
```

## ⚠️ Notes

- **Root Privileges**: The script requires `sudo` for most operations.
- **Beta Version**: Currently optimized for Debian/Ubuntu. RHEL/Arch support is experimental.
