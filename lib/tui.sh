#!/bin/bash

# ==============================================================================
# HyperInit - TUI Engine
# ==============================================================================

# Global variable to store selection
SELECTION=""
# Global array for multi-select results (selected option strings)
SELECTED_ITEMS=()

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

# Multi-select menu: Space toggles, Enter confirms.
# Usage: show_multiselect "Title" "Option1" "Option2" ...
# Result: SELECTED_ITEMS=() array is set to selected option strings.
show_multiselect() {
    local title="$1"
    shift
    local options=("$@")
    local n=${#options[@]}
    local selected=0
    # checked[i]=1 if option i is selected
    local checked=()
    for ((i=0; i<n; i++)); do checked[i]=0; done
    local key=""

    tput civis
    while true; do
        print_banner
        info "$OS_TYPE detected."
        echo ""
        echo -e "${NEON_CYAN}  === $title ===${RESET}"
        echo -e "${BBLACK}  (Space: toggle, Enter: confirm, Arrow keys: move)${RESET}"
        echo ""

        for i in "${!options[@]}"; do
            local check=" "
            [ "${checked[i]}" -eq 1 ] && check="x"
            if [ $i -eq $selected ]; then
                echo -e "  ${NEON_PINK}> [${check}] ${options[$i]}${RESET}"
            else
                echo -e "    [${check}] ${options[$i]}"
            fi
        done
        echo ""

        read -rsn1 key
        if [[ $key == $'\x1b' ]]; then
            read -rsn2 key
            if [[ $key == "[A" ]]; then
                ((selected--))
                [ $selected -lt 0 ] && selected=$((${#options[@]} - 1))
            elif [[ $key == "[B" ]]; then
                ((selected++))
                [ $selected -ge ${#options[@]} ] && selected=0
            fi
        elif [[ $key == " " ]]; then
            checked[$selected]=$((1 - checked[selected]))
        elif [[ $key == "" ]]; then
            break
        fi
    done

    SELECTED_ITEMS=()
    for i in "${!options[@]}"; do
        [ "${checked[i]}" -eq 1 ] && SELECTED_ITEMS+=("${options[$i]}")
    done
    tput cnorm
}
