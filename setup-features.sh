#!/bin/sh
# ==============================================================================
# FluidOS - Configuracion de funciones del sistema y escritorio
# FreeBSD 14.5-RELEASE / amd64
# ==============================================================================

set -eu

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info()    { printf '%b[INFO]%b %s\n' "$BLUE" "$NC" "$1"; }
log_success() { printf '%b[OK]%b %s\n' "$GREEN" "$NC" "$1"; }
log_warn()    { printf '%b[WARN]%b %s\n' "$YELLOW" "$NC" "$1"; }
log_error()   { printf '%b[ERROR]%b %s\n' "$RED" "$NC" "$1" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || log_error "Ejecuta este script como root."

TARGET_DIR="${1:-/usr/obj/fluidos_root}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
DESKTOP_SETUP="$SCRIPT_DIR/setup-desktop.sh"

[ -d "$TARGET_DIR" ] || log_error "No existe el sistema objetivo: $TARGET_DIR"
[ -x "$TARGET_DIR/bin/sh" ] || log_error "El destino no parece contener un FreeBSD instalado: falta /bin/sh. Ejecuta antes build-os.sh."
[ -f "$TARGET_DIR/etc/master.passwd" ] || log_error "Falta etc/master.passwd en el destino. Comprueba la extraccion de base.txz."
[ -f "$DESKTOP_SETUP" ] || log_error "No se encuentra setup-desktop.sh junto a este archivo."

log_info "Configurando FluidOS en $TARGET_DIR"

mkdir -p "$TARGET_DIR/usr/local/bin" \
         "$TARGET_DIR/usr/local/etc" \
         "$TARGET_DIR/etc" \
         "$TARGET_DIR/home"

# ==============================================================================
# 1. OPENZFS Y HERRAMIENTA DE ACTUALIZACION
# ==============================================================================

log_info "[1/4] Configurando ZFS y Boot Environments..."
sysrc -R "$TARGET_DIR" zfs_enable="YES"

cat > "$TARGET_DIR/usr/local/bin/fluidos-update" <<'UPDATE_EOF'
#!/bin/sh
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Ejecuta fluidos-update como root." >&2
    exit 1
fi

command -v bectl >/dev/null 2>&1 || {
    echo "[ERROR] bectl no esta disponible en este sistema." >&2
    exit 1
}

STAMP="$(date +%Y%m%d_%H%M%S)"
NEW_BE="FluidOS-Update-${STAMP}"
MOUNT_POINT=""

cleanup() {
    if [ -n "$MOUNT_POINT" ]; then
        bectl unmount "$NEW_BE" >/dev/null 2>&1 || true
    fi
}
trap cleanup EXIT HUP INT TERM

echo "==> Creando Boot Environment: $NEW_BE"
bectl create "$NEW_BE"
echo "==> Montando Boot Environment..."
MOUNT_POINT="$(bectl mount "$NEW_BE")"

[ -n "$MOUNT_POINT" ] || {
    echo "[ERROR] No se pudo montar el Boot Environment." >&2
    bectl destroy -F "$NEW_BE" >/dev/null 2>&1 || true
    exit 1
}

echo "==> Actualizando paquetes en el nuevo entorno..."
if ! pkg -r "$MOUNT_POINT" upgrade -y; then
    echo "[ERROR] La actualizacion fallo. El entorno nuevo no se activara." >&2
    cleanup
    bectl destroy -F "$NEW_BE" >/dev/null 2>&1 || true
    exit 1
fi

cleanup
MOUNT_POINT=""
echo "==> Activando $NEW_BE"
bectl activate "$NEW_BE"
echo "Actualizacion preparada. Reinicia para arrancar el nuevo entorno."
UPDATE_EOF

chmod 755 "$TARGET_DIR/usr/local/bin/fluidos-update"
log_success "Herramienta fluidos-update instalada."

# ==============================================================================
# 2. RED, PF Y BONJOUR
# ==============================================================================

log_info "[2/4] Configurando red, PF y servicios de red..."
sysrc -R "$TARGET_DIR" ifconfig_DEFAULT="DHCP"
sysrc -R "$TARGET_DIR" pf_enable="YES"
sysrc -R "$TARGET_DIR" pf_rules="/etc/pf.conf"
sysrc -R "$TARGET_DIR" pflog_enable="YES"

cat > "$TARGET_DIR/etc/pf.conf" <<'PF_EOF'
# Firewall base de FluidOS.
set skip on lo0
set block-policy drop
scrub in all
block in all
pass out all keep state

# mDNS / Bonjour en la red local.
pass in  proto udp from any to any port 5353 keep state
pass out proto udp from any to any port 5353 keep state

# Respuestas a ping IPv4.
pass in inet proto icmp all icmp-type echoreq keep state
PF_EOF

if pkg -r "$TARGET_DIR" install -y avahi-app nss_mdns; then
    sysrc -R "$TARGET_DIR" avahi_daemon_enable="YES"
    if [ -f "$TARGET_DIR/etc/nsswitch.conf" ] && ! grep -q 'mdns' "$TARGET_DIR/etc/nsswitch.conf"; then
        sed -i '' 's/^hosts:[[:space:]]*files dns/hosts: files dns mdns/' "$TARGET_DIR/etc/nsswitch.conf"
    fi
    log_success "Avahi y mDNS instalados."
else
    log_warn "Avahi/mDNS no se pudo instalar; se continua sin Bonjour."
fi

if pkg -r "$TARGET_DIR" install -y dbus; then
    sysrc -R "$TARGET_DIR" dbus_enable="YES"
else
    log_error "No se pudo instalar DBus, necesario para el escritorio."
fi

log_success "Red y firewall configurados."

# ==============================================================================
# 3. WAYLAND, WAYFIRE Y USUARIO
# ==============================================================================

log_info "[3/4] Instalando Wayland y Wayfire..."

GRAPHICS_PACKAGES="wayland wayfire seatd drm-kmod xwayland foot gtk3 gtk-layer-shell python312 py312-pygobject py312-pycairo"

if ! pkg -r "$TARGET_DIR" install -y $GRAPHICS_PACKAGES; then
    log_error "Fallo la instalacion de paquetes graficos. Revisa el log de pkg y los nombres disponibles para FreeBSD 14.5."
fi

sysrc -R "$TARGET_DIR" seatd_enable="YES"
sysrc -R "$TARGET_DIR" kld_list="i915kms amdgpu"

log_info "Preparando grupos y usuario fluid..."
if ! chroot "$TARGET_DIR" pw group show video >/dev/null 2>&1; then
    chroot "$TARGET_DIR" pw groupadd video
fi

if ! chroot "$TARGET_DIR" pw user show fluid >/dev/null 2>&1; then
    chroot "$TARGET_DIR" pw useradd fluid \
        -m -g wheel -G video -s /bin/sh \
        -c "FluidOS Desktop User"
    printf '%s\n' 'fluidos' | chroot "$TARGET_DIR" pw usermod fluid -h 0
else
    chroot "$TARGET_DIR" pw usermod fluid -G video,wheel
fi

# ==============================================================================
# 4. SHELL PROPIA DE FLUIDOS
# ==============================================================================

log_info "[4/4] Instalando la interfaz propia de FluidOS..."

sh "$DESKTOP_SETUP" "$TARGET_DIR"

log_success "=============================================================="
log_success "Configuracion de FluidOS terminada."
log_success "ZFS, PF, Wayland, Wayfire y la shell propia estan preparados."
log_info "Siguiente paso: ejecutar make-iso.sh."
log_warn "La compilacion no garantiza por si sola que la ISO arranque; hay que probarla en una maquina virtual."
log_success "=============================================================="
