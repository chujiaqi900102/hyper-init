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
        "5. Install Essential Tools (curl, git, vim, htop, etc.)" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Install Zsh"*)
            install_zsh
            ;;
        *"Oh-My-Zsh"*)
            install_omz
            ;;
        *"Powerlevel10k"*)
            install_p10k
            ;;
        *"Plugins"*)
            install_zsh_plugins
            ;;
        *"Essential Tools"*)
            install_essentials
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
    else
        info "Installing Oh-My-Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
        success "Oh-My-Zsh installed."
    fi
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
    else
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$theme_dir"
        # Update .zshrc
        sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="powerlevel10k\/powerlevel10k"/' ~/.zshrc
        success "Powerlevel10k installed & enabled."
    fi
}

install_zsh_plugins() {
    # Dependency check: git
    if ! command -v git &> /dev/null; then
        warn "Git is required but not found. Installing..."
        install_pkg "git"
    fi

    local plugin_dir="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
    
    # Auto Suggestions
    if [ ! -d "$plugin_dir/zsh-autosuggestions" ]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "$plugin_dir/zsh-autosuggestions"
    fi
    
    # Syntax Highlighting
    if [ ! -d "$plugin_dir/zsh-syntax-highlighting" ]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$plugin_dir/zsh-syntax-highlighting"
    fi
    
    # Update .zshrc plugins list
    # Simple replacement: plugins=(git) -> plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
    sed -i 's/plugins=(git)/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/' ~/.zshrc
    
    success "Plugins installed and enabled."
}

install_essentials() {
    info "Installing Essential Modern CLI Tools..."
    
    # Modern replacements: 
    # htop -> btop
    # vim -> neovim
    # cat -> bat
    # find -> fd
    # grep -> ripgrep
    # cd -> zoxide
    
    local tools=(curl wget git neovim btop tmux jq tree unzip fastfetch ripgrep zoxide)

    # Distro-specific package name handling
    if [ "$PKG_MANAGER" == "apt" ]; then
        # Debian/Ubuntu Quirks
        install_pkg "bat"
        # Create alias for batcat -> bat if needed
        if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
            # We can't easily alias for the user's shell here without modifying rc files for everyone, 
            # but we can try to symlink if it doesn't exist (risky) or just warn.
            # Local bin is safer
            mkdir -p ~/.local/bin
            ln -sf /usr/bin/batcat ~/.local/bin/bat
        fi
        
        install_pkg "fd-find"
        if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
             mkdir -p ~/.local/bin
             ln -sf /usr/bin/fdfind ~/.local/bin/fd
        fi

    elif [ "$PKG_MANAGER" == "pacman" ]; then
        # Arch uses standard names usually
        tools+=(bat fd)
    else
        # RHEL/Fedora
        tools+=(bat fd-find)
    fi

    for tool in "${tools[@]}"; do
        install_pkg "$tool"
    done
    
    success "Essential tools installed."
    
    # Version checks
    local check_tools=(nvim btop bat fd rg zoxide)
    for t in "${check_tools[@]}"; do
        if command -v "$t" &> /dev/null; then
             echo -e "${NEON_CYAN}$t Version:${RESET} $($t --version | head -n 1)"
        fi
    done
}
