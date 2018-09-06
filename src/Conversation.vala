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
                    max-width: 1px;
                    min-width: 1px;
                }
                div._1q5- {
                    border-left: none;
                }
                a._30yy._2oc8 {
                    display: none;
                }
                span._3oh-._58nk {
                    /*white-space: pre;*/
                }
                div._1p1v {
                    white-space: pre;
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
                    document.title = '__success__';
                } catch(err) {
                    document.title = '__fail__';
                }
            """;

            private int64 last_id;
            private bool user_changed = false;
            private bool loading_finished = true;
            private bool failed = false;
            private bool script_running = false;

            public WebView webview { get; private set; }
            
            public signal void ready ();
            public signal void auth_failed ();
            public signal void load_failed ();

            private void load_conversation (Fb.Id id) {
                script_running = false;
                last_id = id;
                var uri = MESSENGER_URL + "/t/" + id.to_string ();
                loading_finished = false;
                failed = false;
                print ("loading uri: %s\n", uri);
                webview.load_uri (uri);
                user_changed = true;
            }

            private void run_script () {
                user_changed = true;
                script_running = true;
                print ("running script\n");
                webview.run_javascript (CHANGE_USER_SCRIPT.printf (last_id), null);
                Timeout.add (1000, () => {
                    if (script_running) {
                        load_conversation (last_id);
                    }
                    return false;
                });
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

            private bool handle_loading_finished () {
                print ("handle_loading_finished - loading_finished = %s\n", loading_finished.to_string ());
                print ("uri: %s\n", webview.get_uri ());
                if (loading_finished) {
                    return false;
                }
                loading_finished = true;
                if (webview.get_uri ().has_prefix (LOGIN_URL)) {
                    last_id = 0;
                    auth_failed ();
                    return false;
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
                return false;
            }

            public View (string cookie_path) {       
                var context = new WebContext ();
                var manager = context.get_cookie_manager ();
                manager.set_persistent_storage (cookie_path, CookiePersistentStorage.TEXT);
                webview = new WebView.with_context (context);

                manager.get_cookies.begin("https://www.messenger.com", null, (obj, res) => {
                    var cookies = manager.get_cookies.end (res);
                    foreach(var cookie in cookies) {
                        print ("%s\n", cookie.to_cookie_header ());
                    }
                });
                
                var style_sheet = new UserStyleSheet (STYLE_SHEET, UserContentInjectedFrames.TOP_FRAME,
                                                         UserStyleLevel.AUTHOR, null, null);
                webview.user_content_manager.add_style_sheet (style_sheet);

                webview.load_changed.connect ((load_event) => {
                    print ("load changed: %s\n", load_event.to_string ());
                    print ("load progress: %lf, is-loading: %s\n", webview.estimated_load_progress,
                        webview.is_loading.to_string ());
                    if (load_event == LoadEvent.FINISHED) {
                        //handle_loading_finished ();
                    }
                });
                webview.notify ["title"].connect ((s, p) => {
                    if ("__success__" in webview.title) {
                        script_running = false;
                        ready ();
                        webview.run_javascript ("document.title = 'Messenger';", null);
                    } else if ("__fail__" in webview.title && last_id != 0) {
                        load_conversation (last_id);
                    }
                });
                webview.notify ["is-loading"].connect ((s, p) => {
                    print ("load progress: %lf, is-loading: %s\n", webview.estimated_load_progress,
                        webview.is_loading.to_string ());
                    if (!webview.is_loading) {
                        handle_loading_finished ();
                    }
                });
                webview.notify ["estimated-load-progress"].connect ((s, p) => {
                    print ("load progress: %lf, is-loading: %s\n", webview.estimated_load_progress,
                        webview.is_loading.to_string ());
                });
                webview.context_menu.connect (() => { return true; });
                webview.show_notification.connect (() => { return true; });
                webview.decide_policy.connect (decide_policy);
                
                webview.load_failed.connect ((event, uri, error) => {
                    print ("network error: %s %d\n", error.message, error.code);
                    failed = true;
                    if (error.code != 302) {
                        load_failed ();
                    }
                    return false;
                });
                load_home_page ();
            }
            
            public bool load (Fb.Id id) {
                if (last_id == id && user_changed) {
                    return false;
                }
                print ("load progress: %lf, is-loading: %s\n", webview.estimated_load_progress,
                    webview.is_loading.to_string ());
                last_id = id;
                if (!webview.is_loading) {
                    run_script ();
                } else {
                    user_changed = false;
                    //Timeout.add (6000, handle_loading_finished);
                }
                return true;
            }

            public void load_home_page () {
                if (!webview.is_loading || failed) {
                    failed = false;
                    loading_finished = false;
                    script_running = false;
                    print ("loading uri: %s\n", MESSENGER_URL);
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
                var interval = setInterval(function () {
                    if (document.readyState == 'complete') {
                        document.getElementById('email').value = '%s';
                        document.getElementById('pass').value = '%s';
                        elements = document.getElementsByTagName('input');
                        for(i = 0; i < elements.length; i++) {
                            if(elements[i].type == 'checkbox') {
                                elements[i].checked = true;
                            }
                        }
                        document.getElementById('login_form').submit();
                        clearInterval(interval);
                    }
                }, 100)​;
                """;
                
            private WebView webview;
            private string username;
            private string password;
                
            public signal void finished (LoginView view);
            
            public signal void failed (LoginView view);
            
            public signal void load_failed (LoginView view);
                
            public LoginView (string user, string pass, string cookie_path) {                
                username = user;
                password = pass;
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

        public signal void close_bubble (Fb.Id id);

        private int width = 690;
        private int height = 500;

        private Loading loading;
        private Stack stack;
        
        private View view;
        private LoginView login_view;
        private ScrolledWindow view_window;

        private PositionType position_type;

        private Shortcut close_bubble_shortcut;
        
        private Fb.App app;

        private string cookie_path;

        private void clear_login_view () {
            if (login_view != null) {
                login_view.destroy ();
            }
            login_view = null;
        }

        private void create_view () {
            if (view_window.get_child () != null) {
                view_window.remove (view_window.get_child ());
            }
            view = new View (cookie_path);
            view.ready.connect (() => {
                print ("ready\n");
                stack.visible_child = view_window;
            });
            view.load_failed.connect (() => { app.network_error (); });
            view.auth_failed.connect (() => { clear_cookies (); app.show_login_dialog (false); });
            view.webview.show_now ();
            view_window.child = view.webview;
        }
        
        public int64 current_id { get; private set; default = 0;}
        
        public void load_conversation (Fb.Id id) {
            current_id = id;
            if (view.load (id)) {
                stack.visible_child = loading;
            } else {
                stack.visible_child = view_window;
            }
            if (is_active) {
                close (true);
            }
        }
        
        public void reload (bool hard = false) {
            if (hard) {
                create_view ();
            }
            view.load_home_page ();
        }
        
        public new void show (int x, int y, Gtk.PositionType dock_position) {
            update_position_type (dock_position);
            set_position (x, y, dock_position);
            set_size_request (width, height);
            show_all ();
            activate ();
            present ();
        }

        private void update_position_type (PositionType type) {
            position_type = type;
            stack.margin_left = stack.margin_right = stack.margin_top = stack.margin_bottom = SHADOW_SIZE;
            switch (type) {
            case PositionType.LEFT:
                stack.margin_left = ARROW_HEIGHT;
                break;
            case PositionType.RIGHT:
                stack.margin_right = ARROW_HEIGHT;
                break;
            case PositionType.TOP:
                stack.margin_top = ARROW_HEIGHT;
                break;
            case PositionType.BOTTOM:
                stack.margin_bottom = ARROW_HEIGHT;
                break;
            }
        }

        private bool key_release (Gdk.EventKey event) {
            if (close_bubble_shortcut.activated (event)) {
                close ();
                close_bubble (current_id);
            }
            return false;
        }

        private void update_settings () {
            close_bubble_shortcut = new Shortcut.parse (app.settings.close_and_remove_shortcut);
            width = app.settings.chat_width;
            height = app.settings.chat_height;
            set_size_request (width, height);
        }
        
        public Conversation (Fb.App _app) {
            cookie_path = Main.cache_path + "/cookies";
            
            var context = WebContext.get_default ();
            var manager = context.get_cookie_manager ();
            manager.set_persistent_storage (cookie_path, CookiePersistentStorage.TEXT);

            app = _app;
            
            view_window = new ScrolledWindow (null, null);
            view_window.show_now ();
            create_view ();

            loading = new Loading (40);
            loading.show_now ();

            key_release_event.connect(key_release);
            
            stack = new Stack ();
            update_position_type (PositionType.BOTTOM);
            stack.add_named (loading, "loading");
            stack.add_named (view_window, "conversation");
            stack.show_now ();
            add (stack);

            update_settings ();
            app.settings.changed.connect (update_settings);
        }
        
        public void log_in (string username, string password) {
            clear_login_view ();
            clear_cookies ();
            login_view = new LoginView (username, password, cookie_path);
            login_view.finished.connect ((lv) => {
                if (login_view != lv) {
                    return;
                }
                clear_login_view ();
                reload (true);
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
            WebContext.get_default ().get_cookie_manager ().delete_cookies_for_domain ("https://www.messenger.com");
        }
        
        public void log_out () {
            clear_cookies ();
            view.load_home_page ();
        }
    }

}
