using GLib;
using Gtk;

namespace Utils {

    public delegate void Operation ();

    public bool my_id_equal (Fb.Id? a, Fb.Id? b) {
        return a == b;
    }
    
    public uint my_id_hash (Fb.Id? id) {
        return (uint) id;
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
