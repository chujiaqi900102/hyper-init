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
    
    # Define tools with descriptions
    declare -A tool_descriptions=(
        ["curl"]="Transfer data with URLs (HTTP/HTTPS client)"
        ["wget"]="Network downloader"
        ["git"]="Version control system"
        ["neovim"]="Modern Vim-based text editor"
        ["btop"]="Resource monitor (modern htop replacement)"
        ["tmux"]="Terminal multiplexer"
        ["jq"]="JSON processor"
        ["tree"]="Directory structure viewer"
        ["unzip"]="Archive extraction tool"
        ["fastfetch"]="System information display"
        ["ripgrep"]="Fast text search (modern grep)"
        ["bat"]="Cat with syntax highlighting"
        ["fd"]="Fast file finder (modern find)"
        ["zoxide"]="Smarter cd command"
    )
    
    # Tool list in order
    local tools=(curl wget git neovim btop tmux jq tree unzip fastfetch ripgrep bat fd zoxide)
    
    # Show selection menu
    echo ""
    echo -e "${NEON_CYAN}Select tools to install (space to toggle, enter to confirm):${RESET}"
    echo ""
    echo "  [0] Select All / Deselect All"
    echo ""
    
    local idx=1
    for tool in "${tools[@]}"; do
        printf "  [%2d] %-12s - %s\n" $idx "$tool" "${tool_descriptions[$tool]}"
        ((idx++))
    done
    
    echo ""
    echo "Enter numbers separated by spaces (e.g., '0' for all, '1 3 5' for specific tools):"
    read -p "> " selections
    
    # Parse selections
    local selected_tools=()
    
    # Check if "0" (Select All) is in selections
    if [[ " $selections " =~ " 0 " ]]; then
        selected_tools=("${tools[@]}")
        info "Selected all tools"
    else
        # Parse individual selections
        for num in $selections; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "${#tools[@]}" ]; then
                local tool_idx=$((num - 1))
                selected_tools+=("${tools[$tool_idx]}")
            fi
        done
    fi
    
    if [ ${#selected_tools[@]} -eq 0 ]; then
        warn "No tools selected. Aborting."
        read -n 1 -s -r -p "Press any key to continue..."
        return
    fi
    
    echo ""
    info "Installing ${#selected_tools[@]} tool(s)..."
    
    # Distro-specific package name handling
    local install_list=()
    
    for tool in "${selected_tools[@]}"; do
        case "$tool" in
            bat)
                if [ "$PKG_MANAGER" == "apt" ]; then
                    install_list+=("bat")
                elif [ "$PKG_MANAGER" == "pacman" ]; then
                    install_list+=("bat")
                else
                    install_list+=("bat")
                fi
                ;;
            fd)
                if [ "$PKG_MANAGER" == "apt" ]; then
                    install_list+=("fd-find")
                elif [ "$PKG_MANAGER" == "pacman" ]; then
                    install_list+=("fd")
                else
                    install_list+=("fd-find")
                fi
                ;;
            neovim)
                install_list+=("neovim")
                ;;
            ripgrep)
                install_list+=("ripgrep")
                ;;
            *)
                install_list+=("$tool")
                ;;
        esac
    done
    
    # Install packages
    for pkg in "${install_list[@]}"; do
        install_pkg "$pkg"
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
    
    success "Essential tools installed."
    
    # Version checks for installed tools
    echo ""
    echo -e "${NEON_CYAN}Installed versions:${RESET}"
    local check_tools=(nvim btop bat fd rg zoxide git curl wget jq tree fastfetch)
    for t in "${check_tools[@]}"; do
        if command -v "$t" &> /dev/null; then
            local version_output=$($t --version 2>/dev/null | head -n 1)
            if [ -n "$version_output" ]; then
                echo -e "  ${NEON_GREEN}✓${RESET} $t: $version_output"
            fi
        fi
    done
    
    echo ""
    if [ "$PKG_MANAGER" == "apt" ]; then
        info "Note: Make sure ~/.local/bin is in your PATH"
        echo "  Add this to your ~/.bashrc or ~/.zshrc:"
        echo "  export PATH=\"\$HOME/.local/bin:\$PATH\""
    fi
}
