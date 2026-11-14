
#!/bin/sh
# ==============================================================================
# FluidOS - Advanced System Features Configuration
# OpenZFS, Boot Environments, PF Firewall, Bonjour, Wayland and Wayfire
# ==============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$1"
}

log_success() {
    printf '%b[SUCCESS]%b %s\n' "$GREEN" "$NC" "$1"
}

log_warn() {
    printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"
}

log_error() {
    printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1"
    exit 1
}

if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root."
fi

TARGET_DIR="${1:-/usr/obj/fluidos_root}"

if [ ! -d "$TARGET_DIR" ]; then
    log_error "No existe el sistema objetivo: $TARGET_DIR"
fi

log_info "Configurando FluidOS en: $TARGET_DIR"

# ==============================================================================
# 1. OPENZFS AND BOOT ENVIRONMENTS
# ==============================================================================

log_info "[1/4] Configurando OpenZFS y Boot Environments..."

sysrc -R "$TARGET_DIR" zfs_enable="YES"

mkdir -p "$TARGET_DIR/usr/local/bin"

cat <<'EOF' > "$TARGET_DIR/usr/local/bin/fluidos-update"
#!/bin/sh

# FluidOS Atomic Update System

set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
NEW_BE="FluidOS-Update-${TIMESTAMP}"

echo "==> Creating Boot Environment: $NEW_BE"

bectl create "$NEW_BE"

echo "==> Mounting new Boot Environment..."

MOUNT_POINT=$(bectl mount "$NEW_BE")

cleanup() {
    bectl unmount "$NEW_BE" 2>/dev/null || true
    bectl destroy -f "$NEW_BE" 2>/dev/null || true
}

echo "==> Updating packages..."

if ! pkg -r "$MOUNT_POINT" upgrade -y; then
    echo "Update failed. Removing temporary Boot Environment."
    cleanup
    exit 1
fi

echo "==> Activating new Boot Environment..."

bectl activate "$NEW_BE"

echo "Update completed."
echo "Restart the computer to use the new environment."
EOF

chmod +x "$TARGET_DIR/usr/local/bin/fluidos-update"

log_success "OpenZFS y herramientas de actualización configuradas."

# ==============================================================================
# 2. NETWORK, PF FIREWALL AND BONJOUR
# ==============================================================================

log_info "[2/4] Configurando red, PF y Bonjour..."

sysrc -R "$TARGET_DIR" ifconfig_DEFAULT="DHCP"
sysrc -R "$TARGET_DIR" pf_enable="YES"
sysrc -R "$TARGET_DIR" pf_rules="/etc/pf.conf"
sysrc -R "$TARGET_DIR" pflog_enable="YES"

cat <<'EOF' > "$TARGET_DIR/etc/pf.conf"
# ==============================================================================
# FluidOS PF Firewall
# ==============================================================================

ext_if = egress

table <badhosts> persist

set skip on lo0
set block-policy drop
set loginterface $ext_if
set reassemble yes

scrub in all fragment reassemble

# Default stateful firewall policy
block in all
pass out all keep state

# Bonjour / mDNS
pass in proto udp to any port 5353 keep state
pass out proto udp to any port 5353 keep state

# Controlled ICMP
pass in inet proto icmp all icmp-type echoreq keep state
EOF

log_info "Instalando Avahi, NSS mDNS y DBus..."

if ! pkg -c "$TARGET_DIR" install -y avahi-app nss_mdns dbus; then
    log_warn "No se pudieron instalar todos los paquetes Bonjour."
fi

sysrc -R "$TARGET_DIR" dbus_enable="YES"
sysrc -R "$TARGET_DIR" avahi_daemon_enable="YES"

if [ -f "$TARGET_DIR/etc/nsswitch.conf" ]; then
    if ! grep -q 'mdns' "$TARGET_DIR/etc/nsswitch.conf"; then
        sed -i '' \
            's/hosts: files dns/hosts: files dns mdns/' \
            "$TARGET_DIR/etc/nsswitch.conf"
    fi
fi

log_success "PF y Bonjour configurados."

# ==============================================================================
# 3. WAYLAND, WAYFIRE AND GRAPHICAL ENVIRONMENT
# ==============================================================================

log_info "[3/4] Instalando entorno gráfico Wayland..."

# Paquetes principales.
# light se omite porque no está disponible en el repositorio utilizado.
WAYLAND_PKGS="
wayland
wayfire
wf-shell
sfwbar
seatd
drm-kmod
xwayland
foot
grim
slurp
pamixer
font-awesome
noto-basic
gtk3
gtk4
evdev-proto
"

