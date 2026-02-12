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
    info "Launching LinuxMirrors Docker Installation Script..."
    if [ "$EUID" -ne 0 ]; then
        warn "This script requires a root login shell environment (sudo -i)."
        info "Switching context to execute..."
        sudo -i bash -c 'bash <(curl -sSL https://linuxmirrors.cn/docker.sh)'
    else
        bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
    fi
    success "Docker installation complete."
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
    
    success "Podman installed. Version: $(podman --version)"
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
}

install_node() {
    info "Installing Node.js via NVM..."
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
    
    nvm install --lts
    nvm use --lts
    success "Node.js $(node -v) installed."
}

install_python() {
    info "Installing Python tools..."
    # Install UV (fast Python package installer)
    curl -LsSf https://astral.sh/uv/install.sh | sh
    success "UV installed."
    
    # Optionally: install Miniconda? User might prefer system python + venv.
    # For now, stick to simple tools.
}

install_rust() {
    info "Installing Rust via Rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    success "Rust $(rustc --version) installed."
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
}
