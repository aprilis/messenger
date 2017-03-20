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
                
            private static int count = 0;
            
            private static UserContentManager content_manager = null;
            
            private int number;
            private string username;
            private string password;
        
            public WebView webview { get; private set; }
            public Fb.Id last_id { get; private set; default = 0; }
            public int64 last_used { get; private set; default = 0; }
            public bool reload { get; set; default = false; }
            public string id { owned get { return number.to_string (); } }
            
            public signal void ready (View view);
            public signal void auth_failed ();
            public signal void load_failed ();
            
            public bool decide_policy (PolicyDecision decision, PolicyDecisionType type) {
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
            
            static construct {
                var style_sheet = new UserStyleSheet (STYLE_SHEET, UserContentInjectedFrames.TOP_FRAME,
                                                         UserStyleLevel.AUTHOR, null, null);
                content_manager = new UserContentManager ();
                content_manager.add_style_sheet (style_sheet);
            }

            public View () {            
                number = count++;
                webview = new WebView.with_user_content_manager (content_manager);
                var settings = webview.get_settings ();
                settings.enable_write_console_messages_to_stdout = true;
                
                webview.load_changed.connect ((load_event) => {
                    if (load_event == LoadEvent.COMMITTED) {
                        if (webview.get_uri ().has_prefix (LOGIN_URL)) {    
                            auth_failed ();
                            return;
                        }
                        if (last_id != 0) {
                            Timeout.add (500, () => {
                                ready (this);
                                return false;
                            });
                        } else {
                            reload = true;
                        }
                    }
                });
                webview.context_menu.connect (() => { return true; });
                webview.show_notification.connect (() => { return true; });
                webview.decide_policy.connect (decide_policy);
                
                webview.load_failed.connect ((event, uri, error) => { load_failed (); return false; });
            }
            
            public bool load (Fb.Id id) {
                last_used = get_monotonic_time ();
                last_id = id;
                var uri = MESSENGER_URL + "/t/" + id.to_string ();
                if (!reload && webview.get_uri () == uri) {
                    return false;
                }
                reload = false;
                webview.load_uri (uri);
                return true;
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
                
            public signal void finished ();
            
            public signal void failed ();
            
            public signal void load_failed ();
                
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
                            failed ();
                        } else if (uri.has_prefix (LOGIN_URL)) {
                            webview.run_javascript (LOGIN_SCRIPT.printf(username, password).to_ascii (), null);
                        } else {
                            username = "";
                            password = "";
                            finished ();
                        }
                    }
                });
                webview.load_failed.connect ((event, uri, error) => { load_failed (); return false; });
                webview.load_uri (LOGIN_URL);
            }
        
            public void destroy () {
                webview.destroy ();
            }
        
        }
        
        public const int64 CACHE_INTERVAL = 1000000 * 60 * 10; //10 minutes
        public const int CACHE_LIMIT = 3;

        private Loading loading;
        private Stack stack;
        
        private List<View> cache;
        private LoginView login_view;
        
        private Fb.App app;
        
        private View get_view (Fb.Id id = 0) {
            View best = null;
            foreach (var view in cache) {
                if (view.last_id == id) {
                    best = view;
                    break;
                }
                if (best == null || best.last_used > view.last_used) {
                    best = view;
                }
            }
            var time = get_monotonic_time ();
            if (best == null || (best.last_id != id && time - best.last_used < CACHE_INTERVAL
                 && cache.length () < CACHE_LIMIT)) {
                best = new View ();
                stack.add_named (best.webview, best.id);
                best.ready.connect ((view) => {
                    if (view.last_id == current_id) {
                        stack.visible_child = view.webview;
                        view.webview.show_now ();
                    }
                });
                best.load_failed.connect (() => { app.network_error (); });
                best.auth_failed.connect (() => { app.auth_needed (); });
                cache.append (best);
            }
            return best;
        }
        
        private void clear_login_view () {
            if (login_view != null) {
                login_view.destroy ();
            }
            login_view = null;
        }
        
        private void clear_cache () {
            foreach (var view in cache) {
                stack.remove (view.webview);
            }
            cache = new List<View> ();
        }
        
        public int64 current_id { get; private set; default = 0;}
        
        public void load_conversation (Fb.Id id) {
            current_id = id;
            var view = get_view (id);
            if (view.load (id)) {
                stack.visible_child = loading;
            } else {
                stack.visible_child = view.webview;
                view.webview.show_now ();
            }
            if (is_active) {
                close (true);
            }
        }
        
        public void reload (Fb.Id id) {
            foreach (var view in cache) {
                if (view.last_id == id) {
                    view.reload = true;
                }
            }
        }
        
        public void reload_all () {
            foreach (var view in cache) {
                view.reload = true;
            }
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
            
            var scrolled = new ScrolledWindow (null, null);
            scrolled.hscrollbar_policy = PolicyType.NEVER;
            scrolled.vscrollbar_policy = PolicyType.NEVER;

            loading = new Loading (40);
            
            stack = new Stack ();
            stack.margin_bottom = ARROW_HEIGHT;
            stack.margin_left = stack.margin_right = stack.margin_top = SHADOW_SIZE;
            stack.add_named (loading, "loading");
            
            scrolled.add (stack);
            add (scrolled);
        }
        
        public void log_in (string username, string password) {
            clear_cache ();
            clear_login_view ();
            login_view = new LoginView (username, password);
            login_view.finished.connect (() => {
                clear_login_view ();
                app.auth_target_done (Fb.App.AuthTarget.WEBVIEW);
            });
            login_view.failed.connect (() => {
                clear_login_view ();
                app.auth_error ();
            });
            login_view.load_failed.connect (() => {
                clear_login_view ();
                app.network_error ();
            });
        }
        
        public void log_out () {
            clear_cache ();
            WebContext.get_default ().get_cookie_manager ().delete_all_cookies ();
        }
    }

}
