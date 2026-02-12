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
    
    # 4. Main Menu Loop
    while true; do
        show_menu "MAIN MENU" \
            "1. System Initialization (Mirrors, Update)" \
            "2. Install AI Agents (OpenCode, Claude...)" \
            "3. Shell Experience (Zsh, Oh-My-Zsh)" \
            "4. Dev Environment (Docker, Langs)" \
            "5. Desktop Apps (Chrome, VSCode)" \
            "Q. Quit"
            
        case "$SELECTION" in
            *"System Initialization"*)
                system_menu
                ;;
            *"Install AI Agents"*)
                ai_menu
                ;;
            *"Shell Experience"*)
                shell_menu
                ;;
            *"Dev Environment"*)
                dev_menu
                ;;
            *"Desktop Apps"*)
                desktop_menu
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
