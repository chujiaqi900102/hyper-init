#!/bin/bash

# ==============================================================================
# HyperInit - Development Tools
# ==============================================================================

dev_menu() {
    show_menu "DEVELOPMENT ENVIRONMENT" \
        "1. Install Docker (Container Platform)" \
        "2. Install Podman (Daemonless Container Engine)" \
        "3. Install LXC/LXD (System Containers)" \
        "4. Install Node.js (via NVM or Package Manager)" \
        "5. Install Python Tools (uv Package Manager)" \
        "6. Install Rust (Rustup)" \
        "7. Install Go (Latest)" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Docker"*)
            install_docker
            ;;
        *"Podman"*)
            install_podman
            ;;
        *"LXC/LXD"*)
            install_lxc
            ;;
        *"Node.js"*)
            install_node
            ;;
        *"Python"*)
            install_python
            ;;
        *"Rust"*)
            install_rust
            ;;
        *"Go"*)
            install_go
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    dev_menu
}

install_docker() {
    info "Installing Docker..."
    
    # Only support Debian/Ubuntu for now
    if [ "$PKG_MANAGER" != "apt" ]; then
        warn "Docker installation currently only supports Debian/Ubuntu systems."
        warn "For other systems, please install manually."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        warn "Docker is already installed: $(docker --version)"
        read -p "Do you want to reinstall? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return
        fi
    fi
    
    # Select Docker CE source
    echo ""
    echo -e "${NEON_CYAN}Select Docker CE Installation Source:${RESET}"
    echo "  1. Tsinghua University (清华大学)"
    echo "  2. USTC (中国科学技术大学)"
    echo "  3. Aliyun (阿里云)"
    echo "  4. Tencent Cloud (腾讯云)"
    echo "  5. Official Docker (docker.com)"
    echo ""
    read -p "Enter your choice [1-5]: " docker_source_choice
    
    local docker_gpg_url=""
    local docker_repo_url=""
    
    case "$docker_source_choice" in
        1)
            docker_gpg_url="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian/gpg"
            docker_repo_url="https://mirrors.tuna.tsinghua.edu.cn/docker-ce/linux/debian"
            ;;
        2)
            docker_gpg_url="https://mirrors.ustc.edu.cn/docker-ce/linux/debian/gpg"
            docker_repo_url="https://mirrors.ustc.edu.cn/docker-ce/linux/debian"
            ;;
        3)
            docker_gpg_url="https://mirrors.aliyun.com/docker-ce/linux/debian/gpg"
            docker_repo_url="https://mirrors.aliyun.com/docker-ce/linux/debian"
            ;;
        4)
            docker_gpg_url="https://mirrors.tencent.com/docker-ce/linux/debian/gpg"
            docker_repo_url="https://mirrors.tencent.com/docker-ce/linux/debian"
            ;;
        5)
            docker_gpg_url="https://download.docker.com/linux/debian/gpg"
            docker_repo_url="https://download.docker.com/linux/debian"
            ;;
        *)
            error "Invalid choice. Aborting."
            read -n 1 -s -r -p "Press any key to continue..."
            return
            ;;
    esac
    
    info "Selected Docker CE source: $docker_repo_url"
    
    # Check if apt can read sources (e.g. avoid failing later due to conflicting Signed-By)
    if ! sudo apt-get update -qq 2>/dev/null; then
        warn "apt-get update failed (e.g. malformed docker.list or conflicting Microsoft Signed-By). Attempting repair..."
        repair_apt_sources --quiet
        if ! sudo apt-get update -qq 2>/dev/null; then
            error "Please run: System Initialization → Repair APT Sources, then try again."
            read -n 1 -s -r -p "Press any key to continue..."
            return 1
        fi
    fi
    
    # Install prerequisites (ca-certificates, curl, gnupg only; codename from /etc/os-release)
    run_task "Installing prerequisites" sudo apt-get install -y ca-certificates curl gnupg
    
    # Add Docker GPG key
    run_task "Adding Docker GPG key" bash -c "curl -fsSL $docker_gpg_url | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg"
    
    # Add Docker repository (codename from /etc/os-release so we don't require lsb-release)
    local arch=$(dpkg --print-architecture)
    local codename=""
    if [ -r /etc/os-release ]; then
        codename=$(grep -E '^VERSION_CODENAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
    fi
    if [ -z "$codename" ] && command -v lsb_release &>/dev/null; then
        codename=$(lsb_release -cs)
    fi
    if [ -z "$codename" ]; then
        error "Could not detect distribution codename (e.g. bookworm). Install lsb-release or set VERSION_CODENAME in /etc/os-release."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    echo "deb [arch=$arch signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] $docker_repo_url $codename stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    success "Docker repository configured"
    
    # Update package index
    run_task "Updating package index" sudo apt-get update
    
    # Install Docker
    run_task "Installing Docker Engine" sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group and configure mirror only if Docker was installed
    if command -v docker &>/dev/null; then
        if ! groups "$USER" | grep -q docker; then
            run_task "Adding $USER to docker group" sudo usermod -aG docker "$USER"
            warn "You need to logout and login again for docker group changes to apply."
        fi
    fi
    
    # Configure Docker Hub registry mirror
    echo ""
    echo -e "${NEON_CYAN}Select Docker Hub Registry Mirror (Optional):${RESET}"
    echo "  1. Aliyun (阿里云)"
    echo "  2. Tencent Cloud (腾讯云)"
    echo "  3. USTC (中国科学技术大学)"
    echo "  4. Docker China (docker.mirrors.ustc.edu.cn)"
    echo "  5. None (Use official Docker Hub)"
    echo ""
    read -p "Enter your choice [1-5]: " registry_choice
    
    local registry_mirror=""
    case "$registry_choice" in
        1) registry_mirror="https://registry.cn-hangzhou.aliyuncs.com" ;;
        2) registry_mirror="https://mirror.ccs.tencentyun.com" ;;
        3) registry_mirror="https://docker.mirrors.ustc.edu.cn" ;;
        4) registry_mirror="https://registry.docker-cn.com" ;;
        5) 
            info "Skipping Docker Hub registry mirror configuration."
            ;;
        *)
            warn "Invalid choice. Skipping registry mirror configuration."
            ;;
    esac
    
    if [ -n "$registry_mirror" ]; then
        info "Configuring Docker Hub registry mirror: $registry_mirror"
        
        sudo mkdir -p /etc/docker
        sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "registry-mirrors": ["$registry_mirror"]
}
EOF
        
        if command -v docker &>/dev/null && systemctl is-active --quiet docker 2>/dev/null; then
            run_task "Restarting Docker service" sudo systemctl restart docker
        elif command -v docker &>/dev/null; then
            run_task "Starting Docker service" sudo systemctl start docker
        fi
        success "Docker Hub registry mirror configured"
    fi
    
    success "Docker installation finished."
    
    # Show versions
    if command -v docker &> /dev/null; then
        echo -e "${NEON_CYAN}Docker Version:${RESET} $(docker --version)"
    fi
    if command -v docker &> /dev/null && docker compose version &> /dev/null; then
        echo -e "${NEON_CYAN}Docker Compose (Plugin):${RESET} $(docker compose version)"
    fi
    
    echo ""
    info "To use Docker without sudo, please logout and login again."
}

