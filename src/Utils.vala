using GLib;
using Gtk;
using Gdk;

namespace Utils {

    public delegate void Operation ();

    public bool my_id_equal (Fb.Id? a, Fb.Id? b) {
        return a == b;
    }
    
    public uint my_id_hash (Fb.Id? id) {
        return (uint) id;
    }

    Pixbuf make_icon (Pixbuf? photo, int size, bool line = false) {  
        Pixbuf pixbuf;
        if (photo == null) {
            pixbuf = new Pixbuf(Colorspace.RGB, true, 8, size, size);
            pixbuf.fill ((uint32)0xffffffff);
        } else {
            pixbuf = photo;
        }
    
        var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
        var context = new Cairo.Context (surface);
        var center = size * 0.5, radius = center * 0.95;
        
        context.arc (center, center, radius, 0, 2 * Math.PI);
        var scale = size / (double)pixbuf.width;
        context.scale (scale, scale);
        cairo_set_source_pixbuf (context, pixbuf, 0, 0);
        context.fill_preserve ();
        if (line) {
            context.scale (1 / scale, 1 / scale);
            context.set_source_rgba (0, 0, 0, 0.5);
            context.set_line_width (0.5);
            context.stroke ();
        }
        
        pixbuf = pixbuf_get_from_surface (surface, 0, 0, size, size);
        if (pixbuf == null) {
            warning ("Failed to create pixbuf");
            pixbuf = new Pixbuf(Colorspace.RGB, true, 8, size, size);
            pixbuf.fill ((uint32)0xaaaaaaff);
        }
        return pixbuf;
    }

    public class DelayedOps : Object {

        private class OpWrapper {
            private Operation op;

            public OpWrapper (owned Operation o) {
                op = (owned)o;
            }

            public void run () {
                op ();
            }
        }

        private GLib.List<OpWrapper> ops = new GLib.List<OpWrapper> ();
        private bool released = false;

        public void add (owned Operation op) {
            if (released) {
                op ();
            } else {
                ops.append (new OpWrapper ((owned)op));
            }
        }

        public void release () {
            if (!released) {
                released = true;
                foreach (var op in ops) {
                    op.run ();
                }
                ops = null;
            }
        }
    }

    public InfoBar create_infobar (string text, MessageType type, bool close_button) {
        var bar = new InfoBar ();
        bar.message_type = type;
        bar.show_close_button = close_button;
        bar.no_show_all = true;
        
        var container = bar.get_content_area ();
        var label = new Label (text);
        label.show ();
        container.add (label);
        
        if (close_button) {
            bar.close.connect (() => { bar.visible = false; });
            bar.response.connect ((id) => { if (id <= 0) bar.visible = false; });
        }
        
        return bar;
    }
}
