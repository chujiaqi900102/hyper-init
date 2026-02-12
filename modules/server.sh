#!/bin/bash

# ==============================================================================
# HyperInit - Web Server (Nginx, Apache)
# ==============================================================================
# Currently supports Debian/Ubuntu (apt), Fedora/RHEL (dnf), Arch (pacman).
# ==============================================================================

server_menu() {
    show_menu "WEB SERVER" \
        "1. Install Nginx" \
        "2. Install Apache" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Nginx"*)
            install_nginx
            ;;
        *"Apache"*)
            install_apache
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    server_menu
}

install_nginx() {
    info "Installing Nginx..."

    local pkg="nginx"
    case "$PKG_MANAGER" in
        apt|dnf|pacman)
            install_pkg "$pkg" || return 1
            ;;
        *)
            warn "Nginx installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    if command -v systemctl &>/dev/null; then
        run_task "Enabling Nginx" sudo systemctl enable nginx
        run_task "Starting Nginx" sudo systemctl start nginx
    fi

    success "Nginx installed."
    if command -v nginx &>/dev/null; then
        echo -e "${NEON_CYAN}nginx:${RESET} $(nginx -v 2>&1)"
    fi
    info "Default site: /etc/nginx/sites-available/default (apt) or /etc/nginx/nginx.conf (dnf/pacman)."
}

install_apache() {
    info "Installing Apache HTTP Server..."

    local pkg_server=""
    case "$PKG_MANAGER" in
        apt)
            pkg_server="apache2"
            ;;
        dnf|pacman)
            pkg_server="httpd"
            ;;
        *)
            warn "Apache installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    install_pkg "$pkg_server" || return 1

    if command -v systemctl &>/dev/null; then
        local svc="$pkg_server"
        run_task "Enabling Apache" sudo systemctl enable "$svc"
        run_task "Starting Apache" sudo systemctl start "$svc"
    fi

    success "Apache installed."
    if command -v apache2 &>/dev/null; then
        echo -e "${NEON_CYAN}apache2:${RESET} $(apache2 -v 2>&1 | head -n1)"
    elif command -v httpd &>/dev/null; then
        echo -e "${NEON_CYAN}httpd:${RESET} $(httpd -v 2>&1 | head -n1)"
    fi
    info "Config: /etc/apache2/ (apt) or /etc/httpd/ (dnf/pacman)."
}
