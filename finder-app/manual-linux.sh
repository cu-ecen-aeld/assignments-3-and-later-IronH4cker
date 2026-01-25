#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u

OUTDIR=/tmp/aeld
KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
#CROSS_COMPILE=${CROSS_COMPILE:-aarch64-linux-gnu-}
# Si el entorno ya define CROSS_COMPILE, lo respetamos.
# Si no, intentamos auto-detectar un toolchain ARM64 disponible.
if [ -z "${CROSS_COMPILE:-}" ]; then
    if command -v aarch64-none-linux-gnu-gcc >/dev/null 2>&1; then
        CROSS_COMPILE="aarch64-none-linux-gnu-"
    elif command -v aarch64-linux-gnu-gcc >/dev/null 2>&1; then
        CROSS_COMPILE="aarch64-linux-gnu-"
    else
        echo "ERROR: No ARM64 cross-compiler found in PATH."
        echo "Expected one of: aarch64-none-linux-gnu-gcc or aarch64-linux-gnu-gcc"
        exit 1
    fi
else
    # Si vino definido, validamos que exista (para fallar con mensaje claro)
    if ! command -v "${CROSS_COMPILE}gcc" >/dev/null 2>&1; then
        echo "ERROR: CROSS_COMPILE is set to '${CROSS_COMPILE}' but '${CROSS_COMPILE}gcc' is not in PATH."
        exit 1
    fi
fi

echo "Using CROSS_COMPILE=${CROSS_COMPILE}"

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

OUTDIR=$(realpath "${OUTDIR}")  # Convertimos OUTDIR a ruta absoluta para evitar problemas al hacer cd/cp
mkdir -p "${OUTDIR}"

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then

    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd "${OUTDIR}/linux-stable"
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}

    # TODO: Add your kernel build steps here
    echo "Building the Image of my Henry Linux Kernel ..."

    echo "Cleaning the previous build artefact (mrproper)" 		   #Anuncia la limpieza completa del arbol del kernel
    make mrproper 					   		   #Borra las configs y outputs previas para crear un build limpio y reproducible

    echo "Configuring kernel with default config defconfig ${ARCH}..."     #Anuncia la configuracion del kernel por defecto
    							       	       	   #Teniendo en cuenta que se define arriba la arquitectura ARCH=arm64 y el compilador cruzado CROSS_COMPILE=aarch64-none-linux-gnu-
    make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} defconfig         #Se crea un archivo .config default para la arquitectura ARM64 usando la toolchain cross
    									   #IMPORTANTE debe llamarse defconfig por convencion de LINUX no es un nombre que sea personalizable
	
    # -j$(nproc):
    # -j indica a make cuántos trabajos puede ejecutar en paralelo
    # $(nproc) devuelve el número de CPUs disponibles en tu máquina
    # (por ejemplo 4, 8, 16, etc.)
    # Usar todos los cores acelera MUCHO la compilación
    echo "Building the kernel Image using all CPU cores ..."		   #Anuncia que se va a construir la imagen del kernel
    make -j"$(nproc)" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} Image    #Compila el kernel sin modulos y genera el directorio arch/arm64/boot/Image
fi

echo "Adding the Image in outdir"
cp -f ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ${OUTDIR}/Image        #Se copia la Imagen final que se genera en tmp/aeld/linux-stabl/arch/arm64/boot/Image...a  
									   #...a solo tmp/aeld  para que QEMU lo encuentre



echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
        sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
# rootfs es un "staging directory":
#  - No es todavía un sistema arrancable
#  - Es simplemente un árbol de directorios que luego empaquetaremos
#    dentro de un initramfs
mkdir -p ${OUTDIR}/rootfs                    # Crea el directorio raíz del filesystem “staging”
mkdir -p ${OUTDIR}/rootfs/bin                # Binarios esenciales (busybox instala aquí symlinks/ejecutables)
mkdir -p ${OUTDIR}/rootfs/sbin               # Binarios de sistema
mkdir -p ${OUTDIR}/rootfs/etc                # Configuración del sistema
mkdir -p ${OUTDIR}/rootfs/proc               # Punto de montaje para procfs (runtime)
mkdir -p ${OUTDIR}/rootfs/sys                # Punto de montaje para sysfs (runtime)
mkdir -p ${OUTDIR}/rootfs/dev                # Nodos de dispositivos (/dev/null, /dev/console)
mkdir -p ${OUTDIR}/rootfs/lib                # Librerías compartidas (ej: libc)
mkdir -p ${OUTDIR}/rootfs/lib64              # Librerías 64-bit + loader dinamico (loader / ld-linux)
mkdir -p ${OUTDIR}/rootfs/usr                # Jerarquía /usr
mkdir -p ${OUTDIR}/rootfs/usr/bin            # Binarios de usuario
mkdir -p ${OUTDIR}/rootfs/usr/sbin           # Binarios de admin en /usr
mkdir -p ${OUTDIR}/rootfs/usr/lib            # Librerías bajo /usr
mkdir -p ${OUTDIR}/rootfs/var                # Datos variables
mkdir -p ${OUTDIR}/rootfs/var/log            # Logs
mkdir -p ${OUTDIR}/rootfs/tmp                # Temporales
mkdir -p ${OUTDIR}/rootfs/home               # Home (para ejecutar scripts del assignment)
mkdir -p ${OUTDIR}/rootfs/home/conf          # Carpeta conf requerida por finder-test.sh




