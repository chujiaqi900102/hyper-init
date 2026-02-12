#!/bin/bash

# ==============================================================================
# HyperInit - Monitoring (Prometheus, Grafana, Node Exporter)
# ==============================================================================
# Prometheus + node_exporter: distro packages where available.
# Grafana: official repo for apt/dnf, distro package for pacman.
# ==============================================================================

monitoring_menu() {
    show_menu "MONITORING" \
        "1. Install Prometheus" \
        "2. Install Node Exporter" \
        "3. Install Grafana" \
        "B. Back to Main Menu"

    case "$SELECTION" in
        *"Prometheus"*)
            install_prometheus
            ;;
        *"Node Exporter"*)
            install_node_exporter
            ;;
        *"Grafana"*)
            install_grafana
            ;;
        *"Back"*)
            return
            ;;
    esac
    read -n 1 -s -r -p "Press any key to continue..."
    monitoring_menu
}

install_node_exporter() {
    info "Installing Node Exporter (Prometheus metrics for the host)..."

    local pkg=""
    case "$PKG_MANAGER" in
        apt)
            pkg="prometheus-node-exporter"
            ;;
        dnf)
            pkg="prometheus-node_exporter"
            ;;
        pacman)
            pkg="prometheus-node-exporter"
            ;;
        *)
            warn "Node Exporter installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    install_pkg "$pkg" || return 1

    if command -v systemctl &>/dev/null; then
        run_task "Enabling Node Exporter" sudo systemctl enable prometheus-node-exporter 2>/dev/null || sudo systemctl enable prometheus-node_exporter 2>/dev/null || true
        run_task "Starting Node Exporter" sudo systemctl start prometheus-node-exporter 2>/dev/null || sudo systemctl start prometheus-node_exporter 2>/dev/null || true
    fi

    success "Node Exporter installed."
    if command -v node_exporter &>/dev/null; then
        echo -e "${NEON_CYAN}node_exporter:${RESET} $(node_exporter --version 2>&1 | head -n1)"
    fi
    info "Metrics exposed on port 9100 by default. Add this target to Prometheus scrape_configs."
}

install_prometheus() {
    info "Installing Prometheus..."

    case "$PKG_MANAGER" in
        apt|dnf|pacman)
            install_pkg "prometheus" || return 1
            ;;
        *)
            warn "Prometheus installation currently supports apt, dnf, and pacman only."
            return 1
            ;;
    esac

    if command -v systemctl &>/dev/null; then
        run_task "Enabling Prometheus" sudo systemctl enable prometheus
        run_task "Starting Prometheus" sudo systemctl start prometheus
    fi

    success "Prometheus installed."
    if command -v prometheus &>/dev/null; then
        echo -e "${NEON_CYAN}prometheus:${RESET} $(prometheus --version 2>&1 | head -n1)"
    fi
    info "Config: /etc/prometheus/prometheus.yml (or /etc/prometheus.yml). Default port 9090."
}

install_grafana() {
    info "Installing Grafana..."

    if [ "$PKG_MANAGER" = "apt" ]; then
        run_task "Installing prerequisites" sudo apt-get install -y apt-transport-https wget
        sudo mkdir -p /etc/apt/keyrings
        run_task "Adding Grafana GPG key" bash -c "wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor | sudo tee /etc/apt/keyrings/grafana.gpg > /dev/null"
        echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" | sudo tee /etc/apt/sources.list.d/grafana.list > /dev/null
        run_task "Updating package index" sudo apt-get update
        install_pkg "grafana" || return 1
    elif [ "$PKG_MANAGER" = "dnf" ]; then
        sudo tee /etc/yum.repos.d/grafana.repo > /dev/null <<'GRAFANA_REPO'
[grafana]
name=grafana
baseurl=https://rpm.grafana.com
repo_gpgcheck=1
enabled=1
gpgcheck=1
gpgkey=https://rpm.grafana.com/gpg.key
sslverify=1
sslcacert=/etc/pki/tls/certs/ca-bundle.crt
GRAFANA_REPO
        run_task "Updating package index" sudo dnf makecache
        install_pkg "grafana" || return 1
    elif [ "$PKG_MANAGER" = "pacman" ]; then
        install_pkg "grafana" || return 1
    else
        warn "Grafana installation currently supports apt, dnf, and pacman only."
        return 1
    fi

    if command -v systemctl &>/dev/null; then
        run_task "Enabling Grafana" sudo systemctl enable grafana-server
        run_task "Starting Grafana" sudo systemctl start grafana-server
    fi

    success "Grafana installed."
    if command -v grafana-server &>/dev/null; then
        echo -e "${NEON_CYAN}grafana-server:${RESET} $(grafana-server -v 2>&1 | head -n1)"
    fi
    info "Grafana UI: http://localhost:3000 (default login admin/admin)."
}
