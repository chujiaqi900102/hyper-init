#!/bin/bash

# ==============================================================================
# HyperInit - Development Tools
# ==============================================================================

dev_menu() {
    show_menu "DEVELOPMENT ENVIRONMENT" \
        "1. Install Docker (LinuxMirrors.cn - Recommended)" \
        "2. Install Podman (Daemonless Container Engine)" \
        "3. Install LXC/LXD (System Containers)" \
        "4. Install Node.js (via NVM or Package Manager)" \
        "5. Install Python Environment (uv + miniconda)" \
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
    info "Installing Docker (Legacy/Stable via Lite Script)..."
    
    local script_url="https://linuxmirrors.cn/docker-lite.sh"
    local script_file="/tmp/docker_lite.sh"
    
    curl -sSL "$script_url" -o "$script_file"
    
    # Run the lite script with minimal interaction
    # The --source option avoids menu if possible, but docker-lite often defaults to official if not specified.
    # Trying clean run. 
    # Use sudo only, no sudo -i.
    
    run_task "Running Docker installation" sudo bash "$script_file" --ignore-backup-tips --docker-ce-source "tuna" --docker-hub-source "audit"
    
    rm -f "$script_file"
    
    # Post-install user group
    if ! groups "$USER" | grep -q docker; then
        run_task "Adding $USER to docker group" sudo usermod -aG docker "$USER"
        warn "You may need to logout and login again for docker group changes to apply."
    fi
     
    success "Docker install process finished."

    if command -v docker &> /dev/null; then
        echo -e "${NEON_CYAN}Docker Version:${RESET} $(docker --version)"
    fi
    if command -v docker-compose &> /dev/null; then
        echo -e "${NEON_CYAN}Docker Compose Version:${RESET} $(docker-compose --version)"
    else
        # newer docker has compose as plugin
        echo -e "${NEON_CYAN}Docker Compose (Plugin):${RESET} $(docker compose version 2>/dev/null)"
    fi
}

install_podman() {
    info "Installing Podman..."
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
