#!/bin/sh
# autorun-qemu.sh se usa como "init" en el autotest:
# - si init termina, el kernel hace panic
# - por eso al final usamos "exec" para reemplazar este proceso por /bin/sh

# 1) Ir al directorio donde está este script (normalmente /home)
#    "$0" es el path del script; dirname lo convierte a su carpeta.
#    Las comillas evitan problemas si hay espacios.
SCRIPT_DIR="$(dirname "$0")"
cd "$SCRIPT_DIR" || exit 1

echo "Running test script"
./finder-test.sh
rc=$?

if [ "$rc" -eq 0 ]; then
    echo "Completed with success!!"
else
    echo "Completed with failure, failed with rc=$rc"
fi

echo "finder-app execution complete, dropping to terminal"

# 2) MUY IMPORTANTE: exec convierte /bin/sh en el proceso init
#    así init NUNCA "termina" y evitamos el kernel panic.
exec /bin/sh