# ============================================================
# BUSYBOX CONFIGURATION
# ============================================================

# busybox es una "navaja suiza" o  "Swiss Army Knife":
#  - Un solo binario que implementa ls, cp, sh, mkdir, etc.
#  - Permite un sistema Linux mínimo sin instalar cientos de programas

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
git clone git://busybox.net/busybox.git     #Descarga buxybox si no existe
    cd busybox				    #Entra al repo de busybox	
    git checkout ${BUSYBOX_VERSION}         #Selecciona version requerida para reproducibilidad
    # TODO:  Configure busybox
    make distclean			    # Elimina configuraciones previas de busybox
				            # Evita que opciones antiguas afecten el build actual
    make defconfig		            # Genera una configuración por defecto
					    # Incluye /bin/sh, utilidades básicas y comandos POSIX mínimos
else
    cd busybox
fi

# TODO: Make and install busybox
# ============================================================
# BUSYBOX BUILD + INSTALL
# ============================================================
make -j"$(nproc)" ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE}     #Compila la busybox con el compilador cruzado

# Instala busybox directamente dentro del rootfs:
#  - Copia el binario busybox
#  - Crea enlaces simbólicos como /bin/sh, /bin/ls, etc.
make ARCH=${ARCH} CROSS_COMPILE=${CROSS_COMPILE} CONFIG_PREFIX=${OUTDIR}/rootfs install #Se instala la busybox en la raiz del sistema de ficheros: /bin/busybox + symlinks



# ============================================================
# LIBRARY DEPENDENCIES
# ============================================================

# busybox NO es estático por defecto
# Eso significa que depende de librerías compartidas (libc, loader, etc.)
# Si no copiamos estas librerías, el kernel arrancará,
# pero cualquier comando dará "not found"

echo "Library dependencies"
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "program interpreter" || true
${CROSS_COMPILE}readelf -a ${OUTDIR}/rootfs/bin/busybox | grep "Shared library" || true

# TODO: Add library dependencies to rootfs
# ============================================================
# ADD MINIMAL LIBRARY DEPENDENCIES TO ROOTFS (ARM64)
# ============================================================
# ------------------------------------------------------------
# CONTEXTO: ¿POR QUÉ COPIAR SOLO LIBRERÍAS MÍNIMAS?
# ------------------------------------------------------------
# En una versión anterior del script, copiábamos "todo" el árbol de librerías
# del toolchain (algo como: ${SYSROOT}/lib/*, ${SYSROOT}/usr/lib/*, etc.).
#
# Eso provocó que el rootfs (y por tanto el initramfs) creciera ENORMEMENTE:
#   - initramfs.cpio.gz llegó a ~3.2 GB
#
# ¿Qué estaba pasando?
#   - Copiar directorios enteros arrastra miles de ficheros que NO necesitas:
#       * librerías extra
#       * soporte de locales
#       * módulos / firmware / plugins
#       * runtimes completos
#       * contenido del host si SYSROOT estaba mal (por ejemplo SYSROOT="/")
#
# ¿Por qué es un problema?
#   - El initramfs se carga en RAM al arrancar.
#   - Un initramfs de gigabytes puede hacer que QEMU no lo pueda cargar
#     (por memoria/tiempo), y aparezcan errores tipo:
#       "could not load initrd ..."
#
# SOLUCIÓN EMBEBIDA (lo correcto):
#   - Copiar SOLO lo que hace falta para ejecutar:
#       * /bin/busybox
#       * writer
#       * scripts del assignment
#   - Es decir: loader + libc (+ un par de libs típicas).
#
# Esto mantiene el initramfs en el orden de MB, no GB.
# ------------------------------------------------------------
# ¿POR QUÉ NO USAMOS SYSROOT?
# ------------------------------------------------------------
# En teoría, SYSROOT debería apuntar al "root" del sistema target (ARM64),
# donde viven:
#   - libc.so.6
#   - ld-linux-aarch64.so.1
#   - libm.so, libresolv.so, etc.
#
# PERO en Ubuntu con gcc-aarch64-linux-gnu:
#
#   aarch64-linux-gnu-gcc -print-sysroot
#   → devuelve "/"
#
# Eso significa que SYSROOT apunta al root del HOST,
# NO a un árbol aislado del target.
#
# Usar SYSROOT="/" provoca:
#   - copiar librerías x86_64 del host
#   - copiar demasiado contenido
#   - initramfs gigantes (GB)
#   - fallos al arrancar QEMU
#
# Por eso DESCARTAMOS SYSROOT en este entorno.


