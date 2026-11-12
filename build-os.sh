#!/bin/sh
# ==============================================================================
# FluidOS - Script Rápido de Aprovisionamiento Base (Método Binario Oficial)
# Descarga e Instalación de Conjuntos Binarios FreeBSD 14.2-RELEASE (amd64)
# ==============================================================================

set -e

# Colores para salida de terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Verificación de privilegios de superusuario
if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script debe ejecutarse como root."
fi

# Variables de configuración
FREEBSD_VERSION="14.2-RELEASE"
ARCH="amd64"
BUILD_DESTDIR="/usr/obj/fluidos_root"
MIRROR_URL="https://download.freebsd.org/releases/${ARCH}/${FREEBSD_VERSION}"
TEMP_DIR="/tmp/fluidos_dist"

log_info "Iniciando aprovisionamiento rápido de FluidOS (FreeBSD ${FREEBSD_VERSION} ${ARCH})..."

# 1. Preparación de directorios
log_info "Creando directorio objetivo staging: ${BUILD_DESTDIR}..."
mkdir -p "${BUILD_DESTDIR}"
mkdir -p "${TEMP_DIR}"

# 2. Descarga de conjuntos binarios oficiales (base.txz y kernel.txz)
log_info "Descargando conjuntos binarios oficiales desde ${MIRROR_URL}..."

fetch_file() {
    FILE=$1
    URL="${MIRROR_URL}/${FILE}"
    TARGET="${TEMP_DIR}/${FILE}"
    if [ ! -f "${TARGET}" ]; then
        log_info "Descargando ${FILE}..."
        fetch -o "${TARGET}" "${URL}" || curl -sSL -o "${TARGET}" "${URL}" || log_error "No se pudo descargar ${FILE} desde ${URL}."
    else
        log_info "Archivo ${FILE} ya descargado previamente en ${TEMP_DIR}."
    fi
}

fetch_file "base.txz"
fetch_file "kernel.txz"

# 3. Extracción de conjuntos binarios en staging root
log_info "Extrayendo base.txz en ${BUILD_DESTDIR}..."
tar -C "${BUILD_DESTDIR}" -xzf "${TEMP_DIR}/base.txz"

log_info "Extrayendo kernel.txz en ${BUILD_DESTDIR}..."
tar -C "${BUILD_DESTDIR}" -xzf "${TEMP_DIR}/kernel.txz"

# 4. Configuración inicial básica del staging
log_info "Copiando configuración DNS para conectividad dentro de staging..."
cp /etc/resolv.conf "${BUILD_DESTDIR}/etc/resolv.conf" 2>/dev/null || true

# 5. Limpieza de archivos temporales
log_info "Limpiando descargas temporales..."
rm -rf "${TEMP_DIR}"

log_success "================================================================="
log_success "Aprovisionamiento binario del Sistema Base FluidOS completado."
log_success "Sistema base listo en: ${BUILD_DESTDIR}"
log_success "Ejecuta ./setup-features.sh para configurar ZFS, red y Wayland."
log_success "================================================================="
