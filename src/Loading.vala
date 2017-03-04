using Gtk;
using GLib;

namespace Ui {
    
    public class Loading : Box {
    
        public Loading (int spinner_size, int label_size) {
            
            Object(orientation: Orientation.VERTICAL, spacing: 10);
            
            var spinner = new Spinner ();
            spinner.set_size_request (spinner_size, spinner_size);
            spinner.expand = false;
            spinner.start ();
            
            var label = new Label ("");
            label.set_markup ("""<span font_desc = "%d" foreground = "grey">loading...</span>""".printf(label_size));
            
            var box = new Box (Orientation.VERTICAL, 10);
            box.pack_start (spinner, false, false);
            box.pack_end (label, false, false);
            
            pack_start (box, true, false);
        
        }
    
    }
    
}
