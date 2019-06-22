using Gtk;
using GLib;

namespace Ui {
    
    public class Welcome : Screen {
        private const string SIGNUP_URL = "https://www.facebook.com/signup";    
        
        public Welcome () {
            var welcome = new Granite.Widgets.Welcome (_("Messenger"), _("Sign in with Facebook to get started."));
            welcome.append ("document-export", _("Sign In"), _("Login to existing account"));
            welcome.append ("contact-new", _("Sign Up"), _("Create a new account"));
            widget = welcome;
            
            title = _("Welcome");
            name = "welcome";
            
            welcome.activated.connect ((index) => {
                if (index == 0) {
                    change_screen ("sign_in");
                } else if (index == 1) {
                    //change_screen ("sign_up");
                    try {
                        AppInfo.launch_default_for_uri (SIGNUP_URL, null);
                    } catch (Error e) {
                        warning ("Glib error: %s", e.message);
                    }
                    
                }
            });
            
        }
        
    }
    
}
