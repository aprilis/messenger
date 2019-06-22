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

    public string get_time_description (int64 time, out int64 next_update_time) {
        if (time == 0) {
            next_update_time = 0;
            return "";
        }
        var now = get_real_time () / 1000000;
        var diff = now - time;
        if (diff < 60) {
            next_update_time = 60 - (diff % 60);
            return _("now");
        } else if (diff < 60*60) {
            next_update_time = 60 - (diff % 60);
            return _("%s min").printf((diff / 60).to_string ());
        } else {
            var date1 = new Date ();
            date1.set_time_t ((time_t)time);
            var date2 = new Date ();
            date2.set_time_t ((time_t)now);
            var tm = Time.local ((time_t)time);
            int days = date1.days_between (date2);
            if (days == 0) {
                Time next_day;
                date2.add_days (1);
                date2.to_time (out next_day);
                next_update_time = 60*60 - (diff % (60*60));
                return _("%s hrs").printf((diff / (60*60)).to_string ());
            } else if (days < 7) {
                Time next_day;
                date2.add_days (1);
                date2.to_time (out next_day);
                next_update_time = next_day.mktime () - now;
                return tm.format ("%a").chomp ();
            } else {
                next_update_time = 0;
                return tm.format ("%e %b").chomp ();
            }
        }
    }
}