# ------------------------------------------------------------
# Hay qye localizar libc REAL del toolchain ARM64
# ------------------------------------------------------------
# Le preguntamos directamente al compilador cruzado:
# “¿Dónde está libc.so.6 que usarías para ARM64?”
#
# Este comando devuelve una RUTA REAL y ESPECÍFICA del target:
LIBC_PATH="$(${CROSS_COMPILE}gcc -print-file-name=libc.so.6)"

# Si gcc no devuelve una ruta absoluta, algo está mal:
#  - falta libc6-arm64-cross
#  - toolchain mal instalado
if [ -z "${LIBC_PATH}" ] || [ "${LIBC_PATH}" = "libc.so.6" ]; then
    echo "ERROR: Could not locate ARM64 libc.so.6 using ${CROSS_COMPILE}gcc"
    echo "Install it with: sudo apt install -y libc6-arm64-cross"
    exit 1
fi

# ------------------------------------------------------------
# LIBDIR = directorio donde viven las librerías ARM64
# ------------------------------------------------------------
# A partir de la ruta exacta a libc, deducimos su directorio.
# Aquí suelen estar también:
#   - libm.so
#   - libresolv.so
LIBDIR="$(dirname "${LIBC_PATH}")"
echo "Using ARM64 library directory: ${LIBDIR}"

# Creamos el directorio destino en el rootfs
sudo mkdir -p ${OUTDIR}/rootfs/lib


# ------------------------------------------------------------
# libc (C standard library)
# ------------------------------------------------------------
# Proporciona:
#   printf, malloc, open/read/write, fork, exec, etc.
# Es IMPRESCINDIBLE para cualquier binario dinámico
sudo cp -a ${LIBDIR}/libc.so.6 ${OUTDIR}/rootfs/lib/
sudo cp -a ${LIBDIR}/libc.so.* ${OUTDIR}/rootfs/lib/ 2>/dev/null || true

# ------------------------------------------------------------
# libm (Math library)
# ------------------------------------------------------------
# Funciones matemáticas: sqrt, pow, etc.
# BusyBox puede depender de ella
sudo cp -a ${LIBDIR}/libm.so.* ${OUTDIR}/rootfs/lib/ 2>/dev/null || true


# ------------------------------------------------------------
# libresolv (DNS / networking helpers)
# ------------------------------------------------------------
# No siempre es crítica, pero muchas distros la incluyen
sudo cp -a ${LIBDIR}/libresolv.so.* ${OUTDIR}/rootfs/lib/ 2>/dev/null || true

# ------------------------------------------------------------
# ALSO install runtime libraries into /lib64 (required by loader)
# ------------------------------------------------------------

sudo mkdir -p ${OUTDIR}/rootfs/lib64

sudo cp -a ${LIBDIR}/libc.so.*     ${OUTDIR}/rootfs/lib64/ 2>/dev/null || true
sudo cp -a ${LIBDIR}/libm.so.*     ${OUTDIR}/rootfs/lib64/ 2>/dev/null || true
sudo cp -a ${LIBDIR}/libresolv.so.* ${OUTDIR}/rootfs/lib64/ 2>/dev/null || true


# ------------------------------------------------------------
# Dynamic loader (ELF interpreter) (IMPRESCINDIBLE)
# ------------------------------------------------------------
# LOADER viene de readelf y típicamente es /lib/ld-linux-aarch64.so.1
LOADER=$(${CROSS_COMPILE}readelf -a "${OUTDIR}/rootfs/bin/busybox" 2>/dev/null \
    | awk '/program interpreter/ {gsub(/[\[\]]/,"",$NF); print $NF}')

