# HyperInit Architecture Documentation

## Table of Contents
1. [System Overview](#system-overview)
2. [Component Architecture](#component-architecture)
3. [Data Flow](#data-flow)
4. [Module Specifications](#module-specifications)
5. [Extension Points](#extension-points)
6. [Security Considerations](#security-considerations)

---

## System Overview

HyperInit is a modular, interactive Linux post-installation automation tool built entirely in Bash. It follows a layered architecture pattern with clear separation of concerns.

### Design Goals
- **User-Centric**: All operations require explicit user confirmation
- **Modular**: Features are isolated in independent modules
- **Portable**: Works across different Linux distributions
- **Maintainable**: Clear code structure with comprehensive documentation
- **Extensible**: Easy to add new features without modifying core

### Technology Stack
- **Language**: Bash 4.0+
- **UI**: ANSI escape codes + tput
- **Package Managers**: apt, dnf, pacman (abstracted)
- **Dependencies**: curl/wget, git, sudo

---

## Component Architecture

### Layer 1: Bootstrap (`bootstrap.sh`)

**Purpose**: Initial setup and repository cloning

**Responsibilities**:
- Ensure `git` and `curl` are installed
- Clone repository to `~/.hyper-init`
- Launch `main.sh`

**Key Logic**:
```bash
# Dependency installation loop
deps=(git curl)
for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
        # Detect package manager and install
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y "$dep"
        elif [ -f /etc/redhat-release ]; then
            sudo dnf install -y "$dep"
        elif [ -f /etc/arch-release ]; then
            sudo pacman -S --noconfirm "$dep"
        fi
    fi
done
```

**Exit Conditions**:
- Success: Launches `main.sh`
- Failure: Exits with error if dependencies cannot be installed

---

### Layer 2: Core Orchestrator (`main.sh`)

**Purpose**: Application entry point and main loop

**Responsibilities**:
- Source all libraries and modules
- Initialize sudo keep-alive
- Detect OS and set environment variables
- Display main menu
- Route user selections to appropriate modules

**Initialization Sequence**:
```
1. Set SCRIPT_DIR
2. Source lib/utils.sh (colors, logging)
3. Source lib/os.sh (OS detection)
4. Source lib/tui.sh (menu system)
5. Source all modules/*.sh
6. Call print_banner()
7. Call init_sudo()
8. Call detect_os()
9. Enter main_menu() loop
```

**Main Menu Loop**:
```bash
main_menu() {
    while true; do
        show_menu "MAIN MENU" \
            "1. System Initialization" \
            "2. Development Environment" \
            "3. Shell Customization" \
            "4. AI Agents" \
            "5. Desktop Applications" \
            "Q. Quit"

        case "$SELECTION" in
            *"System"*) system_menu ;;
            *"Development"*) dev_menu ;;
            *"Shell"*) shell_menu ;;
            *"AI"*) ai_menu ;;
            *"Desktop"*) desktop_menu ;;
            *"Quit"*) exit 0 ;;
        esac
    done
}
```

---

### Layer 3: Core Libraries (`lib/`)

#### `lib/os.sh` - OS Detection & Package Management

**Global Variables Set**:
- `OS_TYPE`: Distribution name (e.g., "Ubuntu", "Debian", "Fedora")
- `OS_VERSION`: Version number
- `PKG_MANAGER`: Package manager command (apt, dnf, pacman)

**Key Functions**:

| Function | Purpose | Return Value |
|----------|---------|--------------|
| `detect_os()` | Detect Linux distribution | Sets global vars |
| `install_pkg(pkg)` | Install package using detected manager | Exit code |
| `init_sudo()` | Initialize sudo with keep-alive | 0 on success |

**OS Detection Logic**:
```bash
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_TYPE=$NAME
        OS_VERSION=$VERSION_ID
    fi

    # Determine package manager
    if command -v apt &> /dev/null; then
        PKG_MANAGER="apt"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
    elif command -v pacman &> /dev/null; then
        PKG_MANAGER="pacman"
    fi
}
```

**Sudo Keep-Alive Mechanism**:
```bash
init_sudo() {
    if [[ $EUID -eq 0 ]]; then
        return 0  # Already root
    fi

    sudo -v  # Prompt for password

    # Background keep-alive loop
    ( while true; do 
        sudo -n true
        sleep 60
        kill -0 "$$" || exit  # Exit if parent dies
    done 2>/dev/null & )
}
```

#### `lib/tui.sh` - Terminal User Interface

**Global Variables**:
- `SELECTION`: Stores user's menu selection

**Key Functions**:

| Function | Purpose | Parameters |
|----------|---------|------------|
| `show_menu(title, options...)` | Display interactive menu | Title + option list |

**Menu Rendering Logic**:
```bash
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0

    tput civis  # Hide cursor

    while true; do
        print_banner
        echo -e "${NEON_CYAN}  === $title ===${RESET}"
        
        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "  ${NEON_PINK}> [${options[$i]}]${RESET}"
            else
                echo -e "    ${options[$i]}"
            fi
        done

        # Read arrow keys
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key == "[A" ]]; then ((selected--)); fi
            if [[ $key == "[B" ]]; then ((selected++)); fi
        elif [[ $key == "" ]]; then
            SELECTION="${options[$selected]}"
            break
        fi
    done

    tput cnorm  # Restore cursor
}
```

#### `lib/utils.sh` - Utilities

**Color Definitions**:
```bash
# Neon colors for cyberpunk theme
NEON_PINK='\033[1;95m'
NEON_CYAN='\033[1;96m'
NEON_GREEN='\033[1;92m'
NEON_YELLOW='\033[1;93m'
RESET='\033[0m'
```

**Logging Functions**:

| Function | Color | Icon | Use Case |
|----------|-------|------|----------|
| `info(msg)` | Blue | ℹ | Informational messages |
| `success(msg)` | Green | ✔ | Success confirmations |
| `warn(msg)` | Yellow | ⚠ | Warnings |
| `error(msg)` | Red | ✖ | Errors |
| `critical(msg)` | Bold Red | 🚨 | Critical errors (exits) |

**Task Execution with Spinner**:
```bash
run_task() {
    local message="$1"
    shift
    local cmd=("$@")

    echo -ne "${NEON_CYAN}⚙  ${message}...${RESET} "
    
    local log_file=$(mktemp)
    "${cmd[@]}" > "$log_file" 2>&1 &
    local pid=$!
    
    show_spinner $pid  # Animated spinner
    
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "\r${NEON_GREEN}✔  ${message} [DONE]${RESET}"
    else
        echo -e "\r${RED}✖  ${message} [FAILED]${RESET}"
        cat "$log_file"
    fi
    
    rm "$log_file"
    return $exit_code
}
```

---

### Layer 4: Feature Modules (`modules/`)

#### Module Structure Pattern

All modules follow this pattern:

```bash
#!/bin/bash

# Module menu function
module_menu() {
    show_menu "MODULE NAME" \
        "1. Feature A" \
        "2. Feature B" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Feature A"*) install_feature_a ;;
        *"Feature B"*) install_feature_b ;;
        *"Back"*) return ;;
    esac
    
    read -n 1 -s -r -p "Press any key to continue..."
    module_menu  # Recursive call for menu loop
}

# Feature installation functions
install_feature_a() {
    info "Installing Feature A..."
    # Installation logic
    success "Feature A installed."
}
```

#### `modules/system.sh` - System Configuration

**Functions**:

1. **`change_mirrors()`**
   - **Purpose**: Configure APT package mirrors
   - **User Interaction**: 6-option menu (Tsinghua, USTC, Aliyun, Tencent, Huawei, Official)
   - **Implementation**:
     ```bash
     # Detect distro
     . /etc/os-release
     distro=$ID
     codename=$VERSION_CODENAME
     
     # Generate sources.list
     sudo tee /etc/apt/sources.list > /dev/null <<EOF
     deb $mirror_url/debian/ $codename main contrib non-free non-free-firmware
     deb $mirror_url/debian/ $codename-updates main contrib non-free non-free-firmware
     deb $mirror_url/debian-security $codename-security main contrib non-free non-free-firmware
     EOF
     
     # Update package index
     sudo apt update
     ```

2. **`update_system()`**
   - **Purpose**: Update all packages
   - **User Interaction**: Confirmation prompt
   - **Implementation**: `sudo apt update && sudo apt upgrade -y`

3. **`configure_ssh()`**
   - **Purpose**: Harden SSH configuration
   - **User Interaction**: Automatic with backup
   - **Changes**:
     - `PermitRootLogin no`
     - `PasswordAuthentication yes` (can be customized)
     - Restart SSH service

4. **`enable_firewall()`**
   - **Purpose**: Enable and configure UFW
   - **User Interaction**: Confirmation prompt
   - **Default Rules**:
     - Allow SSH (port 22)
     - Default deny incoming
     - Default allow outgoing

#### `modules/dev.sh` - Development Tools

**Functions**:

1. **`install_docker()`**
   - **Purpose**: Install Docker Engine with user-selected sources
   - **User Interaction**: 2-step selection
     1. Docker CE source (5 options)
     2. Docker Hub mirror (5 options)
   - **Implementation Flow**:
     ```
     1. Check if already installed
     2. Select Docker CE source
     3. Install prerequisites (ca-certificates, curl, gnupg, lsb-release)
     4. Add Docker GPG key
     5. Add Docker repository
     6. Update package index
     7. Install docker-ce, docker-ce-cli, containerd.io, plugins
     8. Add user to docker group
     9. Select Docker Hub mirror
     10. Configure /etc/docker/daemon.json
     11. Restart Docker service
     12. Display versions
     ```

2. **`install_podman()`**
   - **Purpose**: Install Podman (daemonless alternative to Docker)
   - **User Interaction**: Optional podman-docker wrapper
   - **Implementation**:
     ```bash
     install_pkg "podman"
     
     read -p "Install 'podman-docker' wrapper? [Y/n] "
     if [[ $REPLY =~ ^[Yy]$ ]]; then
         install_pkg "podman-docker"
     fi
     ```

3. **`install_lxc()`**
   - **Purpose**: Install LXC/LXD system containers
   - **User Interaction**: Automatic
   - **Implementation**:
     ```bash
     if [ "$PKG_MANAGER" == "apt" ]; then
         if command -v snap &> /dev/null; then
             sudo snap install lxd
             sudo lxd init --auto
         else
             install_pkg "lxc"
             install_pkg "lxd"
         fi
     fi
     ```

4. **`install_node()`**
   - **Purpose**: Install Node.js via NVM
   - **User Interaction**: Automatic
   - **Implementation**:
     ```bash
     curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
     export NVM_DIR="$HOME/.nvm"
     [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
     nvm install --lts
     nvm use --lts
     ```

5. **`install_python()`**
   - **Purpose**: Install UV package manager
   - **User Interaction**: Automatic
   - **Implementation**: `curl -LsSf https://astral.sh/uv/install.sh | sh`

6. **`install_rust()`**
   - **Purpose**: Install Rust via Rustup
   - **User Interaction**: Automatic
   - **Implementation**:
     ```bash
     curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
     source "$HOME/.cargo/env"
     ```

7. **`install_go()`**
   - **Purpose**: Install Go
   - **User Interaction**: Automatic
   - **Implementation**: Snap (if available) or package manager

#### `modules/shell.sh` - Shell Customization

**Functions**:

1. **`install_zsh()`**
   - **Purpose**: Install Zsh and set as default shell
   - **User Interaction**: Automatic
   - **Implementation**:
     ```bash
     install_pkg "zsh"
     sudo chsh -s "$(which zsh)" "$USER"
     ```

2. **`install_omz()`**
   - **Purpose**: Install Oh-My-Zsh framework
   - **User Interaction**: Automatic (unattended mode)
   - **Dependency Check**: Prompts to install Zsh if missing
   - **Implementation**:
     ```bash
     sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
     ```

3. **`install_p10k()`**
   - **Purpose**: Install Powerlevel10k theme
   - **User Interaction**: Automatic
   - **Implementation**:
     ```bash
     git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
         "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
     sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
     ```

4. **`install_zsh_plugins()`**
   - **Purpose**: Install Zsh plugins
   - **User Interaction**: Automatic
   - **Plugins**:
     - zsh-autosuggestions
     - zsh-syntax-highlighting
   - **Implementation**:
     ```bash
     git clone https://github.com/zsh-users/zsh-autosuggestions \
         "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
     git clone https://github.com/zsh-users/zsh-syntax-highlighting \
         "${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
     sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
     ```

5. **`install_essentials()`**
   - **Purpose**: Install modern CLI tools
   - **User Interaction**: Multi-select menu (14 tools)
   - **Tool List**:
     ```
     [0] Select All / Deselect All
     [1] curl - Transfer data with URLs
     [2] wget - Network downloader
     [3] git - Version control system
     [4] neovim - Modern text editor
     [5] btop - Resource monitor
     [6] tmux - Terminal multiplexer
     [7] jq - JSON processor
     [8] tree - Directory structure viewer
     [9] unzip - Archive extraction
     [10] fastfetch - System info display
     [11] ripgrep - Fast text search
     [12] bat - Cat with syntax highlighting
     [13] fd - Fast file finder
     [14] zoxide - Smarter cd command
     ```
   - **Implementation**:
     ```bash
     # Parse user selections
     read -p "> " selections
     
     if [[ " $selections " =~ " 0 " ]]; then
         selected_tools=("${tools[@]}")  # Select all
     else
         for num in $selections; do
             tool_idx=$((num - 1))
             selected_tools+=("${tools[$tool_idx]}")
         done
     fi
     
     # Install with package name mapping
     for tool in "${selected_tools[@]}"; do
         case "$tool" in
             bat)
                 if [ "$PKG_MANAGER" == "apt" ]; then
                     install_pkg "bat"
                     ln -sf /usr/bin/batcat ~/.local/bin/bat
                 fi
                 ;;
             fd)
                 if [ "$PKG_MANAGER" == "apt" ]; then
                     install_pkg "fd-find"
                     ln -sf /usr/bin/fdfind ~/.local/bin/fd
                 fi
                 ;;
             *)
                 install_pkg "$tool"
                 ;;
         esac
     done
     ```

#### `modules/ai.sh` - AI Agents

**Functions**:

1. **`install_opencode()`**
   - **Purpose**: Install OpenCode terminal coding agent
   - **User Interaction**: Automatic
   - **Implementation**: `curl -fsSL https://opencode.ai/install | bash`

2. **`install_claude()`**
   - **Purpose**: Install Claude Code CLI
   - **User Interaction**: Prompts to install Node.js if missing
   - **Implementation**: `npm install -g @anthropic-ai/claude-code`

3. **`install_openclaw()`**
   - **Purpose**: Install OpenClaw autonomous agent
   - **User Interaction**: Prompts to install Node.js if missing
   - **Implementation**:
     ```bash
     npm install -g openclaw@latest
     openclaw onboard --install-daemon
     ```

#### `modules/desktop.sh` - Desktop Applications

**Functions**:

1. **`install_chrome()`**
   - **Purpose**: Install Google Chrome
   - **Platform**: Debian/Ubuntu only
   - **Implementation**:
     ```bash
     wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
     sudo apt install ./google-chrome-stable_current_amd64.deb -y
     rm google-chrome-stable_current_amd64.deb
     ```

2. **`install_vscode()`**
   - **Purpose**: Install Visual Studio Code
   - **Platform**: Debian/Ubuntu only
   - **Implementation**:
     ```bash
     wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
     sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
     sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
     sudo apt update
     sudo apt install code -y
     ```

3. **`install_fonts()`**
   - **Purpose**: Install Hack Nerd Font
   - **User Interaction**: Automatic
   - **Implementation**:
     ```bash
     mkdir -p ~/.local/share/fonts
     cd ~/.local/share/fonts
     wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
     unzip Hack.zip
     rm Hack.zip
     fc-cache -fv
     ```

---

## Data Flow

### User Interaction Flow

```
User launches bootstrap.sh
    ↓
Bootstrap ensures dependencies (git, curl)
    ↓
Bootstrap clones repo to ~/.hyper-init
    ↓
Bootstrap launches main.sh
    ↓
main.sh sources all libraries and modules
    ↓
main.sh initializes sudo keep-alive
    ↓
main.sh detects OS (sets OS_TYPE, OS_VERSION, PKG_MANAGER)
    ↓
main.sh displays main menu (via show_menu)
    ↓
User navigates with arrow keys, selects with Enter
    ↓
SELECTION variable is set by show_menu
    ↓
main_menu() case statement routes to module menu
    ↓
Module menu displays sub-options
    ↓
User selects feature
    ↓
Feature function executes:
    - Checks dependencies
    - Prompts for user input (if needed)
    - Installs packages (via install_pkg)
    - Configures system
    - Displays success/error
    ↓
Module menu loops back
    ↓
User can select "Back" to return to main menu
    ↓
User can select "Quit" to exit
```

### Package Installation Flow

```
Feature function calls install_pkg("package-name")
    ↓
install_pkg checks PKG_MANAGER variable
    ↓
Case statement routes to appropriate package manager:
    - apt: sudo apt install -y package-name
    - dnf: sudo dnf install -y package-name
    - pacman: sudo pacman -S --noconfirm package-name
    ↓
Command executes with sudo (kept alive by init_sudo)
    ↓
Returns exit code to caller
    ↓
Caller checks exit code and displays success/error
```

### Task Execution Flow (with Spinner)

```
Feature function calls run_task("Description", command, args...)
    ↓
run_task displays "⚙ Description..." message
    ↓
Creates temporary log file
    ↓
Executes command in background, redirects output to log
    ↓
Captures PID of background process
    ↓
Calls show_spinner(PID)
    ↓
show_spinner displays animated spinner while process runs
    ↓
wait for PID to complete
    ↓
Capture exit code
    ↓
If exit code == 0:
    - Display "✔ Description [DONE]"
    - Delete log file
    - Return 0
Else:
    - Display "✖ Description [FAILED]"
    - Display log file contents
    - Delete log file
    - Return exit code
```

---

## Extension Points

### Adding a New Module

1. **Create module file**: `modules/newmodule.sh`
2. **Implement module menu function**: `newmodule_menu()`
3. **Implement feature functions**: `install_feature_x()`
4. **Source module in main.sh**: `source "$SCRIPT_DIR/modules/newmodule.sh"`
5. **Add to main menu**: Update `main_menu()` in `main.sh`

### Adding a New Package Manager

1. **Update `detect_os()` in `lib/os.sh`**:
   ```bash
   elif command -v newpm &> /dev/null; then
       PKG_MANAGER="newpm"
   ```

2. **Update `install_pkg()` in `lib/os.sh`**:
   ```bash
   "newpm")
       sudo newpm install -y "$1"
       ;;
   ```

### Adding a New Mirror Source

1. **Update `change_mirrors()` in `modules/system.sh`**:
   ```bash
   echo "  7. New Mirror (example.com)"
   
   case "$mirror_choice" in
       # ... existing cases ...
       7) mirror_url="https://mirrors.example.com" ;;
   esac
   ```

### Adding a New Docker Source

1. **Update `install_docker()` in `modules/dev.sh`**:
   ```bash
   echo "  6. New Docker Source"
   
   case "$docker_source_choice" in
       # ... existing cases ...
       6)
           docker_gpg_url="https://example.com/docker-ce/linux/debian/gpg"
           docker_repo_url="https://example.com/docker-ce/linux/debian"
           ;;
   esac
   ```

---

## Security Considerations

### Sudo Usage

**Problem**: Scripts require sudo for package installation and system configuration.

**Solution**: `init_sudo()` function with keep-alive mechanism
- Prompts for password once at start
- Keeps sudo session alive with background loop
- Loop exits when parent script exits
- **Never uses `sudo -i`** (avoids full root shell)

**Implementation**:
```bash
init_sudo() {
    if [[ $EUID -eq 0 ]]; then
        return 0  # Already root
    fi

    sudo -v  # Prompt for password

    # Keep-alive: update sudo timestamp every 60 seconds
    ( while true; do 
        sudo -n true
        sleep 60
        kill -0 "$$" || exit  # Exit if parent dies
    done 2>/dev/null & )
}
```

### External Script Execution

**Problem**: Original design used external scripts (LinuxMirrors.cn) which could contain ads or malicious code.

**Solution**: Native implementation
- All mirror configuration is done natively in `modules/system.sh`
- All Docker installation is done natively in `modules/dev.sh`
- No external scripts are downloaded and executed

### File Backups

**Problem**: Modifying system files could break the system.

**Solution**: Automatic backups with timestamps
```bash
sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak.$(date +%Y%m%d_%H%M%S)
```

### Input Validation

**Problem**: User input could cause unexpected behavior.

**Solution**: Input validation in all interactive functions
```bash
if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#tools[@]}" ]; then
    # Valid input
else
    # Invalid input
fi
```

### Error Handling

**Problem**: Failed operations could leave system in inconsistent state.

**Solution**: Exit code checking and error messages
```bash
if [ $? -ne 0 ]; then
    error "Installation failed."
    return 1
fi
```

---

## Performance Considerations

### Spinner for Long-Running Tasks

**Problem**: Long-running commands appear to hang.

**Solution**: `run_task()` function with animated spinner
- Provides visual feedback
- Captures output to log file
- Displays errors if command fails

### Minimal Package Manager Calls

**Problem**: Multiple `apt update` calls slow down execution.

**Solution**: Batch operations
- Update once per module
- Install multiple packages in single command when possible

### Background Sudo Keep-Alive

**Problem**: Repeated password prompts interrupt workflow.

**Solution**: Single password prompt at start with background keep-alive
- Updates sudo timestamp every 60 seconds
- Automatically exits when parent script exits

---

## Testing Recommendations

### Manual Testing Checklist

- [ ] Test on fresh Debian installation
- [ ] Test on fresh Ubuntu installation
- [ ] Test on Fedora (if supported)
- [ ] Test on Arch (if supported)
- [ ] Test with minimal system (no curl/git)
- [ ] Test all menu navigation
- [ ] Test all module installations
- [ ] Test error handling (network failures, permission errors)
- [ ] Test backup creation
- [ ] Test version display after installation

### Automated Testing (Future)

- Unit tests for library functions
- Integration tests for module installations
- Docker-based testing on multiple distributions
- CI/CD pipeline with GitHub Actions

---

## Future Enhancements

### Configuration File Support

**Goal**: Allow users to define installation profiles in YAML/JSON

**Example**:
```yaml
# ~/.hyper-init/config.yaml
profile: developer
modules:
  system:
    mirror: tsinghua
    update: true
    ssh: true
    firewall: true
  dev:
    docker:
      ce_source: aliyun
      hub_mirror: aliyun
    node: true
    python: true
    rust: true
  shell:
    zsh: true
    omz: true
    p10k: true
    tools:
      - git
      - neovim
      - btop
      - ripgrep
      - fd
      - bat
```

**Implementation**:
```bash
# Parse YAML with yq or custom parser
if [ -f ~/.hyper-init/config.yaml ]; then
    # Read configuration
    # Execute modules non-interactively
fi
```

### Dry-Run Mode

**Goal**: Preview changes without executing

**Implementation**:
```bash
# Add --dry-run flag
if [ "$DRY_RUN" == "true" ]; then
    info "Would execute: $command"
else
    $command
fi
```

### Rollback Functionality

**Goal**: Undo changes made by HyperInit

**Implementation**:
- Track all changes in a log file
- Store backups with metadata
- Provide rollback menu option

### Plugin System

**Goal**: Allow community-contributed modules

**Implementation**:
- Define plugin API
- Load plugins from `~/.hyper-init/plugins/`
- Validate plugin signatures

---

**Document Version**: 1.0  
**Last Updated**: 2026-02-12  
**Maintainer**: chujiaqi900102
