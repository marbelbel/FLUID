# FluidOS Custom Shell

Esta primera implementación reemplaza los paneles `wf-shell`/`sfwbar` por componentes propios de FluidOS, escritos en Python + GTK3 y anclados con GTK Layer Shell sobre Wayfire.

## Archivos

- `desktop/fluidos-shell.py`: escritorio, fondo, iconos, barra superior, Dock, centro de control, notificaciones, lanzador y explorador de archivos propios.
- `setup-desktop.sh`: instala las dependencias, copia el shell y escribe la configuración de Wayfire.
- `SETUP-FEATURES.patch`: cambios necesarios para integrarlo en el `setup-features.sh` actual.

## Integración

Desde la raíz del repositorio, extrae el ZIP allí mismo para que queden `desktop/`, `setup-desktop.sh` y `SETUP-FEATURES.patch` en la raíz. Después ejecuta:

```sh
patch -p1 < SETUP-FEATURES.patch
chmod +x setup-desktop.sh
```

A continuación ejecuta la compilación habitual de FluidOS.

## Dependencias

El instalador añade GTK3, `gtk-layer-shell`, Python 3.12, PyGObject y PyCairo. `gtk-layer-shell` permite anclar paneles, notificaciones y fondos al protocolo layer-shell de Wayland; Wayfire es un compositor compatible.

## Qué funciona en esta versión

- Barra superior, Dock e iconos de escritorio propios.
- Centro de control y panel de notificaciones con apertura/cierre.
- Lanzador de aplicaciones propio.
- Explorador de archivos propio: navega por carpetas reales y abre archivos con la aplicación asociada.
- Fondo dibujado por FluidOS con Cairo.

## Qué todavía es visual

Los botones de Wi-Fi, Bluetooth, modo avión, modo noche, brillo y volumen cambian su estado visual, pero aún no están conectados a los servicios reales de FreeBSD. Las notificaciones mostradas son de demostración. No se debe anunciar esta versión como panel de control funcional hasta integrar y probar esos servicios.

## Verificación

Antes de compilar, se ha comprobado la sintaxis Python (`py_compile`) y la sintaxis del script de instalación (`sh -n`). Todavía falta probar el shell dentro de una sesión Wayfire real creada por la ISO de FluidOS.