if [ -n "${LOADER}" ]; then
    sudo mkdir -p "${OUTDIR}/rootfs$(dirname "${LOADER}")"

    LOADER_BASENAME="$(basename "${LOADER}")"

    # Lista de candidatos donde podría estar el loader en distintos toolchains/hosts
    #  - Ubuntu host: /lib/aarch64-linux-gnu/...
    #  - toolchain sysroot cerca de LIBDIR (lib, lib64, libc/lib, etc.)
    CANDIDATES=(
        "/lib/aarch64-linux-gnu/${LOADER_BASENAME}"
        "${LIBDIR}/${LOADER_BASENAME}"
        "${LIBDIR}/../lib/${LOADER_BASENAME}"
        "${LIBDIR}/../lib64/${LOADER_BASENAME}"
        "${LIBDIR}/../libc/lib/${LOADER_BASENAME}"
        "${LIBDIR}/../libc/lib64/${LOADER_BASENAME}"
    )

    FOUND_LOADER=""
    for c in "${CANDIDATES[@]}"; do
        if [ -f "${c}" ]; then
            FOUND_LOADER="${c}"
            break
        fi
    done

    if [ -z "${FOUND_LOADER}" ]; then
        echo "ERROR: Could not find ARM64 loader ${LOADER} on host."
        echo "Searched:"
        for c in "${CANDIDATES[@]}"; do
            echo "  - ${c}"
        done
        exit 1
    fi

    echo "Found loader at: ${FOUND_LOADER}"
    sudo cp -a "${FOUND_LOADER}" "${OUTDIR}/rootfs${LOADER}"
fi

# TODO: Make device nodes
# ============================================================
# DEVICE NODES
# ============================================================

# /dev/null:
#  - Dispositivo que descarta todo lo que se escribe en él
#  - MUCHOS programas dependen de su existencia
sudo mknod -m 666 ${OUTDIR}/rootfs/dev/null c 1 3 2>/dev/null || true

# /dev/console:
#  - Permite al kernel escribir mensajes en la consola
#  - Sin este nodo, el kernel puede fallar al arrancar
sudo mknod -m 600 ${OUTDIR}/rootfs/dev/console c 5 1 2>/dev/null || true

# TODO: Clean and build the writer utility
# ============================================================
# BUILD write
# ============================================================
if [ -f "${FINDER_APP_DIR}/writer.c" ]; then                               # Comprueba que writer.c esté en finder-app
    make -C ${FINDER_APP_DIR} clean || true                                 # Limpia build previo del writer
    make -C ${FINDER_APP_DIR} CROSS_COMPILE=${CROSS_COMPILE}                # Compila writer con toolchain cross (produce binario ARM64)
    cp -f ${FINDER_APP_DIR}/writer ${OUTDIR}/rootfs/home/                   # Copia writer al home del target para ejecutarlo en QEMU
else
    echo "WARNING: writer.c no encontrado en ${FINDER_APP_DIR}. Ajusta la ruta si tu writer está en otro directorio." # Aviso si tu repo difiere
fi


# TODO: Copy the finder related scripts and executables to the /home directory
# on the target rootfs
# ============================================================
# COPY finder scripts + conf + autorun
# ============================================================

cp -f ${FINDER_APP_DIR}/finder.sh ${OUTDIR}/rootfs/home/ 2>/dev/null || true        # Copia finder.sh al /home del rootfs
cp -f ${FINDER_APP_DIR}/finder-test.sh ${OUTDIR}/rootfs/home/ 2>/dev/null || true   # Copia finder-test.sh al /home del rootfs
cp -f "${FINDER_APP_DIR}/autorun-qemu.sh" "${OUTDIR}/rootfs/home/"                  # Copia autorun-qemu.sh al /home del rootfs

cp -f ${FINDER_APP_DIR}/../conf/username.txt ${OUTDIR}/rootfs/home/conf/ 2>/dev/null || true   # Copia conf/username.txt al target
cp -f ${FINDER_APP_DIR}/../conf/assignment.txt ${OUTDIR}/rootfs/home/conf/ 2>/dev/null || true # Copia conf/assignment.txt al target

