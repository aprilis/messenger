using Gtk;
using Gdk;

namespace Ui {

    public class HeaderBar : Gtk.HeaderBar {
        public const int PHOTO_SIZE = 32;
    
        private Image picture;
        
        //private ToggleButton search_button;
        
        public void set_photo (Pixbuf photo) {
            picture.pixbuf = photo;
        }
        
        public void clear_photo () {
            picture.clear ();
        }
        
        public void set_menu (GLib.Menu menu) {
            var menu_button = new Gtk.MenuButton ();
            var image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            menu_button.image = image;
            menu_button.menu_model = menu;
            pack_end (menu_button);
        }
    
        public HeaderBar () {
            show_close_button = true;
            
            picture = new Gtk.Image ();
            picture.margin_start = 40;
            picture.margin_end = 10;
            pack_start (picture);
        }
    }

}
