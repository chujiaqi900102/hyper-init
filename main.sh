#!/bin/bash

# ==============================================================================
# HyperInit - Main Entry Point
# ==============================================================================

# Determine the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Libraries
source "$SCRIPT_DIR/lib/utils.sh"
source "$SCRIPT_DIR/lib/os.sh"
source "$SCRIPT_DIR/lib/tui.sh"
source "$SCRIPT_DIR/modules/system.sh"
source "$SCRIPT_DIR/modules/ai.sh"
source "$SCRIPT_DIR/modules/dev.sh"
source "$SCRIPT_DIR/modules/shell.sh"
source "$SCRIPT_DIR/modules/desktop.sh"

# Main Execution Flow
main() {
    # 1. Print Banner
    print_banner

    # 2. Check Prerequisites
    init_sudo
    
    # 3. Detect OS
    # info "Detecting System Environment..."
    detect_os
    # success "Identified: $OS_TYPE ($OS_VERSION) using $PKG_MANAGER"

    # 3.1 Ensure essential tools (curl)
    if ! command -v curl &> /dev/null; then
        warn "curl is missing. Installing..."
        install_pkg "curl"
    fi
    
    # 3.2 Show first-time user guidance
    if [ ! -f ~/.hyper-init/.initialized ]; then
        echo ""
        info "First time running HyperInit? Here's a recommended workflow:"
        echo -e "  ${NEON_CYAN}1.${RESET} System Initialization → Change Mirrors (faster downloads)"
        echo -e "  ${NEON_CYAN}2.${RESET} System Initialization → Update System Packages"
        echo -e "  ${NEON_CYAN}3.${RESET} Development Environment → Install your tools"
        echo -e "  ${NEON_CYAN}4.${RESET} Shell Customization → Install Zsh + Oh-My-Zsh"
        echo ""
        read -p "Press Enter to continue to main menu..."
        
        # Mark as initialized
        mkdir -p ~/.hyper-init
        touch ~/.hyper-init/.initialized
    fi
    
    # 4. Main Menu Loop
    while true; do
        show_menu "MAIN MENU" \
            "1. System Initialization (Mirrors, Updates, SSH, Firewall)" \
            "2. Development Environment (Docker, Node, Python, Rust, Go)" \
            "3. Shell Customization (Zsh, Oh-My-Zsh, Tools)" \
            "4. Desktop Applications (Chrome, VS Code, Fonts)" \
            "5. AI Agents (OpenCode, Claude, OpenClaw)" \
            "Q. Quit"
            
        case "$SELECTION" in
            *"System Initialization"*)
                system_menu
                ;;
            *"Development Environment"*)
                dev_menu
                ;;
            *"Shell Customization"*)
                shell_menu
                ;;
            *"Desktop Applications"*)
                desktop_menu
                ;;
            *"AI Agents"*)
                ai_menu
                ;;
            *"Quit"*)
                echo -e "${NEON_CYAN}  See you, Space Cowboy...${RESET}"
                exit 0
                ;;
            *)
                echo "Selected: $SELECTION"
                sleep 1
                ;;
        esac
    done
}

main
