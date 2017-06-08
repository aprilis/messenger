using GLib;
using Gtk;
using WebKit;
using Granite.Widgets;

namespace Ui {

    public class Conversation : PopOver {
            
        private class View {
        
            private const string MESSENGER_URL = "https://www.messenger.com";
            private const string LOGIN_URL = MESSENGER_URL + "/login";
            
            private const string STYLE_SHEET = """
                div._1enh {
                    max-width: 0px;
                    min-width: 0px;
                }
                div._1q5- {
                    border-left: none
                }
                a._30yy._2oc8 {
                    display: none
                }
                """;

            private const string CHANGE_USER_SCRIPT = """
                try {
                    document.title = 'loading';
                    id = '%lld';
                    element = document.getElementById('row_header_id_user:' + id);
                    if (element == null) {
                        element = document.getElementById('row_header_id_thread:' + id);
                    }
                    link = element.getElementsByTagName('a')[0];
                    link.click();
                    document.title = 'success';
                } catch(err) {
                    document.title = 'fail';
                }
            """;
        
            private int64 last_id;
            private bool user_changed = false;

            public WebView webview { get; private set; }
            
            public signal void ready ();
            public signal void auth_failed ();
            public signal void load_failed ();

            private void load_conversation (Fb.Id id) {
                last_id = id;
                var uri = MESSENGER_URL + "/t/" + id.to_string ();
                webview.load_uri (uri);
                user_changed = true;
            }

            private void run_script () {
                user_changed = true;
                webview.run_javascript (CHANGE_USER_SCRIPT.printf (last_id), null);
            }
            
            private bool decide_policy (PolicyDecision decision, PolicyDecisionType type) {
                var nav = decision as NavigationPolicyDecision;
                if (nav != null && nav.request.get_http_method () == "GET") {
                    var uri = nav.request.uri;
                    try {
                        var address = NetworkAddress.parse_uri (uri, 1);
                        if ((nav.frame_name != null || address.hostname.has_suffix ("fbcdn.net"))
                                 && address.hostname != "www.messenger.com") {
                            AppInfo.launch_default_for_uri (nav.request.uri, null);
                            nav.ignore ();
                            return true;
                        }
                    } catch (Error e) {
                        warning ("Error %s\n", e.message);
                    }
                }
                return false;
            }

            public View () {       
                var style_sheet = new UserStyleSheet (STYLE_SHEET, UserContentInjectedFrames.TOP_FRAME,
                                                         UserStyleLevel.AUTHOR, null, null);
                var content_manager = new UserContentManager ();
                content_manager.add_style_sheet (style_sheet);

                webview = new WebView.with_user_content_manager (content_manager);
                var settings = webview.get_settings ();
                settings.enable_write_console_messages_to_stdout = true;
                
                webview.load_changed.connect ((load_event) => {
                    if (load_event == LoadEvent.COMMITTED) {
                        if (webview.get_uri ().has_prefix (LOGIN_URL)) {
                            last_id = 0;
                            auth_failed ();
                            return;
                        }
                        if (last_id != 0) {
                            if (!user_changed) {
                                run_script ();
                            } else {
                                Timeout.add (500, () => {
                                    ready ();
                                    return false;
                                });
                            }
                        }
                    }
                });
                webview.notify ["title"].connect ((s, p) => {
                    if (webview.title == "success") {
                        ready ();
                    } else if (webview.title == "fail" && last_id != 0) {
                        load_conversation (last_id);
                    }
                });
                webview.context_menu.connect (() => { return true; });
                webview.show_notification.connect (() => { return true; });
                webview.decide_policy.connect (decide_policy);
                
                webview.load_failed.connect ((event, uri, error) => { print ("network error: %s %d\n", error.message, error.code); load_failed (); return false; });
                load_home_page ();
            }
            
            public bool load (Fb.Id id) {
                if (last_id == id) {
                    return false;
                }
                last_id = id;
                if (!webview.is_loading) {
                    run_script ();
                } else {
                    user_changed = false;
                }
                return true;
            }

            public void load_home_page () {
                if (!webview.is_loading) {
                    webview.load_uri (MESSENGER_URL);
                }
                last_id = 0;
            }
        }
        
        private class LoginView {
            
            private const string MESSENGER_URL = "https://www.messenger.com";
        
            private const string LOGIN_URL = MESSENGER_URL + "/login";
            private const string FAIL_URL = LOGIN_URL + "/password";
            
