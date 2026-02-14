#!/bin/bash

# ==============================================================================
# HyperInit - AI Module
# ==============================================================================

ai_menu() {
    show_menu "AI AGENT INSTALLATION" \
        "1. Install OpenCode (Terminal Coding Agent)" \
        "2. Install Claude Code (Anthropic CLI)" \
        "3. Install OpenClaw (Autonomous Agent)" \
        "4. Install VS Code/Cursor AI Extensions (Continue.dev, Codeium)" \
        "5. Install Ollama (Local LLM runtime)" \
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
        *"VS Code/Cursor AI Extensions"*|*"Continue.dev"*|*"Codeium"*)
            install_vscode_ai_extensions
            ;;
        *"Ollama"*)
            install_ollama
            ;;
        *"Back"*)
            return
            ;;
    esac
    ai_menu
}

install_opencode() {
    local install_success=false
    
    info "尝试: 官方安装脚本..."
    if curl -fsSL https://opencode.ai/install | bash 2>/dev/null; then
        install_success=true
    fi
    
    if [ "$install_success" = false ]; then
        info "尝试: npm install -g opencode-ai..."
        if npm install -g opencode-ai 2>/dev/null; then
            install_success=true
        fi
    fi
    
    if [ "$install_success" = false ]; then
        info "尝试: bun install -g opencode-ai..."
        if bun install -g opencode-ai 2>/dev/null; then
            install_success=true
        fi
    fi
    
    if [ "$install_success" = false ]; then
        info "尝试: pnpm install -g opencode-ai..."
        if pnpm install -g opencode-ai 2>/dev/null; then
            install_success=true
        fi
    fi
    
    if [ "$install_success" = false ] && [ "$(uname)" = "Darwin" ]; then
        info "尝试: brew install anomalyco/tap/opencode..."
        if brew install anomalyco/tap/opencode 2>/dev/null; then
            install_success=true
        fi
    fi
    
    if [ "$install_success" = true ]; then
        success "OpenCode 安装成功!"
        info "运行 'opencode' 启动。"
    else
        error "所有自动安装方法均失败。"
        info "请手动安装: https://opencode.ai/docs/zh-cn"
    fi
    read -n 1 -s -r -p "按任意键继续..."
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

install_vscode_ai_extensions() {
    info "Installing AI extensions (Continue.dev, Codeium) for VS Code or Cursor..."

    local code_cmd=""
    if command -v code &>/dev/null; then
        code_cmd="code"
    elif command -v cursor &>/dev/null; then
        # Cursor may support --install-extension when invoked as cursor
        code_cmd="cursor"
    else
        warn "Neither 'code' (VS Code) nor 'cursor' CLI found in PATH."
        info "Install VS Code or Cursor and ensure the CLI is in your PATH (e.g. Install 'code' command from VS Code Command Palette)."
        read -n 1 -s -r -p "Press any key to continue..."
        return 1
    fi

    run_task "Installing Continue.dev extension" "$code_cmd" --install-extension Continue.continue --force
    run_task "Installing Codeium extension" "$code_cmd" --install-extension Codeium.codeium --force

    success "AI extensions installed. Restart VS Code/Cursor if needed."
    read -n 1 -s -r -p "Press any key to continue..."
}

install_ollama() {
    info "Installing Ollama (local LLM runtime)..."

    if command -v ollama &>/dev/null; then
        warn "Ollama is already installed: $(ollama --version 2>/dev/null || ollama -v 2>/dev/null)"
        read -p "Reinstall/update? [y/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            read -n 1 -s -r -p "Press any key to continue..."
            return 0
        fi
    fi

    run_task "Running Ollama install script" bash -c "curl -fsSL https://ollama.com/install.sh | sh"
    if [ $? -ne 0 ]; then
        error "Ollama installation failed."
        read -n 1 -s -r -p "Press any key to continue..."
        return 1
    fi

    if command -v systemctl &>/dev/null && systemctl list-unit-files | grep -q ollama; then
        run_task "Enabling Ollama service" sudo systemctl enable ollama
        run_task "Starting Ollama service" sudo systemctl start ollama
    fi

    success "Ollama installed."
    if command -v ollama &>/dev/null; then
        echo -e "${NEON_CYAN}ollama:${RESET} $(ollama --version 2>/dev/null || echo 'installed')"
    fi
    info "Run 'ollama run <model>' to pull and run a model (e.g. ollama run llama3)."
    read -n 1 -s -r -p "Press any key to continue..."
}
