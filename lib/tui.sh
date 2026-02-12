#!/bin/bash

# ==============================================================================
# HyperInit - TUI Engine
# ==============================================================================

# Global variable to store selection
SELECTION=""

# Interactive Menu Function
# Usage: show_menu "Title" "Option1" "Option2" ...
show_menu() {
    local title="$1"
    shift
    local options=("$@")
    local selected=0
    local key=""

    # Hide cursor
    tput civis

    while true; do
        # Clear screen below header (simple hack: clear all and reprint banner)
        # For better performance, we'd use tput, but this is simple.
        print_banner
        info "$OS_TYPE detected."
        echo ""
        echo -e "${NEON_CYAN}  === $title ===${RESET}"
        echo ""

        for i in "${!options[@]}"; do
            if [ $i -eq $selected ]; then
                echo -e "  ${NEON_PINK}> [${options[$i]}]${RESET}"
            else
                echo -e "    ${options[$i]}"
            fi
        done
        echo ""
        echo -e "${BBLACK}  (Use Arrow Keys to Move, Enter to Select)${RESET}"

        # Read input
        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key == "[A" ]]; then # Up
                ((selected--))
                if [ $selected -lt 0 ]; then selected=$((${#options[@]} - 1)); fi
            elif [[ $key == "[B" ]]; then # Down
                ((selected++))
                if [ $selected -ge ${#options[@]} ]; then selected=0; fi
            fi
        elif [[ $key == "" ]]; then # Enter
            SELECTION="${options[$selected]}"
            break
        fi
    done

    # Restore cursor
    tput cnorm
}
