using GLib;
using Gtk;

namespace Ui {
    public class Utils {
    
        public static InfoBar create_infobar (string text, MessageType type, bool close_button) {
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
}
