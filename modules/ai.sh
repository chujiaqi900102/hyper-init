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
        warn "Node.js is required but not found. Please install it from the Dev menu first."
        read -n 1 -s -r -p "Press any key to continue..."
        return
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
        warn "Node.js is required but not found. Please install it from the Dev menu first."
        return
    fi

    run_task "Installing OpenClaw" npm install -g openclaw@latest
    
    info "Starting OpenClaw Onboarding..."
    openclaw onboard --install-daemon
    
    read -n 1 -s -r -p "Press any key to continue..."
}
