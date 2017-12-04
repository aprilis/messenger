using GLib;
using Gtk;

namespace Ui { 
    public class Settings : Granite.Services.Settings { 

        private const int MIN_DIMENSION = 100;

        public string close_and_remove_shortcut { get; set; }
        public bool create_new_bubbles { get; set; }
        public string title_bar_color { get; set; }
        public int chat_width { get; set; }
        public int chat_height { get; set; }
        public int window_width { get; set; }
        public int window_height { get; set; }

        public Settings () {
            base ("com.github.aprilis.messenger");
        }

        protected override void verify (string key) {
            switch (key) {
                case "title-bar-color":
                    var col = new Gdk.RGBA ();
                    if (!col.parse (title_bar_color)) {
                        title_bar_color = "white";
                    }
                    break;
                case "close-and-remove-shortcut":
                    if(close_and_remove_shortcut != "") {
                        uint acc_key;
                        Gdk.ModifierType acc_mod;
                        accelerator_parse(close_and_remove_shortcut, out acc_key, out acc_mod);
                        if (acc_key == 0 && acc_mod == (Gdk.ModifierType) 0) {
                            close_and_remove_shortcut = "";
                        }
                    }
                    break;
                case "chat-width":
                    if (chat_width < MIN_DIMENSION) {
                        chat_width = MIN_DIMENSION;
                    }
                    break;
                case "chat-height":
                    if (chat_height < MIN_DIMENSION) {
                        chat_height = MIN_DIMENSION;
                    }
                    break;
                case "window-width":
                    if (window_width < MIN_DIMENSION) {
                        window_width = MIN_DIMENSION;
                    }
                    break;
                case "window-height":
                    if (window_height < MIN_DIMENSION) {
                        window_height = MIN_DIMENSION;
                    }
                    break;
            }
        }
    }
}