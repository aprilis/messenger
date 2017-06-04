using Gtk;
using GLib;

namespace Ui {
    
    public class SignIn : Screen {
        private Entry login;
        
        private Entry password;
        
        private Button sign_in_button;
        
        private Button back_button;
        
        private Widget[] login_widgets;
        
        public signal void log_in (string username, string password);
        
        public InfoBar network_error_bar { get; private set; }
        
        public InfoBar auth_error_bar { get; private set; }
        
        private void set_login_widgets_sensitive (bool sensitive) {
            foreach (var w in login_widgets) {
                w.sensitive = sensitive;
            }
        }
        
        private void emit_log_in () {
            if (login.text != "" && password.text != "") {
                set_login_widgets_sensitive (false);
                log_in (login.text, password.text);
            }
        }
    
        public SignIn () {
            title = "Sign In";
            name = "sign_in";
        
            var icon = new Image.from_icon_name ("user-info", IconSize.DIALOG);
            var label = new Label ("Enter your login and password");
            label.justify = Gtk.Justification.CENTER;
            label.hexpand = true;
            label.wrap = true;
            label.wrap_mode = Pango.WrapMode.WORD;
            label.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            label.get_style_context ().add_class ("h2");
        
            login = new Entry ();
            login.placeholder_text = "Email or phone number";
            login.has_frame = true;
            
            password = new Entry ();
            password.placeholder_text = "Password";
            password.visibility = false;
            password.caps_lock_warning = true;
            
            login.activate.connect (emit_log_in);
            password.activate.connect (emit_log_in);
            
            sign_in_button = new Button.with_label ("Sign In");
            var style_ctx = sign_in_button.get_style_context ();
            style_ctx.add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            style_ctx.add_class ("h3");
            sign_in_button.clicked.connect (emit_log_in);
            sign_in_button.height_request = 30;
            
            back_button = new Button.with_label ("Back");
            back_button.clicked.connect (() => {
                change_screen ("welcome");
            });
            back_button.get_style_context ().add_class ("h3");
            back_button.height_request = 30;
            
            var button_box = new Box (Orientation.HORIZONTAL, 5);
            button_box.pack_start (back_button);
            button_box.pack_start (sign_in_button);
            
            network_error_bar = Utils.create_infobar ("Connection failed", MessageType.ERROR, true);
            auth_error_bar = Utils.create_infobar ("Wrong username or password", MessageType.ERROR, true);
            
            var box1 = new Box (Orientation.VERTICAL, 5);
            box1.pack_start (icon, false, false);
            box1.pack_start (label, false, false, 10);
            box1.pack_start (login);
            box1.pack_start (password);
            box1.pack_start (button_box, false, false, 30);
            box1.margin = 40;
            
            var box2 = new Box (Orientation.VERTICAL, 0);
            box2.pack_start (network_error_bar, false);
            box2.pack_start (auth_error_bar, false);
            box2.pack_start (box1, true, false);
            widget = box2;
            
            style_ctx = widget.get_style_context ();
            style_ctx.add_class (Gtk.STYLE_CLASS_VIEW);
            style_ctx.add_class ("welcome");
            
            login_widgets = { login, password, sign_in_button, back_button };
        }
        
        public override void hide () {
            login.text = "";
            password.text = "";
            network_error_bar.visible = false;
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
        }
        
        public override void cowardly_user () {
            login.text = "";
            password.text = "";
            set_login_widgets_sensitive (true);
        }
        
    }
    
}   
