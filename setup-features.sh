
#!/bin/sh
# ==============================================================================
# FluidOS - Configuracion de Caracteristicas Avanzadas
# OpenZFS, Boot Environments, PF, Bonjour y Wayfire
# ==============================================================================

set -e

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo "[INFO] $1"
}

log_success() {
    echo "[SUCCESS] $1"
}

log_warn() {
    echo "[WARN] $1"
}

log_error() {
    echo "[ERROR] $1"
    exit 1
}

# Comprobar root
if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root."
fi

# Directorio del sistema objetivo
TARGET_DIR="${1:-/usr/obj/fluidos_root}"

log_info "Configurando FluidOS en: ${TARGET_DIR}"

if [ ! -d "${TARGET_DIR}" ]; then
    log_error "No existe el sistema base: ${TARGET_DIR}"
fi

# CORRECCION: crear los directorios necesarios
# antes de escribir los archivos de configuracion.
mkdir -p "${TARGET_DIR}/usr/local/bin"
mkdir -p "${TARGET_DIR}/etc"
mkdir -p "${TARGET_DIR}/home/fluid"

# ==============================================================================
# 1. OPENZFS Y BOOT ENVIRONMENTS
# ==============================================================================

log_info "[1/4] Configurando OpenZFS y Boot Environments..."

sysrc -R "${TARGET_DIR}" zfs_enable="YES"

# Herramienta de actualizacion atomica de FluidOS
cat << 'EOF' > "${TARGET_DIR}/usr/local/bin/fluidos-update"
#!/bin/sh

# FluidOS Atomic System Update Tool
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
NEW_BE="FluidOS-Update-${TIMESTAMP}"

echo "==> Creando nuevo Boot Environment: ${NEW_BE}"

bectl create "${NEW_BE}"

echo "==> Montando nuevo Boot Environment..."

MOUNT_POINT=$(bectl mount "${NEW_BE}")

echo "==> Aplicando actualizaciones..."

if ! pkg -r "${MOUNT_POINT}" upgrade -y; then
    echo "ERROR: Fallo en la actualizacion."

    bectl unmount "${NEW_BE}" || true
    bectl destroy -f "${NEW_BE}" || true

    exit 1
fi

echo "==> Activando nuevo Boot Environment..."

bectl activate "${NEW_BE}"

echo "==> Actualizacion completada."
echo "==> Reinicie FluidOS para aplicar los cambios."

EOF

chmod +x "${TARGET_DIR}/usr/local/bin/fluidos-update"

log_success "ZFS y herramienta de actualizacion configurados."

# ==============================================================================
# 2. RED, FIREWALL PF Y BONJOUR
# ==============================================================================

log_info "[2/4] Configurando red, PF y Bonjour..."

sysrc -R "${TARGET_DIR}" defaultrouter=""
sysrc -R "${TARGET_DIR}" ifconfig_DEFAULT="DHCP"

sysrc -R "${TARGET_DIR}" pf_enable="YES"
sysrc -R "${TARGET_DIR}" pf_rules="/etc/pf.conf"
sysrc -R "${TARGET_DIR}" pflog_enable="YES"

# Configuracion del firewall
cat << 'EOF' > "${TARGET_DIR}/etc/pf.conf"

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

block in all
pass out all keep state

# Bonjour / mDNS
pass in proto udp to any port 5353 keep state
pass out proto udp to any port 5353 keep state

# ICMP
pass in inet proto icmp all icmp-type echoreq keep state

EOF

log_info "Instalando Avahi, mDNS y D-Bus..."

if ! pkg -c "${TARGET_DIR}" install -y avahi-app nss_mdns dbus; then
    log_warn "No se pudieron instalar todos los paquetes Avahi."
fi

sysrc -R "${TARGET_DIR}" dbus_enable="YES"
sysrc -R "${TARGET_DIR}" avahi_daemon_enable="YES"

# Configuracion NSS
if [ -f "${TARGET_DIR}/etc/nsswitch.conf" ]; then
    sed -i '' 's/hosts: files dns/hosts: files dns mdns/g' \
        "${TARGET_DIR}/etc/nsswitch.conf"
fi

log_success "Firewall PF y Bonjour configurados."

# ==============================================================================
# 3. WAYLAND Y WAYFIRE
# ==============================================================================

log_info "[3/4] Instalando entorno grafico Wayland..."

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
light
font-awesome
noto-basic
gtk3
gtk4
evdev-proto
"

if ! pkg -c "${TARGET_DIR}" install -y ${WAYLAND_PKGS}; then
    log_warn "Fallo parcial en la instalacion de paquetes graficos."
fi

sysrc -R "${TARGET_DIR}" seatd_enable="YES"
sysrc -R "${TARGET_DIR}" kld_list="i915kms amdgpu"

# ==============================================================================
# 4. USUARIO Y ESCRITORIO FLUIDOS
# ==============================================================================

log_info "[4/4] Configurando escritorio FluidOS..."

log_info "Creando usuario fluid..."

if ! chroot "${TARGET_DIR}" pw user show fluid >/dev/null 2>&1; then
    chroot "${TARGET_DIR}" pw useradd fluid \
        -m \
        -g wheel \
        -G video,input \
        -s /bin/sh \
        -c "FluidOS Desktop User"

    chroot "${TARGET_DIR}" sh -c \
        'echo "fluid:fluidos" | chpasswd'
fi

USER_HOME="${TARGET_DIR}/home/fluid"

mkdir -p "${USER_HOME}/.config/wayfire"
mkdir -p "${USER_HOME}/.config/sfwbar"

# ==============================================================================
# CONFIGURACION WAYFIRE
# ==============================================================================

cat << 'EOF' > "${USER_HOME}/.config/wayfire/wayfire.ini"

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

# ==============================================================================
# CONFIGURACION SFWBAR: BARRA SUPERIOR Y DOCK
# ==============================================================================

cat << 'EOF' > "${USER_HOME}/.config/sfwbar/sfwbar.config"

# FluidOS macOS-inspired Top Bar & Bottom Dock

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
        format = "%a %b %d  %H:%M"
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

# ==============================================================================
# PERMISOS
# ==============================================================================

log_info "Asignando permisos al usuario fluid..."

chroot "${TARGET_DIR}" chown -R fluid:wheel /home/fluid

chmod +x "${TARGET_DIR}/usr/local/bin/fluidos-update"

# ==============================================================================
# FINAL
# ==============================================================================

log_success "=========================================================="
log_success "FluidOS: configuracion completada."
log_success "OpenZFS y Boot Environments configurados."
log_success "PF y Bonjour configurados."
log_success "Wayland y Wayfire configurados."
log_success "Barra superior y Dock preparados."
log_success "Actualizador FluidOS instalado."
log_success "=========================================================="

echo "[INFO] Sistema objetivo: ${TARGET_DIR}"
echo "[INFO] Ejecuta make-iso.sh para generar la imagen."
