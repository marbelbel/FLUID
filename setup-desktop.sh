#!/bin/sh
# Instala la shell propia de FluidOS en el sistema objetivo preparado.
set -eu

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] setup-desktop.sh debe ejecutarse como root." >&2
    exit 1
fi

TARGET_DIR="${1:-/usr/obj/fluidos_root}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOURCE="$SCRIPT_DIR/desktop/fluidos-shell.py"

[ -d "$TARGET_DIR" ] || { echo "[ERROR] No existe $TARGET_DIR." >&2; exit 1; }
[ -d "$TARGET_DIR/home/fluid" ] || { echo "[ERROR] No existe $TARGET_DIR/home/fluid. Ejecuta antes setup-features.sh." >&2; exit 1; }
[ -f "$SOURCE" ] || { echo "[ERROR] No se encuentra $SOURCE." >&2; exit 1; }

# Las dependencias se instalan en setup-features.sh. Aqui solo se instala la shell.
install -d -m 755 "$TARGET_DIR/usr/local/lib/fluidos"
install -d -m 755 "$TARGET_DIR/usr/local/bin"
install -d -m 755 "$TARGET_DIR/home/fluid/.config/wayfire"
install -m 755 "$SOURCE" "$TARGET_DIR/usr/local/lib/fluidos/fluidos-shell.py"

cat > "$TARGET_DIR/usr/local/bin/fluidos-shell" <<'LAUNCHER_EOF'
#!/bin/sh
export GDK_BACKEND=wayland
export XDG_CURRENT_DESKTOP=FluidOS
export XDG_SESSION_DESKTOP=FluidOS
exec /usr/local/bin/python3.12 /usr/local/lib/fluidos/fluidos-shell.py "$@"
LAUNCHER_EOF
chmod 755 "$TARGET_DIR/usr/local/bin/fluidos-shell"

cat > "$TARGET_DIR/home/fluid/.config/wayfire/wayfire.ini" <<'WAYFIRE_EOF'
[core]
plugins = alpha animate autostart command decoration expo grid move place resize scale vswitch wobbly
vwidth = 2
vheight = 2
close_top_view = <super> KEY_Q | <alt> KEY_F4
preferred_decoration_mode = client

[autostart]
autostart_wf_shell = false
0_environment = dbus-update-activation-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=FluidOS
1_fluidos_shell = /usr/local/bin/fluidos-shell

[command]
binding_terminal = <super> KEY_ENTER
command_terminal = foot

[grid]
slot_l = <super> KEY_LEFT
slot_r = <super> KEY_RIGHT
slot_t = <super> KEY_UP
slot_b = <super> KEY_DOWN

[expo]
toggle = <super> KEY_E

[vswitch]
binding_left = <ctrl> <super> KEY_LEFT
binding_right = <ctrl> <super> KEY_RIGHT
WAYFIRE_EOF

chroot "$TARGET_DIR" chown -R fluid:wheel /home/fluid
chroot "$TARGET_DIR" chmod 755 /home/fluid /home/fluid/.config /home/fluid/.config/wayfire

echo "[SUCCESS] Shell propia de FluidOS instalada."
echo "[INFO] Wayfire iniciara fluidos-shell sin wf-shell ni sfwbar."
