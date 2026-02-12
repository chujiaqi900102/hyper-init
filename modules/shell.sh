#!/bin/bash

# ==============================================================================
# HyperInit - Shell Customization
# ==============================================================================

shell_menu() {
    show_menu "SHELL CUSTOMIZATION" \
        "1. Install Zsh" \
        "2. Install Oh-My-Zsh (Automated)" \
        "3. Install Powerlevel10k Theme" \
        "4. Install Zsh Plugins (Autosuggestions, Syntax Highlighting)" \
        "5. Install Essential CLI Tools (Interactive Selection)" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Install Zsh"*)
            install_zsh || error "Zsh installation failed."
            ;;
        *"Oh-My-Zsh"*)
            install_omz || error "Oh-My-Zsh installation failed."
            ;;
        *"Powerlevel10k"*)
            install_p10k || error "Powerlevel10k installation failed."
            ;;
        *"Plugins"*)
            install_zsh_plugins || error "Zsh plugins installation failed."
            ;;
        *"Essential Tools"*)
            install_essentials || error "Essential CLI tools installation failed."
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    shell_menu
}

install_zsh() {
    # Check if zsh is installed
    if ! command -v zsh &> /dev/null; then
        warn "Zsh not found. Installing..."
        install_pkg "zsh"
    else 
        info "Zsh is already installed."
    fi

    local zsh_path=$(which zsh)
    if [ "$SHELL" != "$zsh_path" ]; then
        info "Setting Zsh as default shell..."
        # chsh might require password, or might not work in non-interactive environments
        # using sudo chsh for the current user
        sudo chsh -s "$zsh_path" "$USER"
        success "Zsh set as default shell. Logout/Login might be required."
    else
        info "Zsh is already the default shell."
    fi
}

install_omz() {
    # Dependency check: Zsh
    if ! command -v zsh &> /dev/null; then
        warn "Zsh is required for Oh-My-Zsh but is not installed."
        read -p "Install Zsh now? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            install_zsh
        else
            error "Cannot install Oh-My-Zsh without Zsh."
            return 1
        fi
    fi

    if [ -d "$HOME/.oh-my-zsh" ]; then
        warn "Oh-My-Zsh is already installed."
        return 0
    fi
    info "Installing Oh-My-Zsh..."
    if ! sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended; then
        error "Oh-My-Zsh install script failed (e.g. network error)."
        return 1
    fi
    success "Oh-My-Zsh installed."
    return 0
}

install_p10k() {
    # Dependency check: git
    if ! command -v git &> /dev/null; then
        warn "Git is required but not found. Installing..."
        install_pkg "git"
    fi

    local theme_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    if [ -d "$theme_dir" ]; then
        warn "Powerlevel10k already installed."
        return 0
    fi
    if ! git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"; then
        error "Powerlevel10k clone failed (e.g. network error)."
        return 1
    fi
    sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
    success "Powerlevel10k installed & enabled."
    return 0
}

install_zsh_plugins() {
    # Dependency check: git
    if ! command -v git &> /dev/null; then
        warn "Git is required but not found. Installing..."
        install_pkg "git"
    fi

    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    
    local failed=0
    if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions" || failed=1
    fi
    if [ ! -d "$plugin_dir/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir/zsh-syntax-highlighting" || failed=1
    fi
    if [ $failed -eq 1 ]; then
        error "One or more plugin clones failed."
        return 1
    fi
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
    success "Plugins installed and enabled."
    return 0
}

# Tool list and distro-specific package names
ESSENTIAL_TOOLS=(curl wget git neovim btop tmux jq tree unzip fastfetch ripgrep bat fd zoxide)

# Map tool name to package name for current distro
tool_to_pkg() {
    local tool=$1
    case "$tool" in
        bat)   [ "$PKG_MANAGER" == "apt" ] && echo "bat" || echo "bat" ;;
        fd)    [ "$PKG_MANAGER" == "apt" ] && echo "fd-find" || { [ "$PKG_MANAGER" == "pacman" ] && echo "fd" || echo "fd-find"; } ;;
        *)     echo "$tool" ;;
    esac
}

install_essentials() {
    local selected_tools=()
    # Step 1: Show submenu so user can choose "All", "Minimal", or "Custom (multi-select)"
    show_menu "ESSENTIAL CLI TOOLS - CHOOSE SET" \
        "1. Install All tools" \
        "2. Minimal set (curl, wget, git, neovim, tmux)" \
        "3. Custom - select tools (multi-select)" \
        "B. Back"

    case "$SELECTION" in
        *"Back"*)
            return 0
            ;;
        *"Install All"*)
            selected_tools=("${ESSENTIAL_TOOLS[@]}")
            ;;
        *"Minimal"*)
            selected_tools=(curl wget git neovim tmux)
            ;;
        *"Custom"*)
            # Step 2: Multi-select TUI for individual tools
            show_multiselect "Select CLI tools to install (Space=toggle, Enter=confirm)" "${ESSENTIAL_TOOLS[@]}"
            selected_tools=("${SELECTED_ITEMS[@]}")
            if [ ${#selected_tools[@]} -eq 0 ]; then
                warn "No tools selected. Aborting."
                read -n 1 -s -r -p "Press any key to continue..."
                return 0
            fi
            ;;
        *)
            return 0
            ;;
    esac

    info "Installing ${#selected_tools[@]} tool(s)..."
    local failed=0
    local install_list=()
    for tool in "${selected_tools[@]}"; do
        install_list+=("$(tool_to_pkg "$tool")")
    done

    for pkg in "${install_list[@]}"; do
        install_pkg "$pkg" || failed=1
    done

    # Create symlinks for Debian/Ubuntu quirks
    if [ "$PKG_MANAGER" == "apt" ]; then
        if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
            mkdir -p ~/.local/bin
            ln -sf /usr/bin/batcat ~/.local/bin/bat
            info "Created symlink: bat -> batcat"
        fi
        if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
            mkdir -p ~/.local/bin
            ln -sf /usr/bin/fdfind ~/.local/bin/fd
            info "Created symlink: fd -> fdfind"
        fi
    fi

    if [ $failed -eq 1 ]; then
        error "One or more packages failed to install. See errors above."
        return 1
    fi
    success "Essential tools installed."

    echo ""
    echo -e "${NEON_CYAN}Installed versions:${RESET}"
    local check_tools=(nvim btop bat fd rg zoxide git curl wget jq tree fastfetch)
    for t in "${check_tools[@]}"; do
        if command -v "$t" &> /dev/null; then
            local version_output=$($t --version 2>/dev/null | head -n 1)
            [ -n "$version_output" ] && echo -e "  ${NEON_GREEN}✓${RESET} $t: $version_output"
        fi
    done
    echo ""
    if [ "$PKG_MANAGER" == "apt" ]; then
        info "Note: Make sure ~/.local/bin is in your PATH"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
    return 0
}
