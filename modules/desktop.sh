#!/bin/bash

# ==============================================================================
# HyperInit - Desktop Applications
# ==============================================================================

desktop_menu() {
    show_menu "DESKTOP APPLICATIONS" \
        "1. Install Google Chrome" \
        "2. Install Visual Studio Code" \
        "3. Install Nerd Fonts (Hack Nerd Font)" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Chrome"*)
            install_chrome
            ;;
        *"Visual Studio Code"*)
            install_vscode
            ;;
        *"Nerd Fonts"*)
            install_fonts
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    desktop_menu
}

install_chrome() {
    # Dependency: wget
    if ! command -v wget &> /dev/null; then
        warn "wget not found. Installing..."
        install_pkg "wget"
    fi

    if [ "$PKG_MANAGER" == "apt" ]; then
        wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
        sudo apt install ./google-chrome-stable_current_amd64.deb -y
        rm google-chrome-stable_current_amd64.deb
        success "Google Chrome installed."
    else
        warn "Chrome install script only supports Debian/Ubuntu for now."
    fi
}

install_vscode() {
    # Dependency: wget, gpg
    local deps=(wget gpg)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            warn "$dep not found. Installing..."
            install_pkg "$dep"
        fi
    done

    if [ "$PKG_MANAGER" == "apt" ]; then
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        rm -f packages.microsoft.gpg
        
        sudo apt install apt-transport-https
        sudo apt update
        sudo apt install code -y
        success "VS Code installed."
    else
        warn "VS Code install script only supports Debian/Ubuntu for now."
    fi
}

install_fonts() {
    # Dependency: wget, unzip
    local deps=(wget unzip)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            warn "$dep not found. Installing..."
            install_pkg "$dep"
        fi
    done

    info "Installing Hack Nerd Font..."
    mkdir -p ~/.local/share/fonts
    cd ~/.local/share/fonts
    wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
    unzip Hack.zip
    rm Hack.zip
    fc-cache -fv
    success "Fonts installed."
}
