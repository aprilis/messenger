using Gtk;
using GLib;
using WebKit;

namespace Ui {
    
    public class SignUp : Screen {
        private const string SIGNUP_URL = "https://www.facebook.com/signup?display=popup";
    
        private WebView view;
        
        private Loading loading;
        
        private Stack stack;
        
        private bool dont_hide = false;
        
        public SignUp () {
            title = "Sign Up";
            name = "sign_up";
        
            view = null;
            loading = new Loading (40, 15);
            stack = new Stack ();
            stack.add_named (loading, "loading");
            widget = stack;
        }
        
        public override void show () {
            if (view != null) {
                dont_hide = true;
                Timeout.add (200, () => {
                    dont_hide = false;
                    return false;
                });
            } else {
                view = new WebView ();
                view.load_changed.connect ((load_event) => {
                    if (load_event == LoadEvent.FINISHED) {
                        stack.visible_child = view;
                    }
                });
                view.zoom_level = 0.7;
                view.show ();
                stack.add_named (view, "view");
            }
            stack.visible_child = loading;
            view.load_uri (SIGNUP_URL);
        }
        
        public override void hide () {
            if (!dont_hide) {
                stack.visible_child = loading;
                stack.remove (view);
                view = null;
            }
        }
    }
    
}