if [ -f "${OUTDIR}/rootfs/home/finder-test.sh" ]; then                              # Si finder-test existe en rootfs
    sed -i 's|\.\./conf/assignment\.txt|conf/assignment.txt|g' ${OUTDIR}/rootfs/home/finder-test.sh # Ajusta ruta requerida por Part 2
fi



# ------------------------------------------------------------
# FIX scripts for BusyBox environment (AUTOTEST CRITICAL)
# ------------------------------------------------------------
# El autotest normalmente arranca QEMU ejecutando /home/autorun-qemu.sh.
# Si ese script usa /bin/bash o tiene CRLF, el init falla (exit 127 => 0x7f00)
# y el kernel hace panic.

# 0) Quitar CRLF SIEMPRE (no dependemos de dos2unix)
for f in "${OUTDIR}/rootfs/home/"*.sh; do
    [ -f "$f" ] || continue
    sed -i 's/\r$//' "$f"
done

# 1) Forzar shebang a /bin/sh (BusyBox NO incluye bash)
for f in "${OUTDIR}/rootfs/home/autorun-qemu.sh" \
         "${OUTDIR}/rootfs/home/finder.sh" \
         "${OUTDIR}/rootfs/home/finder-test.sh"
do
    if [ -f "${f}" ]; then
        sed -i '1s|^#! */bin/bash|#!/bin/sh|' "${f}" || true
    fi
done

# 2) Permisos de ejecución
chmod +x "${OUTDIR}/rootfs/home/autorun-qemu.sh" 2>/dev/null || true
chmod +x "${OUTDIR}/rootfs/home/finder-test.sh" 2>/dev/null || true
chmod +x "${OUTDIR}/rootfs/home/finder.sh" 2>/dev/null || true
chmod +x "${OUTDIR}/rootfs/home/writer" 2>/dev/null || true

echo "Sanity check: autorun shebang and perms"
head -n 1 "${OUTDIR}/rootfs/home/autorun-qemu.sh" || true
ls -l "${OUTDIR}/rootfs/home/autorun-qemu.sh" || true



# ------------------------------------------------------------
# Create /init (AUTOTEST CRITICAL)
# ------------------------------------------------------------
# El kernel busca /init dentro del initramfs para arrancar userspace.
# El autotest espera que /init ejecute /home/autorun-qemu.sh.

# Nos aseguramos de que el destino existe antes de crear el symlink
if [ ! -f "${OUTDIR}/rootfs/home/autorun-qemu.sh" ]; then
    echo "ERROR: autorun-qemu.sh was not copied into rootfs/home"
    exit 1
fi

# Creamos /init como symlink a /home/autorun-qemu.sh
ln -sf /home/autorun-qemu.sh "${OUTDIR}/rootfs/init"

# IMPORTANTE: el symlink debe apuntar a algo existente, y el script debe ser ejecutable
chmod +x "${OUTDIR}/rootfs/home/autorun-qemu.sh"

# TODO: Chown the root directory
# ============================================================
# CHOWN rootfs
# ============================================================
sudo chown -R root:root ${OUTDIR}/rootfs                  # Rootfs debe pertenecer a root para initramfs correcto y permisos coherentes

# TODO: Create initramfs.cpio.gz
# ============================================================
# INITRAMFS CREATION
# ============================================================

# initramfs es un archivo comprimido que contiene:
#  - El kernel filesystem inicial
#  - Todo lo que el kernel necesita antes de montar un rootfs real
#
# En este assignment:
#  - NO usamos disco
#  - TODO el sistema vive dentro del initramfs

cd ${OUTDIR}/rootfs                                       # IMPORTANTE: entrar a rootfs para que el cpio tenga rutas relativas correctas


# find .:
#  - Lista TODOS los archivos desde rootfs
#  - El punto (.) es crítico: mantiene rutas relativas correctas

# cpio:
#  - Empaqueta archivos en formato initramfs-compatible
#  - newc es el formato requerido por el kernel moderno

# gzip:
#  - Comprime para reducir tamaño en memoria
# Lista todo (incluye .) con separador NUL para soportar espacios
# Crea archivo cpio formato newc, leyendo nombres NUL; -o write; -v verbose
# Comprime máximo y guarda en OUTDIR para que scripts QEMU lo usen

find . -print0 | sudo cpio --null -ov --format=newc | gzip -9 > "${OUTDIR}/initramfs.cpio.gz"
               

echo "SUCCESS: Created ${OUTDIR}/Image and ${OUTDIR}/initramfs.cpio.gz"
echo "Run: ./start-qemu-terminal.sh ${OUTDIR}"
