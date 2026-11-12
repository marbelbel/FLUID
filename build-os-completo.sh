#!/bin/sh
# ==============================================================================
# FluidOS - Script Maestro de Compilación Completa desde Código Fuente
# Compilación del Kernel de Baja Latencia y Sistema Base (buildworld & buildkernel)
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
FREEBSD_BRANCH="releng/14.2"
SRC_DIR="/usr/src"
BUILD_JOBS=$(sysctl -n hw.ncpu 2>/dev/null || echo 4)
KERNCONF_NAME="FLUIDOS"
KERNEL_CONF_PATH="${SRC_DIR}/sys/amd64/conf/${KERNCONF_NAME}"
BUILD_DESTDIR="/usr/obj/fluidos_root"

log_info "Iniciando proceso de compilación completa de FluidOS desde código fuente..."
log_info "Utilizando ${BUILD_JOBS} hilos de procesamiento para compilación."

# 1. Instalación de dependencias del entorno de compilación
log_info "Verificando dependencias de construcción (git, ca_root_nss)..."
if ! command -v git >/dev/null 2>&1; then
    pkg install -y git-lite ca_root_nss || log_error "No se pudo instalar git-lite."
fi

# 2. Descarga / Actualización del código fuente oficial de FreeBSD
if [ ! -d "${SRC_DIR}/.git" ]; then
    log_info "Clonando repositorio oficial de FreeBSD (${FREEBSD_BRANCH}) en ${SRC_DIR}..."
    rm -rf "${SRC_DIR:?}"/*
    git clone --depth 1 -b "${FREEBSD_BRANCH}" https://git.freebsd.org/src.git "${SRC_DIR}"
else
    log_info "Actualizando fuentes de FreeBSD en ${SRC_DIR}..."
    git -C "${SRC_DIR}" pull --rebase || log_warn "No se pudo actualizar vía git pull, continuando con fuentes locales existentes."
fi

# 3. Generación de configuración de Kernel de Baja Latencia (FLUIDOS)
log_info "Configurando el kernel de baja latencia ${KERNCONF_NAME}..."

cat << 'EOF' > "${KERNEL_CONF_PATH}"
#
# FLUIDOS Kernel Configuration - Low Latency Commercial Desktop Profile
# FreeBSD AMD64 Architecture
#

include GENERIC

ident       FLUIDOS

# Optimización de latencia y programación de tareas
options     HZ=1000                 # 1ms timer tick para máxima efectividad multimedia y baja latencia
options     PREEMPTION              # Preempción de kernel en tiempo real para respuesta de escritorio
options     SCHED_ULE               # Scheduler ULE multinúcleo optimizado para desktop
options     DEVICE_POLLING          # Polling opcional para mitigación de sobrecarga de interrupciones

# Desactivación de depuración para maximizar rendimiento comercial
nooptions   WITNESS
nooptions   WITNESS_SKIPSPIN
nooptions   INVARIANTS
nooptions   INVARIANT_SUPPORT
nooptions   DIAGNOSTIC
nooptions   KDB
nooptions   DDB

# Aceleración de almacenamiento y red
options     KNOTE_DEFAULT_BUFSIZE=16384
options     DIRECTIO

# Soporte gráfico e integración DRM/KMS
device      vt
device      vt_vga
device      vt_efifb
EOF

log_success "Archivo de configuración del Kernel creado en ${KERNEL_CONF_PATH}."

# 4. Configuración de /etc/make.conf optimizado para la compilación
cat << EOF > /etc/make.conf
# FluidOS Make Configuration
KERNCONF=${KERNCONF_NAME}
CPUTYPE?=x86-64
MALLOC_PRODUCTION=yes
WITHOUT_DEBUG=yes
WITH_MALLOC_PRODUCTION=yes
WITH_FAST_DEPEND=yes
EOF

# 5. Compilación del Sistema Base (buildworld)
log_info "Iniciando compilación de buildworld (esto tomará bastante tiempo según el hardware)..."
cd "${SRC_DIR}"
make -j"${BUILD_JOBS}" buildworld || log_error "Fallo durante la ejecución de buildworld."
log_success "buildworld completado satisfactoriamente."

# 6. Compilación del Kernel Personalizado (buildkernel)
log_info "Iniciando compilación de buildkernel (${KERNCONF_NAME})..."
make -j"${BUILD_JOBS}" buildkernel KERNCONF="${KERNCONF_NAME}" || log_error "Fallo durante la ejecución de buildkernel."
log_success "buildkernel completado satisfactoriamente."

# 7. Instalación en directorio Staging (/usr/obj/fluidos_root)
log_info "Instalando sistema base compilado en staging (${BUILD_DESTDIR})..."
mkdir -p "${BUILD_DESTDIR}"
make installworld DESTDIR="${BUILD_DESTDIR}"
make installkernel DESTDIR="${BUILD_DESTDIR}" KERNCONF="${KERNCONF_NAME}"
make distribution DESTDIR="${BUILD_DESTDIR}"

log_success "================================================================="
log_success "Compilación completa del Kernel y Sistema Base FluidOS finalizada."
log_success "Staging directory listo en: ${BUILD_DESTDIR}"
log_success "Ejecuta ./setup-features.sh para configurar ZFS, red y Wayland."
log_success "================================================================="
