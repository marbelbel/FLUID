#!/bin/sh
set -e

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: Este script debe ejecutarse como root."
    exit 1
fi

ARCH="amd64"
STAGE_DIR="/usr/obj/fluidos_root"
CACHE_DIR="/usr/obj/fluidos_cache"

echo "[INFO] Preparando directorios en ${STAGE_DIR}..."
if [ -d "${STAGE_DIR}" ]; then
    chflags -R noschg "${STAGE_DIR}" 2>/dev/null || true
    rm -rf "${STAGE_DIR}"
fi
mkdir -p "${STAGE_DIR}" "${CACHE_DIR}"

DESCARGADO=0
for VER in "14.4-RELEASE" "14.3-RELEASE" "15.0-RELEASE" "14.2-RELEASE"; do
    BASE_URL="https://freebsd.org{ARCH}/${ARCH}/${VER}"
    echo "[INFO] Probando descarga desde FreeBSD ${VER}..."
    if fetch -o "${CACHE_DIR}/base.txz" "${BASE_URL}/base.txz" 2>/dev/null; then
        fetch -o "${CACHE_DIR}/kernel.txz" "${BASE_URL}/kernel.txz"
        DESCARGADO=1
        echo "[OK] Descargado correctamente desde ${VER}"
        break
    fi
done

if [ "${DESCARGADO}" -eq 0 ]; then
    echo "[ERROR] No se encontro ninguna version activa en download.freebsd.org"
    exit 1
fi

echo "[INFO] Extrayendo base.txz y kernel.txz..."
tar -xpf "${CACHE_DIR}/base.txz" -C "${STAGE_DIR}"
tar -xpf "${CACHE_DIR}/kernel.txz" -C "${STAGE_DIR}"

cp /etc/resolv.conf "${STAGE_DIR}/etc/resolv.conf" 2>/dev/null || echo "nameserver 1.1.1.1" > "${STAGE_DIR}/etc/resolv.conf"
echo "FluidOS 1.0" > "${STAGE_DIR}/etc/motd"
rm -rf "${CACHE_DIR}"

echo "[OK] Sistema base de FluidOS listo en ${STAGE_DIR}"
