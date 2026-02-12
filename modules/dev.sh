#!/bin/bash

# ==============================================================================
# HyperInit - Development Tools
# ==============================================================================

dev_menu() {
    show_menu "DEVELOPMENT ENVIRONMENT" \
        "1. Install Docker (LinuxMirrors.cn - Recommended)" \
        "2. Install Node.js (via NVM or Package Manager)" \
        "3. Install Python Environment (uv + miniconda)" \
        "4. Install Rust (Rustup)" \
        "5. Install Go (Latest)" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Docker"*)
            install_docker
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
    bash <(curl -sSL https://linuxmirrors.cn/docker.sh)
    success "Docker installation complete."
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
