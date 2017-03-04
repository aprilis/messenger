using Gtk;
using Gdk;

namespace Ui {

    public class HeaderBar : Gtk.HeaderBar {
        public const int PHOTO_SIZE = 32;
    
        private Image picture;
        
        private ToggleButton search_button;
        
        public void set_photo (Pixbuf photo) {
            picture.pixbuf = photo;
        }
        
        public void clear_photo () {
            picture.clear ();
        }
        
        public void set_menu (Gtk.Menu menu) {
            var app_menu = new Granite.Widgets.AppMenu (menu);
            var image = new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            app_menu.icon_widget = image;
            pack_end (app_menu);
        }
    
        public HeaderBar () {
            show_close_button = true;
            
            picture = new Gtk.Image ();
            picture.margin_left = 40;
            picture.margin_right = 10;
            pack_start (picture);
        }
    }

}
