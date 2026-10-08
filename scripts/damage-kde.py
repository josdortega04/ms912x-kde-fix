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
        win.set_default_size(64, 64)
        win.set_decorated(False)
        win.set_resizable(False)
        win.set_title("damage")

        area = Gtk.DrawingArea()
        area.set_draw_func(self.on_draw)
        win.set_child(area)
        win.present()

        self.win = win
        self.area = area
        GLib.timeout_add(500, self.tick)  # 2 fps, muy lento

    def on_draw(self, area, cr, w, h):
        c = (self.counter % 200) / 200.0
        cr.set_source_rgb(1.0, c, 0.0)
        cr.paint()

    def tick(self):
        self.counter += 1
        self.area.queue_draw()
        return True

DamageMaker().run(None)