            private const string LOGIN_SCRIPT = """
                document.onreadystatechange = function () {
                    if (document.readyState == 'complete') {
                        document.getElementById('email').value = '%s';
                        document.getElementById('pass').value = '%s';
                        document.getElementById('u_0_3').checked = true;
                        document.getElementById('login_form').submit();
                    }
                }​;
                """;
                
            private WebView webview;
            private string username;
            private string password;
                
            public signal void finished (LoginView view);
            
            public signal void failed (LoginView view);
            
            public signal void load_failed (LoginView view);
                
            public LoginView (string user, string pass) {                
                username = user;
                password = pass;
                WebContext.get_default ().get_cookie_manager ().delete_all_cookies ();
                webview = new WebView ();
                webview.load_changed.connect ((load_event) => {
                    if (load_event == LoadEvent.FINISHED) {
                        var uri = webview.get_uri ();
                        if (uri.has_prefix (FAIL_URL)) {
                            username = "";
                            password = "";
                            failed (this);
                        } else if (uri.has_prefix (LOGIN_URL)) {
                            webview.run_javascript (LOGIN_SCRIPT.printf(username, password).to_ascii (), null);
                        } else {
                            username = "";
                            password = "";
                            finished (this);
                        }
                    }
                });
                webview.load_failed.connect ((event, uri, error) => { load_failed (this); return false; });
                webview.load_uri (LOGIN_URL);
            }
        
            public void destroy () {
                webview.destroy ();
            }
        
        }

        private Loading loading;
        private Stack stack;
        
        private View view;
        private LoginView login_view;
        private ScrolledWindow view_window;
        
        private Fb.App app;

        private void clear_login_view () {
            if (login_view != null) {
                login_view.destroy ();
            }
            login_view = null;
        }
        
        public int64 current_id { get; private set; default = 0;}
        
        public void load_conversation (Fb.Id id) {
            current_id = id;
            if (view.load (id)) {
                stack.visible_child = loading;
            } else {
                view_window.show_now ();
                stack.visible_child = view_window;
            }
            if (is_active) {
                close (true);
            }
        }
        
        public void reload () {
            view.load_home_page ();
        }
        
        public new void show (int x, int y) {
            move (x, y);
            set_size_request (700, 500);
            activate ();
            present ();
        }
        
        public Conversation (Fb.App _app) {
            var context = WebContext.get_default ();
            var manager = context.get_cookie_manager ();
            manager.set_persistent_storage (Main.cache_path + "/cookies", CookiePersistentStorage.TEXT);

            app = _app;
        
            set_size_request (700, 500);
            
            view_window = new ScrolledWindow (null, null);
            //view_window.hscrollbar_policy = PolicyType.NEVER;
            //view_window.vscrollbar_policy = PolicyType.NEVER;

            loading = new Loading (40);
            
            stack = new Stack ();
            stack.margin_bottom = ARROW_HEIGHT;
            stack.margin_left = stack.margin_right = stack.margin_top = SHADOW_SIZE;
            stack.add_named (loading, "loading");
            stack.add_named (view_window, "conversation");

            view = new View ();
            view.ready.connect (() => {
                view_window.show_now ();
                stack.visible_child = view_window;
            });
            view.load_failed.connect (() => { app.network_error (); });
            view.auth_failed.connect (() => { clear_cookies (); app.show_login_dialog (false); });

            
            view_window.add (view.webview);
            add (stack);
        }
        
        public void log_in (string username, string password) {
            clear_login_view ();
            login_view = new LoginView (username, password);
            login_view.finished.connect ((lv) => {
                if (login_view != lv) {
                    return;
                }
                clear_login_view ();
                view.load_home_page ();
                app.auth_target_done (Fb.App.AuthTarget.WEBVIEW);
            });
            login_view.failed.connect ((lv) => {
                if (login_view != lv) {
                    return;
                }
                clear_login_view ();
                app.show_login_dialog (true);
            });
            login_view.load_failed.connect ((lv) => {
                if (login_view != lv) {
                    return;
                }
                clear_login_view ();
                app.network_error ();
            });
        }

        public void clear_cookies () {
            WebContext.get_default ().get_cookie_manager ().delete_all_cookies ();
        }
        
        public void log_out () {
            clear_cookies ();
            view.load_home_page ();
        }
    }

}
