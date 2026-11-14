#!/usr/local/bin/python3.12
"""FluidOS Shell: interfaz propia GTK3 + GTK Layer Shell para Wayfire.

Los controles de conectividad y multimedia son visuales en esta primera versión.
El explorador de archivos sí navega por el sistema de archivos del usuario.
"""

import os
import subprocess
import sys
from datetime import datetime

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("GtkLayerShell", "0.1")
from gi.repository import Gdk, Gio, GLib, Gtk, GtkLayerShell

APP_NAME = "FluidOS"
HOME = os.path.expanduser("~")
FOLDERS = [
    ("Escritorio", "Desktop", "▣"),
    ("Descargas", "Downloads", "↓"),
    ("Documentos", "Documents", "▤"),
    ("Imágenes", "Pictures", "▧"),
    ("Música", "Music", "♫"),
    ("Vídeos", "Videos", "▶"),
]

CSS = b"""
* { font-family: "Noto Sans", "DejaVu Sans", sans-serif; }
window { background-color: rgba(0,0,0,0); color: #f7fbff; }
button { outline: none; }
.topbar {
  background-color: rgba(5, 29, 69, 0.88);
  border-bottom: 1px solid rgba(178, 234, 255, 0.30);
  color: #f8fcff; padding: 4px 18px;
}
.brand { color: #ffffff; font-size: 19px; font-weight: 700; }
.brand-mark { color: #54efff; font-size: 25px; }
.top-item {
  color: #f4fbff; background: transparent; border: 0;
  border-radius: 10px; padding: 7px 12px; font-size: 14px;
}
.top-item:hover, .top-item:checked { background-color: rgba(255,255,255,0.17); }
.status-button {
  color: #ffffff; background: transparent; border: 0;
  border-radius: 10px; padding: 6px 8px; font-size: 17px;
}
.status-button:hover { background-color: rgba(255,255,255,0.18); }
.clock { color: #ffffff; font-size: 13px; font-weight: 600; padding-left: 8px; }
.desktop-icons { padding: 26px 24px; }
.desktop-icon {
  color: #ffffff; background: transparent; border: 1px solid transparent;
  border-radius: 14px; padding: 8px 6px; min-width: 92px;
}
.desktop-icon:hover { background-color: rgba(255,255,255,0.15); border-color: rgba(255,255,255,0.20); }
.desktop-glyph { color: #e8fbff; font-size: 39px; }
.desktop-label { color: #ffffff; font-size: 13px; text-shadow: 0 1px 5px rgba(0,0,0,.75); }
.dock {
  background-color: rgba(17, 76, 137, 0.76);
  border: 1px solid rgba(182, 239, 255, 0.40);
  border-radius: 24px; padding: 8px 14px;
}
.dock-item {
  background-color: rgba(255,255,255,0.10); border: 1px solid rgba(255,255,255,0.10);
  border-radius: 17px; color: #ffffff; min-width: 58px; min-height: 58px;
  padding: 4px; font-size: 27px;
}
.dock-item:hover { background-color: rgba(255,255,255,0.25); }
.dock-separator { background-color: rgba(255,255,255,0.35); min-width: 1px; margin: 5px 7px; }
.glass-panel {
  background-color: rgba(9, 49, 94, 0.91);
  border: 1px solid rgba(164, 232, 255, 0.48);
  border-radius: 23px; padding: 15px; color: #ffffff;
}
.panel-title { color: #ffffff; font-size: 17px; font-weight: 700; }
.panel-subtitle { color: rgba(235,248,255,.72); font-size: 12px; }
.control-tile {
  background-color: rgba(110, 177, 226, 0.23);
  border: 1px solid rgba(210,240,255,0.18);
  border-radius: 17px; color: #ffffff; padding: 11px;
  min-height: 65px;
}
.control-tile:checked { background-color: rgba(0, 139, 255, 0.70); }
.control-tile:hover { background-color: rgba(130, 205, 255, 0.32); }
.tile-glyph { font-size: 25px; color: #ffffff; }
.tile-title { font-size: 13px; font-weight: 700; color: #ffffff; }
.tile-state { font-size: 11px; color: rgba(255,255,255,.78); }
.round-control {
  background-color: rgba(103, 176, 225, 0.24); color: #ffffff;
  border: 1px solid rgba(210,240,255,0.20); border-radius: 20px;
  min-width: 66px; min-height: 66px; font-size: 24px;
}
.round-control:checked { background-color: rgba(0,135,238,.72); }
.slider-label { color: #e9f8ff; font-size: 12px; }
.notification-card {
  background-color: rgba(111, 184, 228, 0.20);
  border: 1px solid rgba(210,240,255,0.12);
  border-radius: 15px; padding: 12px;
}
.notification-heading { color: #ffffff; font-weight: 700; font-size: 13px; }
.notification-body { color: rgba(245,251,255,.88); font-size: 12px; }
.fm-window {
  background-color: rgba(238, 247, 255, 0.97); color: #132c49;
  border: 1px solid rgba(255,255,255,.8); border-radius: 20px;
}
.fm-header {
  background-color: rgba(111, 185, 235, 0.92); color: #0d2945;
  border-radius: 19px 19px 0 0; padding: 9px 12px;
}
.fm-title { color: #102b48; font-size: 16px; font-weight: 700; }
.fm-control { color: #102b48; background-color: rgba(255,255,255,.28); border: 0; border-radius: 15px; padding: 4px 9px; }
.fm-path { background-color: rgba(255,255,255,.72); color: #183858; border: 1px solid rgba(41,111,170,.15); border-radius: 12px; padding: 8px 11px; }
.fm-sidebar { background-color: rgba(198, 224, 245, 0.58); padding: 12px 9px; }
.fm-side-button {
  color: #153452; background: transparent; border: 0; border-radius: 10px;
  padding: 8px 10px; text-align: left;
}
.fm-side-button:hover, .fm-side-button:checked { background-color: rgba(0,139,255,.18); }
.fm-main { background-color: rgba(248,252,255,.82); padding: 17px; }
.folder-card {
  background-color: rgba(255,255,255,.74); color: #102b48;
  border: 1px solid rgba(41,111,170,.13); border-radius: 15px;
  min-width: 132px; min-height: 114px; padding: 12px;
}
.folder-card:hover { background-color: #ffffff; border-color: rgba(0,130,235,.38); }
.folder-glyph { font-size: 40px; color: #0788ef; }
.folder-name { color: #102b48; font-weight: 600; font-size: 13px; }
.fm-footer { color: #294762; background-color: rgba(213,232,248,.72); padding: 7px 14px; border-radius: 0 0 19px 19px; font-size: 11px; }
.launcher {
  background-color: rgba(7, 39, 82, 0.94); border: 1px solid rgba(168,230,255,.44);
  border-radius: 24px; padding: 20px;
}
.launcher-search { background-color: rgba(255,255,255,.13); color: white; border: 1px solid rgba(255,255,255,.17); border-radius: 13px; padding: 10px; }
.launcher-app { background-color: rgba(255,255,255,.10); border: 1px solid rgba(255,255,255,.10); border-radius: 17px; color: white; padding: 14px; min-width: 110px; min-height: 90px; }
.launcher-app:hover { background-color: rgba(60,164,255,.42); }
"""


