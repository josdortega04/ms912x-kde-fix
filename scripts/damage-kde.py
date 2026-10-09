#!/usr/bin/env python3
import gi

gi.require_version('Gtk', '4.0')
from gi.repository import Gtk, GLib


class DamageMaker(Gtk.Application):
    def __init__(self):
        super().__init__(application_id='com.kalahari.damagekde')
        self.counter = 0

    def do_activate(self):
        win = Gtk.ApplicationWindow(application=self)
        win.set_default_size(8, 8)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("damage")

        # Opacidad global de la ventana: 12 %
        win.set_opacity(0.12)

        area = Gtk.DrawingArea()
        area.set_draw_func(self.on_draw)
        win.set_child(area)
        win.present()

        self.win = win
        self.area = area
        GLib.timeout_add(500, self.tick)

    def on_draw(self, area, cr, w, h):
        # Color oscuro y poco llamativo
        c = (self.counter % 200) / 200.0
        cr.set_source_rgb(0.18, 0.025 + c * 0.08, 0.025)
        cr.paint()

    def tick(self):
        self.counter += 1
        self.area.queue_draw()
        return GLib.SOURCE_CONTINUE


DamageMaker().run(None)