install_podman() {
    info "Installing Podman..."

    # On Debian/Ubuntu, ensure APT sources are valid before installing (fixes broken docker.list / Microsoft Signed-By)
    if [ "$PKG_MANAGER" = "apt" ]; then
        if ! sudo apt-get update -qq 2>/dev/null; then
            warn "APT update failed (e.g. malformed docker.list or conflicting Microsoft keys). Attempting repair..."
            repair_apt_sources --quiet
            if ! sudo apt-get update -qq 2>/dev/null; then
                error "Please run: System Initialization → Repair APT Sources, then try again."
                read -n 1 -s -r -p "Press any key to continue..."
                return 1
            fi
        fi
    fi

    install_pkg "podman"

    # Optional: Install podman-docker to simulate docker command
    read -p "Install 'podman-docker' wrapper (allows using 'docker' command)? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        install_pkg "podman-docker"
    fi

    success "Podman installed."
    echo -e "${NEON_CYAN}Podman Version:${RESET} $(podman --version)"
}

install_lxc() {
    info "Installing LXC and LXD..."
    
    if [ "$PKG_MANAGER" == "apt" ]; then
        # Ensure APT sources are readable (fix malformed docker.list / Microsoft Signed-By conflicts)
        if ! sudo apt-get update -qq 2>/dev/null; then
            warn "APT update failed (e.g. malformed docker.list or conflicting Microsoft Signed-By). Attempting repair..."
            repair_apt_sources --quiet
        fi
        # Ubuntu often prefers snap for lxd, but let's try apt first or snap
        if command -v snap &> /dev/null; then
            info "Installing LXD via Snap (Recommended for Ubuntu/Debian)..."
            sudo snap install lxd
            info "Initializing LXD (auto)..."
            sudo lxd init --auto
        else
            install_pkg "lxc"
            install_pkg "lxd" 
            # If lxd package not found via apt (older debian), warn
        fi
    else
        install_pkg "lxc"
        install_pkg "lxd"
    fi
    
    success "LXC/LXD installed."
    if command -v lxc &> /dev/null; then
        echo -e "${NEON_CYAN}LXC Version:${RESET} $(lxc --version)"
    fi
    if command -v lxd &> /dev/null; then
         echo -e "${NEON_CYAN}LXD Version:${RESET} $(lxd --version)"
    fi
}

