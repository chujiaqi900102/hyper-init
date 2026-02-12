#!/bin/bash

# ==============================================================================
# HyperInit - Database (PostgreSQL, MySQL/MariaDB, Redis)
# ==============================================================================
# Currently supports Debian/Ubuntu (apt), Fedora/RHEL (dnf), Arch (pacman).
# ==============================================================================

database_menu() {
    show_menu "DATABASE" \
        "1. Install PostgreSQL" \
        "2. Install MySQL/MariaDB" \
        "3. Install Redis" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"PostgreSQL"*)
            install_postgresql
            ;;
        *"MySQL/MariaDB"*)
            install_mariadb
            ;;
        *"Redis"*)
            install_redis
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    database_menu
}

install_postgresql() {
    info "Installing PostgreSQL..."

    case "$PKG_MANAGER" in
        apt)
            install_pkg "postgresql" || return 1
            install_pkg "postgresql-contrib" || true
            if command -v systemctl &>/dev/null; then
                run_task "Enabling PostgreSQL" sudo systemctl enable postgresql
                run_task "Starting PostgreSQL" sudo systemctl start postgresql
            fi
            ;;
        dnf)
            install_pkg "postgresql-server" || return 1
            install_pkg "postgresql-contrib" || true
            run_task "Initializing PostgreSQL database" sudo postgresql-setup --initdb
            run_task "Enabling PostgreSQL" sudo systemctl enable postgresql
            run_task "Starting PostgreSQL" sudo systemctl start postgresql
            ;;
        pacman)
            install_pkg "postgresql" || return 1
            run_task "Initializing PostgreSQL (initdb)" sudo -u postgres initdb -D /var/lib/postgres/data
            run_task "Enabling PostgreSQL" sudo systemctl enable postgresql
            run_task "Starting PostgreSQL" sudo systemctl start postgresql
            ;;
        *)
            warn "PostgreSQL installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    success "PostgreSQL installed."
    if command -v psql &>/dev/null; then
        echo -e "${NEON_CYAN}psql:${RESET} $(psql --version)"
    fi
    info "Connect as system user: sudo -u postgres psql (or peer auth as postgres)."
}

install_mariadb() {
    info "Installing MySQL/MariaDB..."

    local pkg_server=""
    local pkg_client=""
    case "$PKG_MANAGER" in
        apt)
            pkg_server="mariadb-server"
            pkg_client="mariadb-client"
            ;;
        dnf)
            pkg_server="mariadb-server"
            pkg_client="mariadb"
            ;;
        pacman)
            pkg_server="mariadb"
            pkg_client="mariadb-clients"
            ;;
        *)
            warn "MySQL/MariaDB installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    install_pkg "$pkg_server" || return 1
    install_pkg "$pkg_client" || true

    if command -v systemctl &>/dev/null; then
        run_task "Enabling MariaDB/MySQL" sudo systemctl enable mariadb
        run_task "Starting MariaDB/MySQL" sudo systemctl start mariadb
    fi

    # Security initialization (Debian/Ubuntu: mysql_secure_installation; some distros use mariadb-secure-installation)
    if command -v mysql_secure_installation &>/dev/null; then
        info "Run 'sudo mysql_secure_installation' to set root password and secure the installation."
        read -p "Run mysql_secure_installation now? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            sudo mysql_secure_installation
        fi
    elif command -v mariadb-secure-installation &>/dev/null; then
        info "Run 'sudo mariadb-secure-installation' to set root password and secure the installation."
        read -p "Run mariadb-secure-installation now? [Y/n] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
            sudo mariadb-secure-installation
        fi
    fi

    success "MySQL/MariaDB installed."
    if command -v mysql &>/dev/null; then
        echo -e "${NEON_CYAN}mysql:${RESET} $(mysql --version)"
    fi
}

install_redis() {
    info "Installing Redis..."

    local pkg=""
    case "$PKG_MANAGER" in
        apt)
            pkg="redis-server"
            ;;
        dnf|pacman)
            pkg="redis"
            ;;
        *)
            warn "Redis installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    install_pkg "$pkg" || return 1

    if command -v systemctl &>/dev/null; then
        run_task "Enabling Redis" sudo systemctl enable redis
        run_task "Starting Redis" sudo systemctl start redis
    fi
    # Some distros use redis-server as service name
    if ! systemctl is-active --quiet redis 2>/dev/null && command -v systemctl &>/dev/null; then
        sudo systemctl enable redis-server 2>/dev/null || true
        sudo systemctl start redis-server 2>/dev/null || true
    fi

    success "Redis installed."
    if command -v redis-cli &>/dev/null; then
        echo -e "${NEON_CYAN}redis-cli:${RESET} $(redis-cli --version)"
    fi
}
