
#!/bin/sh
set -eu

# FluidOS: descarga del sistema base oficial de FreeBSD

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] Ejecuta este script como root."
    exit 1
fi

ARCH="amd64"
VER="14.2-RELEASE"
STAGE_DIR="/usr/obj/fluidos_root"
CACHE_DIR="/usr/obj/fluidos_cache"

BASE_URL="https://download.freebsd.org/releases/${ARCH}/${ARCH}/${VER}"

echo "[INFO] Preparando directorios..."

if [ -d "${STAGE_DIR}" ]; then
    chflags -R noschg "${STAGE_DIR}" 2>/dev/null || true
    rm -rf "${STAGE_DIR}"
fi

mkdir -p "${STAGE_DIR}" "${CACHE_DIR}"

echo "[INFO] Descargando FreeBSD ${VER}..."
echo "[INFO] URL: ${BASE_URL}"

if ! fetch -o "${CACHE_DIR}/base.txz" "${BASE_URL}/base.txz"; then
    echo "[ERROR] No se pudo descargar base.txz"
    rm -rf "${CACHE_DIR}"
    exit 1
fi

if ! fetch -o "${CACHE_DIR}/kernel.txz" "${BASE_URL}/kernel.txz"; then
    echo "[ERROR] No se pudo descargar kernel.txz"
    rm -rf "${CACHE_DIR}"
    exit 1
fi

echo "[OK] Descargas completadas."

echo "[INFO] Extrayendo sistema base..."

tar -xpf "${CACHE_DIR}/base.txz" -C "${STAGE_DIR}"
tar -xpf "${CACHE_DIR}/kernel.txz" -C "${STAGE_DIR}"

echo "[INFO] Configurando FluidOS..."

mkdir -p "${STAGE_DIR}/etc"

if [ -f /etc/resolv.conf ]; then
    cp /etc/resolv.conf "${STAGE_DIR}/etc/resolv.conf"
fi

echo "FluidOS 1.0" > "${STAGE_DIR}/etc/motd"

rm -rf "${CACHE_DIR}"

echo "[OK] Sistema base preparado."
echo "[OK] Directorio: ${STAGE_DIR}"