def add_class(widget, name):
    widget.get_style_context().add_class(name)
    return widget


def label(text, css=None, xalign=0.0):
    item = Gtk.Label(label=text, xalign=xalign)
    if css:
        add_class(item, css)
    return item


def button(text, css, callback=None, tooltip=None):
    item = Gtk.Button(label=text)
    item.set_relief(Gtk.ReliefStyle.NONE)
    add_class(item, css)
    if tooltip:
        item.set_tooltip_text(tooltip)
    if callback:
        item.connect("clicked", lambda *_: callback())
    return item


def launch(command):
    try:
        subprocess.Popen(command, shell=True, close_fds=True)
    except Exception as exc:
        print("FluidOS: no se pudo iniciar", command, exc, file=sys.stderr)


class FluidFileManager:
    def __init__(self):
        self.window = Gtk.Window(title="Carpeta personal")
        self.window.set_default_size(790, 540)
        self.window.set_position(Gtk.WindowPosition.CENTER)
        self.window.set_decorated(False)
        self.window.set_resizable(True)
        self.window.set_name("fluidos-file-manager")
        self.window.get_style_context().add_class("fm-window")
        self.current_path = HOME
        self._build()
        self.open_path(HOME)

    def _build(self):
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=0)
        add_class(root, "fm-window")
        self.window.add(root)

        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        add_class(header, "fm-header")
        title = label("◈   Carpeta personal", "fm-title")
        header.pack_start(title, False, False, 8)
        header.pack_start(Gtk.Box(), True, True, 0)
        for glyph, action in (("−", self.window.iconify), ("□", self._toggle_maximize), ("×", self.window.hide)):
            header.pack_start(button(glyph, "fm-control", action), False, False, 0)
        header.add_events(Gdk.EventMask.BUTTON_PRESS_MASK)
        header.connect("button-press-event", self._drag_window)
        root.pack_start(header, False, False, 0)

        body = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=0)
        root.pack_start(body, True, True, 0)

        sidebar = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        add_class(sidebar, "fm-sidebar")
        sidebar.set_size_request(190, -1)
        body.pack_start(sidebar, False, False, 0)
        self.sidebar_buttons = []
        for name, folder, glyph in FOLDERS:
            path = os.path.join(HOME, folder)
            side = button(f"{glyph}   {name}", "fm-side-button", lambda p=path: self.open_path(p))
            side.set_halign(Gtk.Align.FILL)
            sidebar.pack_start(side, False, False, 0)
            self.sidebar_buttons.append(side)
        sidebar.pack_start(Gtk.Separator(orientation=Gtk.Orientation.HORIZONTAL), False, False, 8)
        sidebar.pack_start(button("▣   Equipo", "fm-side-button", lambda: self.open_path("/")), False, False, 0)
        sidebar.pack_start(button("◎   Red", "fm-side-button", lambda: self.open_path("/net")), False, False, 0)

        main = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        add_class(main, "fm-main")
        body.pack_start(main, True, True, 0)

        nav = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
        main.pack_start(nav, False, False, 0)
        nav.pack_start(button("‹", "fm-control", self.go_back), False, False, 0)
        nav.pack_start(button("›", "fm-control", self.go_home), False, False, 0)
        self.path_label = label(HOME, "fm-path")
        self.path_label.set_hexpand(True)
        nav.pack_start(self.path_label, True, True, 0)
        nav.pack_start(button("⌕", "fm-control", self.go_home), False, False, 0)

        scroller = Gtk.ScrolledWindow()
        scroller.set_policy(Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC)
        scroller.set_shadow_type(Gtk.ShadowType.NONE)
        main.pack_start(scroller, True, True, 0)
        self.grid = Gtk.FlowBox()
        self.grid.set_selection_mode(Gtk.SelectionMode.NONE)
        self.grid.set_valign(Gtk.Align.START)
        self.grid.set_max_children_per_line(3)
        self.grid.set_min_children_per_line(2)
        self.grid.set_column_spacing(12)
        self.grid.set_row_spacing(12)
        scroller.add(self.grid)

        self.footer = label("", "fm-footer")
        root.pack_start(self.footer, False, False, 0)

    def _drag_window(self, widget, event):
        if event.button == 1 and event.type == Gdk.EventType.BUTTON_PRESS:
            self.window.begin_move_drag(event.button, int(event.x_root), int(event.y_root), event.time)
        return False

    def _toggle_maximize(self):
        if self.window.is_maximized():
            self.window.unmaximize()
        else:
            self.window.maximize()

    def clear_grid(self):
        for child in self.grid.get_children():
            self.grid.remove(child)

    def add_card(self, glyph, name, callback):
        card = Gtk.Button()
        card.set_relief(Gtk.ReliefStyle.NONE)
        add_class(card, "folder-card")
        content = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        content.set_halign(Gtk.Align.CENTER)
        content.set_valign(Gtk.Align.CENTER)
        content.pack_start(label(glyph, "folder-glyph", 0.5), True, True, 0)
        content.pack_start(label(name, "folder-name", 0.5), False, False, 0)
        card.add(content)
        card.connect("clicked", lambda *_: callback())
        self.grid.add(card)

    def open_path(self, path):
        if path == "/net":
            self.current_path = path
            self.clear_grid()
            self.path_label.set_text("Red")
            self.footer.set_text("Ubicaciones de red")
            self.add_card("◎", "Red local", lambda: None)
            self.grid.show_all()
            return
        if not os.path.isdir(path):
            path = HOME
        self.current_path = os.path.abspath(path)
        self.path_label.set_text(self.current_path)
        self.clear_grid()

        if self.current_path == HOME:
            for name, folder, glyph in FOLDERS:
                full_path = os.path.join(HOME, folder)
                os.makedirs(full_path, exist_ok=True)
                self.add_card(glyph, name, lambda p=full_path: self.open_path(p))
            try:
                extra = sorted(os.listdir(HOME))
                known = {f[1] for f in FOLDERS}
                for entry in extra:
                    if entry.startswith(".") or entry in known:
                        continue
                    full = os.path.join(HOME, entry)
                    if os.path.isdir(full):
                        self.add_card("▰", entry, lambda p=full: self.open_path(p))
            except OSError:
                pass
            self.footer.set_text("6 carpetas principales")
        else:
            try:
                entries = sorted(os.scandir(self.current_path), key=lambda e: (not e.is_dir(), e.name.lower()))
            except OSError as exc:
                entries = []
                self.footer.set_text(f"No se puede abrir esta carpeta: {exc}")
            for entry in entries[:90]:
                glyph = "▰" if entry.is_dir(follow_symlinks=False) else "▤"
                self.add_card(glyph, entry.name[:22], lambda p=entry.path, d=entry.is_dir(follow_symlinks=False): self.open_path(p) if d else self.open_file(p))
            self.footer.set_text(f"{len(entries)} elementos")
        self.grid.show_all()

    def open_file(self, path):
        try:
            Gio.AppInfo.launch_default_for_uri(Gio.File.new_for_path(path).get_uri(), None)
        except Exception as exc:
            print("FluidOS: no se pudo abrir", path, exc, file=sys.stderr)

    def go_back(self):
        parent = os.path.dirname(self.current_path.rstrip("/")) or "/"
        self.open_path(parent if parent != "/" else HOME)

    def go_home(self):
        self.open_path(HOME)

    def present(self):
        self.window.show_all()
        self.window.present()