install_node() {
    info "Installing Node.js via NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    
    nvm install --lts
    nvm use --lts
    success "Node.js Environment installed."
    
    echo -e "${NEON_CYAN}Node Version:${RESET} $(node -v)"
    echo -e "${NEON_CYAN}NPM Version:${RESET} $(npm -v)"
    echo -e "${NEON_CYAN}NVM Version:${RESET} $(nvm --version)"
}

install_python() {
    info "Installing Python tools..."
    # Install UV (fast Python package installer)
    curl -LsSf https://astral.sh/uv/install.sh | sh
    success "UV installed."
    
    # Reload profile or add to path manually just to check version if needed
    source "$HOME/.cargo/env" 2>/dev/null || true
    
    if command -v uv &> /dev/null; then
         echo -e "${NEON_CYAN}uv Version:${RESET} $(uv --version)"
    fi
    if command -v python3 &> /dev/null; then
        echo -e "${NEON_CYAN}System Python3:${RESET} $(python3 --version)"
    fi
}

install_rust() {
    info "Installing Rust via Rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    success "Rust installed."
    
    if command -v rustc &> /dev/null; then
        echo -e "${NEON_CYAN}rustc Version:${RESET} $(rustc --version)"
    fi
    if command -v cargo &> /dev/null; then
        echo -e "${NEON_CYAN}cargo Version:${RESET} $(cargo --version)"
    fi
}

install_go() {
    info "Installing Go..."
    # This is a simple install, ideally we'd fetch latest version dynamically.
    # For Debian/Ubuntu, apt might be old.
    # Using snap for convenience on Ubuntu, or tarball manual install.
    
    if [ "$PKG_MANAGER" == "apt" ]; then
        # Try snap if available
        if command -v snap &> /dev/null; then
            sudo snap install go --classic
        else
            install_pkg "golang-go"
        fi
    else
        install_pkg "go"
    fi
    success "Go installed."
    if command -v go &> /dev/null; then
        echo -e "${NEON_CYAN}Go Version:${RESET} $(go version)"
    fi
}
