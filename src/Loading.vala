using Gtk;
using GLib;

namespace Ui {
    
    public class Loading : Box {
    
        private string _text;

        private Label label;

        private void update_markup () {
            label.set_markup ("""<span foreground = "grey">%s</span>""".printf(text));
        }

        public string text {
            get { return _text; }
            set { _text = value; update_markup (); }
        }

        public Loading (int spinner_size, string txt = "Loading...") {

            Object(orientation: Orientation.VERTICAL, spacing: 10);
            
            var spinner = new Spinner ();
            spinner.set_size_request (spinner_size, spinner_size);
            spinner.expand = false;
            spinner.start ();
            
            label = new Label ("");
            label.get_style_context ().add_class (Granite.STYLE_CLASS_H2_LABEL);
            text = txt;
            
            var box = new Box (Orientation.VERTICAL, 10);
            box.pack_start (spinner, false, false);
            box.pack_end (label, false, false);
            
            pack_start (box, true, false);
        
        }
    
    }
    
}