if ! pkg -c "$TARGET_DIR" install -y $WAYLAND_PKGS; then
    log_warn "Fallo parcial instalando paquetes gráficos."
fi

sysrc -R "$TARGET_DIR" seatd_enable="YES"
sysrc -R "$TARGET_DIR" kld_list="i915kms amdgpu"

# ------------------------------------------------------------------------------
# Create video group if missing
# ------------------------------------------------------------------------------

log_info "Comprobando grupos del sistema..."

if ! chroot "$TARGET_DIR" pw group show video >/dev/null 2>&1; then
    chroot "$TARGET_DIR" pw groupadd video
fi

# ------------------------------------------------------------------------------
# Create FluidOS desktop user
# ------------------------------------------------------------------------------

log_info "Creando usuario FluidOS..."

if ! chroot "$TARGET_DIR" pw user show fluid >/dev/null 2>&1; then

    chroot "$TARGET_DIR" pw useradd fluid \
        -m \
        -g wheel \
        -G video \
        -s /bin/sh \
        -c "FluidOS Desktop User"

    printf '%s\n' "fluidos" |
        chroot "$TARGET_DIR" pw usermod fluid -h 0

else

    log_info "El usuario fluid ya existe."

    chroot "$TARGET_DIR" pw usermod fluid -G video

fi

log_success "Usuario fluid configurado correctamente."

# ==============================================================================
# 4. FLUIDOS DESKTOP CONFIGURATION
# ==============================================================================

log_info "[4/4] Configurando escritorio FluidOS..."

USER_HOME="$TARGET_DIR/home/fluid"

mkdir -p "$USER_HOME/.config/wayfire"
mkdir -p "$USER_HOME/.config/sfwbar"

# ------------------------------------------------------------------------------
# Wayfire configuration
# ------------------------------------------------------------------------------

cat <<'EOF' > "$USER_HOME/.config/wayfire/wayfire.ini"
[core]
plugins = autostart alpha animate blur expo firedecor grid move resize place window-rules wobbly scale

close_top_window = <super> KEY_Q

vwidth = 2
vheight = 2

[autostart]
0_environment = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=Wayfire
1_sfwbar = sfwbar
2_background = wayfire-bg

[animate]
open_animation = zoom
close_animation = fade
duration = 300

[wobbly]
friction = 3.0
spring_k = 8.0

[expo]
toggle = <super> KEY_E

[scale]
toggle = <super> KEY_V

[window-rules]
rule_1 = on created if app_id contains "foot" then maximize
EOF

# ------------------------------------------------------------------------------
# SFWBar top bar and dock
# ------------------------------------------------------------------------------

cat <<'EOF' > "$USER_HOME/.config/sfwbar/sfwbar.config"
# FluidOS Desktop Interface

include("winops.widget")

target "top-bar" {
    layout = top
    height = 28
    style = "topbar"

    item "logo" {
        icon = "distributor-logo-freebsd"
        action = "sfwbar-menu"
    }

    item "taskbar" {
        type = taskbar
        labels = true
    }

    item "spacer" {
        type = flex
    }

    item "clock" {
        type = clock
        format = "%a %b %d %H:%M"
    }
}

target "dock" {
    layout = bottom
    height = 56
    style = "mac-dock"

    item "launcher-term" {
        icon = "utilities-terminal"
        action = "foot"
    }

    item "launcher-files" {
        icon = "system-file-manager"
        action = "foot -e netrik"
    }
}

css {
    .topbar {
        background-color: rgba(30, 30, 30, 0.85);
        color: #ffffff;
        font-family: "Noto Sans", sans-serif;
        font-size: 13px;
    }

    .mac-dock {
        background-color: rgba(255, 255, 255, 0.25);
        border-radius: 16px;
        margin: 6px;
    }
}
EOF

# ------------------------------------------------------------------------------
# Permissions
# ------------------------------------------------------------------------------

chroot "$TARGET_DIR" chown -R fluid:wheel /home/fluid

chmod 755 "$USER_HOME"
chmod 755 "$USER_HOME/.config"
chmod 755 "$USER_HOME/.config/wayfire"
chmod 755 "$USER_HOME/.config/sfwbar"

# ==============================================================================
# FINISH
# ==============================================================================

log_success "=============================================================="
log_success "FluidOS features configured successfully."
log_success "ZFS, Boot Environments, PF, Bonjour and Wayland configured."
log_success "Wayfire and SFWBar desktop configuration generated."
log_success "=============================================================="

log_info "Siguiente paso: ejecutar make-iso.sh"