class FluidShell:
    def __init__(self):
        if not GtkLayerShell.is_supported():
            raise RuntimeError("Wayfire no ofrece zwlr_layer_shell_v1. Inicia FluidOS dentro de Wayfire.")
        self.file_manager = FluidFileManager()
        self.control_window = None
        self.notification_window = None
        self.launcher_window = None
        self._build_desktop()
        self._build_topbar()
        self._build_dock()
        self._build_control_center()
        self._build_notifications()
        self._build_launcher()
        self.update_clock()
        GLib.timeout_add_seconds(30, self.update_clock)

    def layer_window(self, name, layer, size, anchors, margins=None, keyboard=False):
        win = Gtk.Window(title=f"FluidOS {name}")
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_app_paintable(True)
        win.set_default_size(*size)
        screen = win.get_screen()
        visual = screen.get_rgba_visual() if screen else None
        if visual:
            win.set_visual(visual)
        GtkLayerShell.init_for_window(win)
        GtkLayerShell.set_namespace(win, f"fluidos-{name}")
        GtkLayerShell.set_layer(win, layer)
        for edge, enabled in anchors.items():
            GtkLayerShell.set_anchor(win, edge, enabled)
        for edge, amount in (margins or {}).items():
            GtkLayerShell.set_margin(win, edge, amount)
        GtkLayerShell.set_keyboard_mode(
            win,
            GtkLayerShell.KeyboardMode.ON_DEMAND if keyboard else GtkLayerShell.KeyboardMode.NONE,
        )
        return win

    def _build_desktop(self):
        self.desktop = self.layer_window(
            "wallpaper", GtkLayerShell.Layer.BACKGROUND, (1280, 720),
            {GtkLayerShell.Edge.TOP: True, GtkLayerShell.Edge.BOTTOM: True,
             GtkLayerShell.Edge.LEFT: True, GtkLayerShell.Edge.RIGHT: True},
        )
        overlay = Gtk.Overlay()
        self.desktop.add(overlay)
        wallpaper = Gtk.DrawingArea()
        wallpaper.connect("draw", self.draw_wallpaper)
        overlay.add(wallpaper)
        icons = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=15)
        add_class(icons, "desktop-icons")
        icons.set_halign(Gtk.Align.START)
        icons.set_valign(Gtk.Align.CENTER)
        overlay.add_overlay(icons)
        self.desktop_icon(icons, "▣", "Equipo", lambda: self.file_manager.present())
        self.desktop_icon(icons, "⌂", "Carpeta personal", lambda: self.file_manager.present())
        self.desktop_icon(icons, "▱", "Papelera", lambda: None)
        self.desktop_icon(icons, "◎", "FluidWeb", lambda: launch("xdg-open https://www.freebsd.org"))
        self.desktop.show_all()

    def desktop_icon(self, parent, glyph, name, callback):
        btn = Gtk.Button()
        btn.set_relief(Gtk.ReliefStyle.NONE)
        add_class(btn, "desktop-icon")
        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        box.pack_start(label(glyph, "desktop-glyph", 0.5), False, False, 0)
        box.pack_start(label(name, "desktop-label", 0.5), False, False, 0)
        btn.add(box)
        btn.connect("clicked", lambda *_: callback())
        parent.pack_start(btn, False, False, 0)

    def draw_wallpaper(self, widget, cr):
        width = widget.get_allocated_width()
        height = widget.get_allocated_height()
        gradient = __import__("cairo").LinearGradient(0, 0, width, height)
        gradient.add_color_stop_rgb(0.0, 0.015, 0.10, 0.29)
        gradient.add_color_stop_rgb(0.48, 0.02, 0.38, 0.73)
        gradient.add_color_stop_rgb(1.0, 0.0, 0.72, 0.73)
        cr.set_source(gradient)
        cr.rectangle(0, 0, width, height)
        cr.fill()
        cr.set_source_rgba(0.20, 0.92, 1.0, 0.20)
        cr.arc(width * 0.73, height * 0.28, min(width, height) * 0.40, 0, 6.283)
        cr.fill()
        cr.set_line_width(max(18, width * 0.012))
        cr.set_source_rgba(0.35, 0.94, 1.0, 0.28)
        cr.move_to(-width * 0.08, height * 0.72)
        cr.curve_to(width * 0.22, height * 0.30, width * 0.46, height * 1.04, width * 0.68, height * 0.66)
        cr.curve_to(width * 0.85, height * 0.38, width * 0.92, height * 0.55, width * 1.08, height * 0.71)
        cr.stroke()
        cr.set_line_width(4)
        cr.set_source_rgba(0.83, 0.99, 1.0, 0.34)
        cr.move_to(-width * 0.05, height * 0.80)
        cr.curve_to(width * 0.28, height * 0.46, width * 0.49, height * 1.08, width * 0.73, height * 0.76)
        cr.curve_to(width * 0.90, height * 0.54, width * 0.98, height * 0.64, width * 1.08, height * 0.77)
        cr.stroke()
        return False

    def _build_topbar(self):
        self.topbar = self.layer_window(
            "topbar", GtkLayerShell.Layer.TOP, (1280, 44),
            {GtkLayerShell.Edge.TOP: True, GtkLayerShell.Edge.LEFT: True, GtkLayerShell.Edge.RIGHT: True},
        )
        GtkLayerShell.set_exclusive_zone(self.topbar, 44)
        bar = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        add_class(bar, "topbar")
        self.topbar.add(bar)
        bar.pack_start(label("◈", "brand-mark"), False, False, 0)
        bar.pack_start(label("FluidOS", "brand"), False, False, 6)
        bar.pack_start(button("Aplicaciones  ▾", "top-item", self.toggle_launcher), False, False, 8)
        bar.pack_start(button("Lugares  ▾", "top-item", self.file_manager.present), False, False, 0)
        bar.pack_start(button("Sistema  ▾", "top-item", self.toggle_control), False, False, 0)
        bar.pack_start(Gtk.Box(), True, True, 0)
        bar.pack_start(button("⌁", "status-button", self.toggle_control, "Red y Wi-Fi"), False, False, 0)
        bar.pack_start(button("ᛒ", "status-button", self.toggle_control, "Bluetooth"), False, False, 0)
        bar.pack_start(button("◖", "status-button", self.toggle_control, "Sonido"), False, False, 0)
        bar.pack_start(button("▰", "status-button", self.toggle_control, "Batería"), False, False, 0)
        self.clock_label = label("", "clock")
        bar.pack_start(self.clock_label, False, False, 5)
        bar.pack_start(button("●", "status-button", self.toggle_notifications, "Notificaciones"), False, False, 0)
        self.topbar.show_all()

    def update_clock(self):
        now = datetime.now()
        days = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
        months = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]
        self.clock_label.set_text(f"{days[now.weekday()]} {now.day} {months[now.month - 1]}   {now:%H:%M}")
        return True

    def _build_dock(self):
        self.dock = self.layer_window(
            "dock", GtkLayerShell.Layer.TOP, (700, 82),
            {GtkLayerShell.Edge.BOTTOM: True}, {GtkLayerShell.Edge.BOTTOM: 17},
        )
        GtkLayerShell.set_exclusive_zone(self.dock, 82)
        dock = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
        add_class(dock, "dock")
        self.dock.add(dock)
        entries = [
            ("◈", "Inicio", self.toggle_launcher),
            ("◎", "FluidWeb", lambda: launch("xdg-open https://www.freebsd.org")),
            ("✉", "Correo", lambda: None),
            ("▣", "Archivos", self.file_manager.present),
            ("⚙", "Ajustes", lambda: launch("wcm")),
            (">_", "Terminal", lambda: launch("foot")),
        ]
        for glyph, name, action in entries:
            item = button(glyph, "dock-item", action, name)
            dock.pack_start(item, False, False, 0)
        separator = Gtk.Separator(orientation=Gtk.Orientation.VERTICAL)
        add_class(separator, "dock-separator")
        dock.pack_start(separator, False, False, 0)
        dock.pack_start(button("▱", "dock-item", lambda: None, "Papelera"), False, False, 0)
        self.dock.show_all()

    def _build_control_center(self):
        self.control_window = self.layer_window(
            "control-center", GtkLayerShell.Layer.OVERLAY, (410, 340),
            {GtkLayerShell.Edge.TOP: True, GtkLayerShell.Edge.RIGHT: True},
            {GtkLayerShell.Edge.TOP: 57, GtkLayerShell.Edge.RIGHT: 22}, True,
        )
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        add_class(root, "glass-panel")
        self.control_window.add(root)
        heading = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        heading.pack_start(label("Centro de control", "panel-title"), True, True, 0)
        heading.pack_end(button("×", "status-button", self.toggle_control), False, False, 0)
        root.pack_start(heading, False, False, 0)
        grid = Gtk.Grid()
        grid.set_row_spacing(9)
        grid.set_column_spacing(9)
        root.pack_start(grid, False, False, 0)
        self._toggle_tile(grid, 0, 0, "⌁", "Wi-Fi", "Conectado", True)
        self._toggle_tile(grid, 1, 0, "ᛒ", "Bluetooth", "Activado", True)
        row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        root.pack_start(row, False, False, 0)
        for glyph, name, active in (("✈", "Modo avión", False), ("☾", "Modo noche", False), ("☼", "Brillo", True), ("◖", "Volumen", True)):
            t = Gtk.ToggleButton(label=f"{glyph}\n{name}")
            t.set_active(active)
            add_class(t, "round-control")
            t.set_tooltip_text(name)
            row.pack_start(t, True, True, 0)
        self._add_slider(root, "☼", "Brillo", 72)
        self._add_slider(root, "◖", "Volumen", 64)
        root.pack_start(label("Controles visuales de FluidOS", "panel-subtitle"), False, False, 0)

    def _toggle_tile(self, grid, column, row, glyph, title, state, active):
        tile = Gtk.ToggleButton()
        tile.set_active(active)
        add_class(tile, "control-tile")
        content = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        content.pack_start(label(glyph, "tile-glyph"), False, False, 3)
        texts = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=3)
        texts.pack_start(label(title, "tile-title"), False, False, 0)
        texts.pack_start(label(state, "tile-state"), False, False, 0)
        content.pack_start(texts, True, True, 0)
        tile.add(content)
        grid.attach(tile, column, row, 1, 1)

    def _add_slider(self, parent, glyph, title, value):
        line = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=9)
        parent.pack_start(line, False, False, 0)
        line.pack_start(label(glyph, "slider-label"), False, False, 0)
        line.pack_start(label(title, "slider-label"), False, False, 0)
        scale = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, 0, 100, 1)
        scale.set_value(value)
        scale.set_draw_value(False)
        scale.set_hexpand(True)
        line.pack_start(scale, True, True, 0)

    def _build_notifications(self):
        self.notification_window = self.layer_window(
            "notifications", GtkLayerShell.Layer.OVERLAY, (410, 250),
            {GtkLayerShell.Edge.TOP: True, GtkLayerShell.Edge.RIGHT: True},
            {GtkLayerShell.Edge.TOP: 414, GtkLayerShell.Edge.RIGHT: 22}, True,
        )
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=11)
        add_class(root, "glass-panel")
        self.notification_window.add(root)
        header = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
        header.pack_start(label("♟  Notificaciones", "panel-title"), True, True, 0)
        header.pack_end(button("×", "status-button", self.toggle_notifications), False, False, 0)
        root.pack_start(header, False, False, 0)
        self._notification(root, "◈", "FluidOS", "¡Bienvenido a FluidOS!", "Ahora")
        self._notification(root, "⚙", "Sistema", "El escritorio está iniciado.", "Ahora")
        root.pack_start(button("Ver todas las notificaciones", "top-item", lambda: None), False, False, 0)

    def _notification(self, parent, glyph, title, body, when):
        card = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=10)
        add_class(card, "notification-card")
        card.pack_start(label(glyph, "tile-glyph"), False, False, 2)
        text_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        text_box.pack_start(label(title, "notification-heading"), False, False, 0)
        text_box.pack_start(label(body, "notification-body"), False, False, 0)
        card.pack_start(text_box, True, True, 0)
        card.pack_end(label(when, "panel-subtitle"), False, False, 0)
        parent.pack_start(card, False, False, 0)

    def _build_launcher(self):
        self.launcher_window = self.layer_window(
            "launcher", GtkLayerShell.Layer.OVERLAY, (480, 440), {}, {}, True,
        )
        root = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        add_class(root, "launcher")
        self.launcher_window.add(root)
        root.pack_start(label("Aplicaciones", "panel-title"), False, False, 0)
        search = Gtk.Entry()
        search.set_placeholder_text("Buscar aplicaciones…")
        add_class(search, "launcher-search")
        root.pack_start(search, False, False, 0)
        grid = Gtk.Grid()
        grid.set_row_spacing(10)
        grid.set_column_spacing(10)
        root.pack_start(grid, True, True, 0)
        apps = [
            ("▣", "Archivos", self.file_manager.present),
            (">_", "Terminal", lambda: launch("foot")),
            ("⚙", "Ajustes", lambda: launch("wcm")),
            ("◎", "FluidWeb", lambda: launch("xdg-open https://www.freebsd.org")),
            ("◈", "FluidOS", self.toggle_control),
            ("▱", "Papelera", lambda: None),
        ]
        for i, (glyph, name, action) in enumerate(apps):
            item = button(f"{glyph}\n{name}", "launcher-app", action)
            grid.attach(item, i % 3, i // 3, 1, 1)

    def toggle_control(self):
        self._toggle_window(self.control_window)

    def toggle_notifications(self):
        self._toggle_window(self.notification_window)

    def toggle_launcher(self):
        self._toggle_window(self.launcher_window)

    @staticmethod
    def _toggle_window(window):
        if window.get_visible():
            window.hide()
        else:
            window.show_all()
            window.present()

    def run(self):
        self.file_manager.present()
        self.control_window.show_all()
        self.notification_window.show_all()
        self.launcher_window.hide()
        Gtk.main()


def main():
    provider = Gtk.CssProvider()
    provider.load_from_data(CSS)
    Gtk.StyleContext.add_provider_for_screen(
        Gdk.Screen.get_default(), provider, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
    )
    try:
        FluidShell().run()
    except Exception as exc:
        print(f"[FluidOS] No se pudo iniciar el escritorio: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
