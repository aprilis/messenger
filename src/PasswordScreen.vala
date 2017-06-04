using GLib;
using Gtk;

namespace Ui {

    public class PasswordScreen : Screen {
        
        private Entry password;
        
        private Button log_out_button;
        
        private Button done_button;
        
        private Widget[] login_widgets;
    
        public InfoBar network_error_bar { get; private set; }
        
        public InfoBar auth_error_bar { get; private set; }

        public InfoBar other_error_bar { get; private set; }
        
        public signal void log_out ();
        
        public signal void done (string password);
        
        private void set_login_widgets_sensitive (bool sensitive) {
            foreach (var w in login_widgets) {
                w.sensitive = sensitive;
            }
        }
        
        private void emit_done () {
            if (password.text != "") {
                set_login_widgets_sensitive (false);
                done (password.text);
            }
        }
    
        public PasswordScreen () {
            title = "Re-enter password";
            name = "password";
            
            var icon = new Image.from_icon_name ("dialog-password", IconSize.DIALOG);
            var label = new Label ("You must re-enter your password");
            label.justify = Gtk.Justification.CENTER;
            label.hexpand = true;
            label.wrap = true;
            label.wrap_mode = Pango.WrapMode.WORD;
            label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            label.get_style_context ().add_class ("h2");
            
            log_out_button = new Button.with_label ("Log out");
            var style_ctx = log_out_button.get_style_context ();
            style_ctx.add_class (Gtk.STYLE_CLASS_DESTRUCTIVE_ACTION);
            style_ctx.add_class ("h3");
            log_out_button.height_request = 30;
            log_out_button.clicked.connect (() => { log_out(); });
            
            done_button = new Button.with_label ("Done");
            done_button.get_style_context ().add_class ("h3");
            done_button.height_request = 30;
            done_button.clicked.connect (emit_done);
            
            password = new Entry ();
            password.placeholder_text = "Password";
            password.visibility = false;
            password.caps_lock_warning = true;
            password.activate.connect (emit_done);

            network_error_bar = Utils.create_infobar ("Connection failed", MessageType.ERROR, true);
            auth_error_bar = Utils.create_infobar ("Wrong username or password", MessageType.ERROR, true);
            other_error_bar = Utils.create_infobar ("Other error", MessageType.ERROR, true);
            
            var button_box = new Box (Orientation.HORIZONTAL, 5);
            button_box.pack_start (log_out_button);
            button_box.pack_start (done_button);
            
            var box1 = new Box (Orientation.VERTICAL, 5);
            box1.pack_start (icon, false, false);
            box1.pack_start (label, false, false, 10);
            box1.pack_start (password);
            box1.pack_start (button_box, false, false, 30);
            box1.margin = 40;
            
            var box2 = new Box (Orientation.VERTICAL, 0);
            box2.pack_start (network_error_bar, false);
            box2.pack_start (auth_error_bar, false);
            box2.pack_start (other_error_bar, false);
            box2.pack_start (box1, true, false);
            widget = box2;
            
            login_widgets = { password, log_out_button, done_button };
        }
        
        public override void hide () {
            password.text = "";
            network_error_bar.visible = false;
            other_error_bar.visible = false;
            auth_error_bar.visible = false;
            set_login_widgets_sensitive (true);
        }
        
        public override void network_error () {
            network_error_bar.visible = true;
            set_login_widgets_sensitive (true);
        }
        
        public override void auth_error () {
            network_error_bar.visible = false;
            auth_error_bar.visible = true;
            set_login_widgets_sensitive (true);
        }
        
        public override void network_ok () {
            network_error_bar.visible = false;
            other_error_bar.visible = false;
        }

        public override void other_error () {
            other_error_bar.visible = true;
            set_login_widgets_sensitive (true);
        }
    
    }

}
