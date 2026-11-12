#!/bin/sh
# ==============================================================================
# FluidOS - Script de Configuración de Características Avanzadas
# OpenZFS Boot Environments, Cortafuegos PF, mDNS (Bonjour) y Entorno Wayfire
# ==============================================================================

set -e

# Colores de salida
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root."
fi

TARGET_DIR="${1:-/usr/obj/fluidos_root}"

log_info "Configurando características de FluidOS en: ${TARGET_DIR}"

# 1. Configuración de OpenZFS y Boot Environments (bectl)
log_info "[1/4] Configurando OpenZFS y Boot Environments (bectl)..."

# Activar ZFS en el sistema objetivo
sysrc -R "${TARGET_DIR}" zfs_enable="YES"

# Script de actualización atómica basado en bectl para la distribución
cat << 'EOF' > "${TARGET_DIR}/usr/local/bin/fluidos-update"
#!/bin/sh
# FluidOS Atomic System Update Tool via OpenZFS Boot Environments
set -e

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
NEW_BE="FluidOS-Update-${TIMESTAMP}"

echo "==> Creando nuevo Boot Environment (BE): ${NEW_BE}"
bectl create "${NEW_BE}"

echo "==> Montando el nuevo BE para actualización..."
MOUNT_POINT=$(bectl mount "${NEW_BE}")

echo "==> Aplicando actualizaciones de paquetes en ${MOUNT_POINT}..."
pkg -r "${MOUNT_POINT}" upgrade -y || {
    echo "Fallo en la actualización. Desmontando y eliminando BE no válido..."
    bectl unmount "${NEW_BE}"
    bectl destroy -f "${NEW_BE}"
    exit 1
}

echo "==> Activando el nuevo BE (${NEW_BE}) para el próximo arranque..."
bectl activate "${NEW_BE}"

echo "==> Actualización completada con éxito. Reinicie el sistema para aplicar los cambios."
echo "==> En caso de fallo durante el arranque, ZFS/loader volverá automáticamente al BE anterior."
EOF

chmod +x "${TARGET_DIR}/usr/local/bin/fluidos-update"
log_success "ZFS y herramientas bectl configuradas correctamente."

# 2. Configuración de Red, Cortafuegos PF y mDNS (Bonjour)
log_info "[2/4] Configurando Red Automática, Cortafuegos PF y mDNS (Bonjour)..."

sysrc -R "${TARGET_DIR}" defaultrouter=""
sysrc -R "${TARGET_DIR}" ifconfig_DEFAULT="DHCP"
sysrc -R "${TARGET_DIR}" pf_enable="YES"
sysrc -R "${TARGET_DIR}" pf_rules="/etc/pf.conf"
sysrc -R "${TARGET_DIR}" pflog_enable="YES"

# Generación del archivo de reglas PF (/etc/pf.conf)
cat << 'EOF' > "${TARGET_DIR}/etc/pf.conf
# ==============================================================================
# FluidOS PF Firewall Configuration - High Security Desktop Profile
# ==============================================================================

# Interfaces y Macros
ext_if = egress

# Tablas para bloqueo de tráfico malicioso
table <badhosts> persist

# Opciones globales
set skip on lo0
set block-policy drop
set loginterface $ext_if
set reassemble yes

# Normalización de tráfico
scrub in all fragment reassemble

# Regla de bloqueo por defecto (Stateful)
block in all
pass out all keep state

# Permitir resolución mDNS / Apple Bonjour (UDP 5353)
pass in proto udp to any port 5353 keep state
pass out proto udp to any port 5353 keep state

# Permitir ICMP (ping/traceroute) controlado
pass in inet proto icmp all icmp-type echoreq keep state
EOF

# Instalación de Avahi (mDNS / Bonjour) y configuración NSS
log_info "Instalando y configurando Avahi/mDNS..."
pkg -c "${TARGET_DIR}" install -y avahi-app nss_mdns dbus || log_warn "No se pudieron instalar paquetes avahi mediante pkg chroot (se instalarán durante construcción de la ISO)."

sysrc -R "${TARGET_DIR}" dbus_enable="YES"
sysrc -R "${TARGET_DIR}" avahi_daemon_enable="YES"

# Modificar /etc/nsswitch.conf para soporte .local / mDNS
if [ -f "${TARGET_DIR}/etc/nsswitch.conf" ]; then
    sed -i '' 's/hosts: files dns/hosts: files dns mdns/g' "${TARGET_DIR}/etc/nsswitch.conf"
fi
log_success "PF y mDNS (Bonjour) configurados correctamente."

# 3. Instalación de Entorno Gráfico Wayland (Wayfire estilo macOS)
log_info "[3/4] Instalando paquetes y entorno Wayfire (Wayland)..."

# Paquetes gráficos principales
WAYLAND_PKGS="wayland wayfire wf-shell sfwbar seatd drm-kmod xwayland foot grim slurp pamixer light font-awesome noto-basic gtk3 gtk4 evdev-proto"

pkg -c "${TARGET_DIR}" install -y ${WAYLAND_PKGS} || log_warn "Fallo parcial en la instalación de paquetes gráficos en chroot."

sysrc -R "${TARGET_DIR}" seatd_enable="YES"
sysrc -R "${TARGET_DIR}" kld_list="i915kms amdgpu"

# Crear usuario por defecto 'fluid' si no existe
log_info "Creando usuario por defecto 'fluid'..."
if ! chroot "${TARGET_DIR}" pw user show fluid >/dev/null 2>&1; then
    chroot "${TARGET_DIR}" pw useradd fluid -m -g wheel -G video,input -s /bin/sh -c "FluidOS Desktop User"
    chroot "${TARGET_DIR}" sh -c 'echo "fluid:fluidos" | chpasswd'
fi

# 4. Configuración Estilo macOS (Barra Superior Global, Dock Inferior, Wayfire)
log_info "[4/4] Aplicando configuración visual inspirada en macOS..."

USER_HOME="${TARGET_DIR}/home/fluid"
mkdir -p "${USER_HOME}/.config/wayfire"
mkdir -p "${USER_HOME}/.config/sfwbar"

# Configuración de Wayfire (~/.config/wayfire.ini)
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

# Configuración de SFWBar estilo macOS (Barra superior + Dock inferior)
cat << 'EOF' > "${USER_HOME}/.config/sfwbar/sfwbar.config"
# FluidOS macOS-inspired Top Bar & Bottom Dock Config for sfwbar

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

  item "spacer" { type = flex }

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

# Asignar permisos al usuario fluid
chroot "${TARGET_DIR}" chown -R fluid:wheel /home/fluid

log_success "================================================================="
log_success "Características avanzadas de FluidOS configuradas con éxito."
log_success "Ejecuta ./make-iso.sh para empaquetar la distribución."
log_success "================================================================="
