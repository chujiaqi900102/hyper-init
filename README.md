# HyperInit 🚀

> **The Cyberpunk Linux Setup Tool**  
> A modern, interactive post-installation automation script for Linux systems with a focus on user experience and flexibility.

![Version](https://img.shields.io/badge/version-0.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-Linux-orange)

---

## 📋 Table of Contents

- [Features](#-features)
- [Quick Start](#-quick-start)
- [Project Architecture](#-project-architecture)
- [Module Overview](#-module-overview)
- [Development Progress](#-development-progress)
- [Usage Guide](#-usage-guide)
- [Extending HyperInit](#-extending-hyperinit)
- [Contributing](#-contributing)

---

## ✨ Features

### 🎨 Modern User Experience
- **Interactive TUI**: Beautiful cyberpunk-themed terminal interface with arrow key navigation
- **User Choice First**: All operations require user confirmation with clear options
- **Progress Indicators**: Animated spinners and real-time status updates
- **Color-Coded Output**: Easy-to-read color scheme for different message types

### 🔧 System Configuration
- **Mirror Management**: Interactive selection of APT mirrors (Tsinghua, USTC, Aliyun, Tencent, Huawei)
- **System Updates**: Safe package updates with user control
- **SSH Hardening**: Disable root login and configure secure SSH
- **Firewall Setup**: UFW configuration with common presets

### 🐳 Development Tools
- **Docker**: Interactive installation with source selection (CE repos + Hub mirrors)
- **Podman**: Daemonless container engine with docker-wrapper option
- **LXC/LXD**: System containers via Snap or native packages
- **Node.js**: NVM-based installation with version management
- **Python**: UV package manager + system Python
- **Rust**: Rustup-based installation
- **Go**: Latest version via Snap or package manager

### 💻 Shell Customization
- **Zsh**: Modern shell with automatic setup
- **Oh-My-Zsh**: Framework with automated installation
- **Powerlevel10k**: Beautiful prompt theme
- **Zsh Plugins**: Auto-suggestions and syntax highlighting
- **Essential Tools**: Interactive multi-select menu for modern CLI tools:
  - `neovim` - Modern text editor
  - `btop` - Resource monitor
  - `bat` - Cat with syntax highlighting
  - `ripgrep` - Fast text search
  - `fd` - Fast file finder
  - `zoxide` - Smarter cd command
  - `fastfetch` - System info display
  - And more...

### 🤖 AI Agents
- **OpenCode**: Terminal coding agent
- **Claude Code**: Anthropic CLI
- **OpenClaw**: Autonomous agent with daemon

### 🖥️ Desktop Applications
- **Google Chrome**: Latest stable version
- **VS Code**: Microsoft's code editor
- **Nerd Fonts**: Hack Nerd Font for terminal

---

## 🚀 Quick Start

### Prerequisites
- A Debian/Ubuntu-based Linux system (primary support)
- `curl` or `wget` installed
- Internet connection
- Sudo privileges

### One-Line Installation

**Using curl:**
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/chujiaqi900102/hyper-init/main/bootstrap.sh)
```

**Using wget:**
```bash
bash <(wget -qO- https://raw.githubusercontent.com/chujiaqi900102/hyper-init/main/bootstrap.sh)
```

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/chujiaqi900102/hyper-init.git
cd hyper-init

# Run the main script
bash main.sh
```

---

## 🏗️ Project Architecture

### Directory Structure

```
hyper-init/
├── bootstrap.sh          # Bootstrap loader (handles initial setup)
├── main.sh              # Main entry point (orchestrates the application)
├── lib/                 # Core libraries
│   ├── os.sh           # OS detection and package management abstraction
│   ├── tui.sh          # Terminal UI engine (menu system)
│   └── utils.sh        # Utilities (logging, colors, animations)
└── modules/            # Feature modules
    ├── system.sh       # System configuration (mirrors, updates, SSH, firewall)
    ├── dev.sh          # Development tools (Docker, Node, Python, Rust, Go)
    ├── shell.sh        # Shell customization (Zsh, Oh-My-Zsh, tools)
    ├── ai.sh           # AI agents installation
    └── desktop.sh      # Desktop applications
```

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────┐
│                    bootstrap.sh                         │
│  • Ensures git/curl are installed                       │
│  • Clones repository to ~/.hyper-init                   │
│  • Launches main.sh                                     │
└────────────────────┬────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────┐
│                     main.sh                             │
│  • Sources all libraries and modules                    │
│  • Initializes sudo keep-alive                          │
│  • Detects OS and sets up environment                   │
│  • Displays main menu loop                              │
└────────────────────┬────────────────────────────────────┘
                     │
         ┌───────────┴───────────┬──────────────┐
         ▼                       ▼              ▼
┌─────────────────┐    ┌─────────────────┐    ┌──────────────┐
│   lib/os.sh     │    │   lib/tui.sh    │    │ lib/utils.sh │
│                 │    │                 │    │              │
│ • detect_os()   │    │ • show_menu()   │    │ • Logging    │
│ • install_pkg() │    │ • Arrow nav     │    │ • Colors     │
│ • PKG_MANAGER   │    │ • Selection     │    │ • Spinners   │
└─────────────────┘    └─────────────────┘    └──────────────┘
         │
         └──────────────────┬──────────────────────────────┐
                            ▼                              ▼
                  ┌─────────────────┐          ┌─────────────────┐
                  │ modules/*.sh    │          │  User Modules   │
                  │                 │          │  (Extensible)   │
                  │ • system.sh     │          └─────────────────┘
                  │ • dev.sh        │
                  │ • shell.sh      │
                  │ • ai.sh         │
                  │ • desktop.sh    │
                  └─────────────────┘
```

### Core Design Principles

1. **Modularity**: Each feature is isolated in its own module
2. **Abstraction**: OS-specific logic is abstracted in `lib/os.sh`
3. **User Control**: All operations require explicit user confirmation
4. **Idempotency**: Scripts can be run multiple times safely
5. **Progressive Enhancement**: Dependencies are installed automatically when needed
6. **No sudo -i**: Uses regular `sudo` to avoid security concerns

---

## 📦 Module Overview

### `lib/os.sh` - OS Detection & Package Management

**Key Functions:**
- `detect_os()`: Detects Linux distribution and sets `OS_TYPE`, `OS_VERSION`, `PKG_MANAGER`
- `install_pkg()`: Abstracted package installation (supports apt, dnf, pacman)
- `init_sudo()`: Initializes sudo with keep-alive background process

**Supported Package Managers:**
- `apt` (Debian, Ubuntu)
- `dnf` (Fedora, RHEL 8+)
- `pacman` (Arch, Manjaro)

### `lib/tui.sh` - Terminal User Interface

**Key Functions:**
- `show_menu()`: Interactive menu with arrow key navigation
- Sets global `SELECTION` variable with user choice

**Features:**
- Cursor hiding during navigation
- Real-time menu updates
- Cyberpunk color scheme

### `lib/utils.sh` - Utilities

**Logging Functions:**
- `info()`: Blue informational messages
- `success()`: Green success messages
- `warn()`: Yellow warning messages
- `error()`: Red error messages
- `critical()`: Red critical errors (exits script)

**UI Functions:**
- `print_banner()`: ASCII art banner
- `show_spinner()`: Animated loading spinner
- `run_task()`: Execute command with spinner and status

**Color Palette:**
- Neon Cyan, Pink, Green, Yellow for highlights
- Standard ANSI colors for text
- Bold variants for emphasis

### `modules/system.sh` - System Configuration

**Functions:**

| Function | Description | User Interaction |
|----------|-------------|------------------|
| `change_mirrors()` | Configure APT mirrors | Interactive source selection (6 options) |
| `update_system()` | Update packages | Confirmation prompt |
| `configure_ssh()` | Harden SSH config | Automatic with backup |
| `enable_firewall()` | Enable UFW | Confirmation prompt |

**Mirror Sources:**
1. Tsinghua University
2. USTC
3. Aliyun
4. Tencent Cloud
5. Huawei Cloud
6. Official (no change)

### `modules/dev.sh` - Development Tools

**Functions:**

| Function | Description | User Interaction |
|----------|-------------|------------------|
| `install_docker()` | Install Docker Engine | 2-step: CE source + Hub mirror selection |
| `install_podman()` | Install Podman | Optional docker-wrapper |
| `install_lxc()` | Install LXC/LXD | Automatic (Snap on Ubuntu) |
| `install_node()` | Install Node.js via NVM | Automatic LTS |
| `install_python()` | Install UV + Python | Automatic |
| `install_rust()` | Install Rust via Rustup | Automatic |
| `install_go()` | Install Go | Snap or package manager |

**Docker Installation Flow:**
1. Check if already installed
2. Select Docker CE source (5 options)
3. Add GPG key and repository
4. Install Docker Engine + Compose plugin
5. Add user to docker group
6. Select Docker Hub mirror (5 options)
7. Configure daemon.json
8. Display versions

### `modules/shell.sh` - Shell Customization

**Functions:**

| Function | Description | User Interaction |
|----------|-------------|------------------|
| `install_zsh()` | Install Zsh shell | Automatic + set as default |
| `install_omz()` | Install Oh-My-Zsh | Automatic (unattended) |
| `install_p10k()` | Install Powerlevel10k | Automatic theme setup |
| `install_zsh_plugins()` | Install plugins | Auto-suggestions + syntax highlighting |
| `install_essentials()` | Install CLI tools | **Multi-select menu (14 tools)** |

**Essential Tools Multi-Select:**
- Option 0: Select All / Deselect All
- Options 1-14: Individual tools with descriptions
- Handles Debian/Ubuntu package name quirks (`bat`/`batcat`, `fd`/`fdfind`)
- Creates symlinks in `~/.local/bin` automatically
- Displays installed versions after completion

### `modules/ai.sh` - AI Agents

**Functions:**
- `install_opencode()`: Terminal coding agent
- `install_claude()`: Anthropic CLI (requires Node.js)
- `install_openclaw()`: Autonomous agent (requires Node.js)

**Dependency Handling:**
- Automatically prompts to install Node.js if missing
- Reloads NVM environment after installation

### `modules/desktop.sh` - Desktop Applications

**Functions:**
- `install_chrome()`: Google Chrome (Debian/Ubuntu only)
- `install_vscode()`: VS Code with Microsoft repo
- `install_fonts()`: Hack Nerd Font

---

## � Development Progress

### ✅ Completed Features

#### Phase 1: Core Infrastructure (100%)
- [x] Bootstrap loader with dependency checks
- [x] Main menu system with TUI
- [x] OS detection and package manager abstraction
- [x] Sudo keep-alive mechanism
- [x] Logging and output utilities
- [x] Color scheme and animations

#### Phase 2: System Module (100%)
- [x] Interactive mirror selection (6 sources)
- [x] Native implementation (no external scripts)
- [x] Automatic backup with timestamps
- [x] System package updates
- [x] SSH hardening
- [x] UFW firewall setup

#### Phase 3: Development Module (100%)
- [x] Docker installation with interactive source selection
- [x] Docker Hub mirror configuration
- [x] Podman installation
- [x] LXC/LXD installation
- [x] Node.js via NVM
- [x] Python with UV
- [x] Rust via Rustup
- [x] Go installation
- [x] Version display after installation

#### Phase 4: Shell Module (100%)
- [x] Zsh installation and default shell setup
- [x] Oh-My-Zsh automated installation
- [x] Powerlevel10k theme
- [x] Zsh plugins (auto-suggestions, syntax highlighting)
- [x] Essential tools multi-select menu
- [x] Modern tool replacements (btop, neovim, bat, ripgrep, fd, zoxide)
- [x] Debian/Ubuntu package name handling
- [x] Symlink creation for compatibility

#### Phase 5: AI & Desktop Modules (100%)
- [x] AI agents installation (OpenCode, Claude, OpenClaw)
- [x] Desktop applications (Chrome, VS Code, Fonts)
- [x] Dependency auto-installation

### 🚧 In Progress

- [ ] Support for more Linux distributions (Fedora, Arch)
- [ ] Configuration file support (YAML/JSON)
- [ ] Dry-run mode
- [ ] Rollback functionality

### 📋 Planned Features

#### Phase 6: Enhanced Functionality
- [ ] Database installation (PostgreSQL, MySQL, Redis)
- [ ] Web server setup (Nginx, Apache)
- [ ] Monitoring tools (Prometheus, Grafana)
- [ ] Backup and restore functionality
- [ ] Custom configuration profiles

#### Phase 7: Advanced Features
- [ ] Remote installation support
- [ ] Multi-machine orchestration
- [ ] Configuration as Code (declarative YAML)
- [ ] Plugin system for community modules
- [ ] Web-based dashboard

---

## 📖 Usage Guide

### Main Menu Navigation

Use **arrow keys** (↑/↓) to navigate and **Enter** to select:

```
  === MAIN MENU ===

  > [1. System Initialization]
    2. Development Environment
    3. Shell Customization
    4. AI Agents
    5. Desktop Applications
    Q. Quit

  (Use Arrow Keys to Move, Enter to Select)
```

### Example Workflows

#### 1. Fresh System Setup

```bash
# Run HyperInit
bash main.sh

# Recommended order:
1. System Initialization → Change Mirrors → Select mirror
2. System Initialization → Update System Packages
3. Development Environment → Install Docker → Select sources
4. Shell Customization → Install Zsh
5. Shell Customization → Install Oh-My-Zsh
6. Shell Customization → Install Essential Tools → Select tools
```

#### 2. Developer Workstation

```bash
# Install development stack
1. Development Environment → Install Docker
2. Development Environment → Install Node.js
3. Development Environment → Install Python
4. Shell Customization → Install Essential Tools
   → Select: git, neovim, btop, ripgrep, fd, bat, zoxide
```

#### 3. AI Development Environment

```bash
1. Development Environment → Install Node.js
2. AI Agents → Install Claude Code
3. AI Agents → Install OpenClaw
4. Shell Customization → Install Essential Tools
```

---

## 🔧 Extending HyperInit

### Adding a New Module

1. **Create module file:**
```bash
touch modules/mymodule.sh
```

2. **Define module structure:**
```bash
#!/bin/bash

# ==============================================================================
# HyperInit - My Module
# ==============================================================================

mymodule_menu() {
    show_menu "MY MODULE" \
        "1. Install Tool A" \
        "2. Install Tool B" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Tool A"*)
            install_tool_a
            ;;
        *"Tool B"*)
            install_tool_b
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    mymodule_menu
}

install_tool_a() {
    info "Installing Tool A..."
    install_pkg "tool-a"
    success "Tool A installed."
}

install_tool_b() {
    info "Installing Tool B..."
    run_task "Installing Tool B" sudo apt install -y tool-b
    success "Tool B installed."
}
```

3. **Source module in main.sh:**
```bash
# Add to main.sh after other module sources
source "$SCRIPT_DIR/modules/mymodule.sh"
```

4. **Add to main menu:**
```bash
# In main_menu() function in main.sh
show_menu "MAIN MENU" \
    "1. System Initialization" \
    "2. Development Environment" \
    "3. Shell Customization" \
    "4. AI Agents" \
    "5. Desktop Applications" \
    "6. My Module" \  # Add this line
    "Q. Quit"

case "$SELECTION" in
    # ... existing cases ...
    *"My Module"*)
        mymodule_menu
        ;;
esac
```

### Best Practices for Extensions

1. **Use abstracted functions:**
   - `install_pkg()` instead of `apt install`
   - `run_task()` for long-running commands
   - Logging functions (`info`, `success`, `warn`, `error`)

2. **Check dependencies:**
```bash
if ! command -v dependency &> /dev/null; then
    warn "Dependency not found. Installing..."
    install_pkg "dependency"
fi
```

3. **Provide user interaction:**
```bash
read -p "Do you want to proceed? [Y/n] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
    # Proceed
fi
```

4. **Display versions after installation:**
```bash
if command -v tool &> /dev/null; then
    echo -e "${NEON_CYAN}Tool Version:${RESET} $(tool --version)"
fi
```

5. **Handle errors gracefully:**
```bash
if [ $? -ne 0 ]; then
    error "Installation failed."
    return 1
fi
```

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch:** `git checkout -b feature/my-feature`
3. **Follow the coding style:**
   - Use 4 spaces for indentation
   - Add comments for complex logic
   - Use descriptive variable names
4. **Test on multiple distributions** (if possible)
5. **Update documentation** (README.md, inline comments)
6. **Submit a pull request**

### Reporting Issues

Please include:
- OS distribution and version
- Steps to reproduce
- Expected vs actual behavior
- Error messages or logs

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🙏 Acknowledgments

- [Oh-My-Zsh](https://ohmyz.sh/) - Zsh framework
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) - Zsh theme
- [LinuxMirrors.cn](https://linuxmirrors.cn/) - Mirror source inspiration
- [Nerd Fonts](https://www.nerdfonts.com/) - Developer fonts

---

## 📞 Contact

- **Author:** chujiaqi900102
- **Repository:** https://github.com/chujiaqi900102/hyper-init
- **Issues:** https://github.com/chujiaqi900102/hyper-init/issues

---

**Made with ❤️ for the Linux community**
