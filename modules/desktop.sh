#!/bin/bash

# ==============================================================================
# HyperInit - Desktop Applications
# ==============================================================================

desktop_menu() {
    show_menu "DESKTOP APPLICATIONS" \
        "1. Install Google Chrome" \
        "2. Install Chromium" \
        "3. Install Microsoft Edge" \
        "4. Install Visual Studio Code" \
        "5. Install Nerd Fonts (Hack Nerd Font)" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Google Chrome"*)
            if install_chrome; then
                :
            else
                error "Google Chrome installation failed. See errors above."
            fi
            ;;
        *"Chromium"*)
            if install_chromium; then
                :
            else
                error "Chromium installation failed. See errors above."
            fi
            ;;
        *"Microsoft Edge"*)
            if install_edge; then
                :
            else
                error "Microsoft Edge installation failed. See errors above."
            fi
            ;;
        *"Visual Studio Code"*)
            if install_vscode; then
                :
            else
                error "Visual Studio Code installation failed. See errors above."
            fi
            ;;
        *"Nerd Fonts"*)
            if install_fonts; then
                :
            else
                error "Nerd Fonts installation failed. See errors above."
            fi
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    desktop_menu
}

install_chrome() {
    if command -v google-chrome-stable &>/dev/null || dpkg -s google-chrome-stable &>/dev/null; then
        success "Google Chrome is already installed."
        return 0
    fi
    if ! command -v wget &> /dev/null; then
        warn "wget not found. Installing..."
        install_pkg "wget" || return 1
    fi
    if [ "$PKG_MANAGER" != "apt" ]; then
        warn "Chrome install script only supports Debian/Ubuntu for now."
        return 1
    fi

    local deb_url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"
    local tmpdir
    tmpdir=$(mktemp -d) || { error "Failed to create temp directory."; return 1; }
    local deb_file="$tmpdir/google-chrome-stable_current_amd64.deb"

    info "Downloading Google Chrome..."
    if ! wget -q --show-progress -O "$deb_file" "$deb_url"; then
        error "Google Chrome download failed (e.g. network or SSL error)."
        error "You can try: curl -LO $deb_url && sudo apt install ./google-chrome-stable_current_amd64.deb"
        rm -rf "$tmpdir"
        return 1
    fi

    if [ ! -f "$deb_file" ]; then
        error "Downloaded file not found."
        rm -rf "$tmpdir"
        return 1
    fi

    info "Installing Google Chrome package..."
    if ! sudo apt install -y "$deb_file"; then
        error "Google Chrome package installation failed."
        rm -rf "$tmpdir"
        return 1
    fi

    rm -rf "$tmpdir"
    success "Google Chrome installed."
    return 0
}

install_chromium() {
    if command -v chromium &>/dev/null || command -v chromium-browser &>/dev/null; then
        success "Chromium is already installed."
        return 0
    fi
    if [ "$PKG_MANAGER" != "apt" ]; then
        warn "Chromium install only supports Debian/Ubuntu for now."
        return 1
    fi
    # Debian/Ubuntu: package is 'chromium' on newer, 'chromium-browser' on some older
    local pkg="chromium"
    if ! apt-cache show chromium &>/dev/null; then
        pkg="chromium-browser"
    fi
    info "Installing Chromium..."
    if ! sudo apt install -y "$pkg"; then
        error "Chromium package installation failed."
        return 1
    fi
    success "Chromium installed."
    return 0
}

install_edge() {
    if command -v microsoft-edge-stable &>/dev/null || command -v microsoft-edge &>/dev/null || dpkg -s microsoft-edge-stable &>/dev/null; then
        success "Microsoft Edge is already installed."
        return 0
    fi
    if [ "$PKG_MANAGER" != "apt" ]; then
        warn "Microsoft Edge install only supports Debian/Ubuntu for now."
        return 1
    fi
    local deps=(curl gpg)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            warn "$dep not found. Installing..."
            install_pkg "$dep" || return 1
        fi
    done

    # Use same key path as VS Code to avoid "Conflicting values set for option Signed-By" when both are installed
    local key_path="/etc/apt/keyrings/packages.microsoft.gpg"
    if [ ! -f "$key_path" ]; then
        local gpg_file="microsoft-edge.gpg"
        if ! curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$gpg_file"; then
            error "Failed to download or add Microsoft GPG key for Edge."
            rm -f "$gpg_file"
            return 1
        fi
        sudo install -D -o root -g root -m 644 "$gpg_file" "$key_path" || { rm -f "$gpg_file"; return 1; }
        rm -f "$gpg_file"
    fi
    printf '%s\n' "deb [arch=amd64 signed-by=$key_path] https://packages.microsoft.com/repos/edge stable main" | \
        sudo tee /etc/apt/sources.list.d/microsoft-edge.list > /dev/null

    sudo apt update || return 1
    if ! sudo apt install -y microsoft-edge-stable; then
        error "Microsoft Edge package installation failed."
        return 1
    fi
    success "Microsoft Edge installed."
    return 0
}

install_vscode() {
    if command -v code &>/dev/null; then
        success "Visual Studio Code is already installed."
        return 0
    fi
    local deps=(wget gpg)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            warn "$dep not found. Installing..."
            install_pkg "$dep" || return 1
        fi
    done
    if [ "$PKG_MANAGER" != "apt" ]; then
        warn "VS Code install script only supports Debian/Ubuntu for now."
        return 1
    fi

    local gpg_file="packages.microsoft.gpg"
    if ! wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > "$gpg_file"; then
        error "Failed to download or add Microsoft GPG key."
        rm -f "$gpg_file"
        return 1
    fi
    sudo install -D -o root -g root -m 644 "$gpg_file" /etc/apt/keyrings/packages.microsoft.gpg || { rm -f "$gpg_file"; return 1; }
    rm -f "$gpg_file"
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list' || return 1

    sudo apt install -y apt-transport-https || return 1
    sudo apt update || return 1
    if ! sudo apt install -y code; then
        error "VS Code package installation failed."
        return 1
    fi
    success "VS Code installed."
    return 0
}

install_fonts() {
    local deps=(wget unzip)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            warn "$dep not found. Installing..."
            install_pkg "$dep" || return 1
        fi
    done

    info "Installing Hack Nerd Font..."
    local font_dir=~/.local/share/fonts
    mkdir -p "$font_dir" || return 1
    local zip_file="$font_dir/Hack.zip"
    if ! wget -q --show-progress -O "$zip_file" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip; then
        error "Failed to download Hack Nerd Font."
        rm -f "$zip_file"
        return 1
    fi
    ( cd "$font_dir" && unzip -o Hack.zip && rm -f Hack.zip ) || { error "Failed to extract fonts."; return 1; }
    fc-cache -fv
    success "Fonts installed."
    return 0
}
