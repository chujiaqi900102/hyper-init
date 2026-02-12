#!/bin/bash

# ==============================================================================
# HyperInit - Core Utilities
# ==============================================================================

# ------------------------------------------------------------------------------
# Colors & Styling (Cyberpunk Theme)
# ------------------------------------------------------------------------------
# Reset
RESET='\033[0m'

# Regular Colors
BLACK='\033[0;30m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[0;37m'

# Bold
BBLACK='\033[1;30m'
BRED='\033[1;31m'
BGREEN='\033[1;32m'
BYELLOW='\033[1;33m'
BBLUE='\033[1;34m'
BPURPLE='\033[1;35m'
BCYAN='\033[1;36m'
BWHITE='\033[1;37m'

# Neon / High Intensity
NEON_PINK='\033[1;95m'
NEON_CYAN='\033[1;96m'
NEON_GREEN='\033[1;92m'
NEON_YELLOW='\033[1;93m'

# Icons
ICON_ROCKET="🚀"
ICON_CHECK="✔"
ICON_ERROR="✖"
ICON_INFO="ℹ"
ICON_GEAR="⚙"
ICON_PKG="📦"

# ------------------------------------------------------------------------------
# Logging & Output
# ------------------------------------------------------------------------------

print_banner() {
    clear
    echo -e "${NEON_CYAN}"
    cat << "EOF"
  _   _                      ___       _ _   
 | | | |_   _ _ __   ___ _ _|_ _|_ __ (_) |_ 
 | |_| | | | | '_ \ / _ \ '__| || '_ \| | __|
 |  _  | |_| | |_) |  __/ |  | || | | | | |_ 
 |_| |_|\__, | .__/ \___|_| |___|_| |_|_|\__|
        |___/|_|                             
EOF
    echo -e "${RESET}"
    echo -e "${PURPLE}  >>> The Cyberpunk Linux Setup Tool <<<${RESET}"
    echo -e "${BBLACK}  ---------------------------------------${RESET}"
    echo -e "${BBLUE}  ::: HyperInit v0.1.0 :::${RESET}"
    echo ""
}

info() {
    echo -e "${BLUE}${ICON_INFO}  ${1}${RESET}"
}

success() {
    echo -e "${NEON_GREEN}${ICON_CHECK}  ${1}${RESET}"
}

warn() {
    echo -e "${YELLOW}⚠  ${1}${RESET}"
}

error() {
    echo -e "${RED}${ICON_ERROR}  ${1}${RESET}" >&2
}

critical() {
    echo -e "${BRED}🚨 CRITICAL: ${1}${RESET}" >&2
    exit 1
}

# ------------------------------------------------------------------------------
# Animations
# ------------------------------------------------------------------------------

show_spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    
    # Hide cursor
    tput civis
    
    while [ -d /proc/$pid ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    
    # Restore cursor
    tput cnorm
}

# Usage: run_task "Description" command [args...]
run_task() {
    local message="$1"
    shift
    # Store the command array properly
    local cmd=("$@")

    echo -ne "${NEON_CYAN}${ICON_GEAR}  ${message}...${RESET} "
    
    # Create temp log file
    local log_file=$(mktemp)
    
    # Run command in background
    "${cmd[@]}" > "$log_file" 2>&1 &
    local pid=$!
    
    # Show spinner
    show_spinner $pid
    
    wait $pid
    local exit_code=$?
    
    # Clear "..." and spinner
    # printf "\r\033[K"
    
    if [ $exit_code -eq 0 ]; then
        echo -e "\r${NEON_GREEN}${ICON_CHECK}  ${message} ${BBLACK}[DONE]${RESET}        "
        rm "$log_file"
        return 0
    else
        echo -e "\r${RED}${ICON_ERROR}  ${message} ${BRED}[FAILED]${RESET}       "
        echo -e "${RED}Error Details:${RESET}"
        cat "$log_file"
        rm "$log_file"
        return $exit_code
    fi
}
