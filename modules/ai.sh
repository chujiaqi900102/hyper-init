#!/bin/bash

# ==============================================================================
# HyperInit - AI Module
# ==============================================================================

ai_menu() {
    show_menu "AI AGENT INSTALLATION" \
        "1. Install OpenCode (Terminal Coding Agent)" \
        "2. Install Claude Code (Anthropic CLI)" \
        "3. Install OpenClaw (Autonomous Agent)" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"OpenCode"*)
            install_opencode
            ;;
        *"Claude Code"*)
            install_claude
            ;;
        *"OpenClaw"*)
            install_openclaw
            ;;
        *"Back"*)
            return
            ;;
    esac
    ai_menu
}

install_opencode() {
    info "Installing OpenCode..."
    # Official install script
    curl -fsSL https://opencode.ai/install | bash
    
    if [ $? -eq 0 ]; then
        success "OpenCode installed successfully!"
        info "Run 'opencode' to start."
    else
        error "OpenCode installation failed."
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

install_claude() {
    info "Installing Claude Code..."
    # Requires Node.js
    if ! command -v node &> /dev/null; then
        warn "Node.js is required but not found."
        read -p "Install Node.js (via NVM) now? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            install_node
            # Check again
            if ! command -v node &> /dev/null; then
                # Reload nvm if needed or check why
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            fi
        else
            error "Cannot install Claude Code without Node.js."
            return 1
        fi
    fi
    
    run_task "Installing @anthropic-ai/claude-code" npm install -g @anthropic-ai/claude-code
    
    if [ $? -eq 0 ]; then
        success "Claude Code installed!"
        info "Run 'claude' to authenticate."
    fi
    read -n 1 -s -r -p "Press any key to continue..."
}

install_openclaw() {
    info "Installing OpenClaw..."
     if ! command -v node &> /dev/null; then
        warn "Node.js is required but not found."
        read -p "Install Node.js (via NVM) now? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            install_node
            # Check again
            if ! command -v node &> /dev/null; then
                export NVM_DIR="$HOME/.nvm"
                [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
            fi
        else
            error "Cannot install OpenClaw without Node.js."
            return 1
        fi
    fi

    run_task "Installing OpenClaw" npm install -g openclaw@latest
    
    info "Starting OpenClaw Onboarding..."
    openclaw onboard --install-daemon
    
    read -n 1 -s -r -p "Press any key to continue..."
}
