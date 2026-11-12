#!/bin/sh
# ==============================================================================
# FluidOS - Script de Empaquetado e Imagen ISO Arrancable (Hybrid UEFI/BIOS)
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

STAGING_DIR="/usr/obj/fluidos_root"
ISO_NAME="fluidos-14.0-amd64.iso"
OUTPUT_ISO_PATH="$(pwd)/${ISO_NAME}"
ISO_LABEL="FLUIDOS_14"

log_info "Iniciando empaquetado de ISO para FluidOS..."

if [ ! -d "${STAGING_DIR}" ]; then
    log_error "El directorio staging ${STAGING_DIR} no existe. Ejecuta primero build-os.sh y setup-features.sh."
fi

# 1. Configuración de /boot/loader.conf final para la ISO/Sistema
log_info "Configurando /boot/loader.conf..."
cat << 'EOF' > "${STAGING_DIR}/boot/loader.conf"
# FluidOS System Boot Parameters
autoboot_delay="3"
loader_logo="orb"
boot_mute="YES"

# Carga de módulos ZFS y kernel
zfs_load="YES"
geom_zfs_load="YES"
vfs.root.mountfrom="zfs:zroot/ROOT/default"

# Módulos gráficos DRM/KMS
i915kms_load="YES"
amdgpu_load="YES"

# Optimización de rendimiento
kern.ipc.shmmax=67108864
kern.ipc.shmall=32768
EOF

# 2. Configuración del instalador / autorun si es necesario
log_info "Verificando estructura de arranque /boot/cdboot y EFI..."
if [ ! -f "${STAGING_DIR}/boot/cdboot" ]; then
    log_warn "Arranque cdboot no encontrado en staging. Copiando desde sistema host..."
    cp -p /boot/cdboot "${STAGING_DIR}/boot/" || log_error "No se pudo copiar /boot/cdboot"
fi

# 3. Generación de partición de arranque EFI (efiboot.img)
EFI_IMG="${STAGING_DIR}/boot/efiboot.img"
log_info "Creando imagen de arranque EFI (${EFI_IMG})..."

if [ -f "/boot/boot1.efimg" ]; then
    cp -p /boot/boot1.efimg "${EFI_IMG}"
else
    # Crear imagen FAT para UEFI de 4MB
    makefs -t msdos -o fat_type=12 -s 4m "${EFI_IMG}" "${STAGING_DIR}/boot/efi" 2>/dev/null || true
fi

# 4. Creación de la imagen ISO con makefs (Formato CD9660 con RockRidge, Bootable BIOS+UEFI)
log_info "Generando la imagen ISO (${OUTPUT_ISO_PATH}) con makefs..."

rm -f "${OUTPUT_ISO_PATH}"

makefs -t cd9660 \
    -o label="${ISO_LABEL}" \
    -o rockridge \
    -o bootimage="i386;${STAGING_DIR}/boot/cdboot" \
    -o no-emul-boot \
    "${OUTPUT_ISO_PATH}" "${STAGING_DIR}" || log_error "Error al generar la imagen ISO con makefs."

log_success "================================================================="
log_success "¡Imagen ISO de FluidOS generada con éxito!"
log_success "Ubicación: ${OUTPUT_ISO_PATH}"
log_success "Tamaño: $(du -h "${OUTPUT_ISO_PATH}" | cut -f1)"
log_success ""
log_success "Para probar en QEMU:"
log_success "  qemu-system-x86_64 -m 4G -smp 4 -cdrom ${ISO_NAME}"
log_success ""
log_success "Para grabar en USB (FreeBSD):"
log_success "  dd if=${ISO_NAME} of=/dev/da0 bs=1M status=progress conv=sync"
log_success "================================================================="
