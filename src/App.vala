using GLib;
using Gdk;
using Gtk;
using Gee;
using Unity;
using Utils;

namespace Fb {

    public class App : Object {
    
        [Flags]
        public enum AuthTarget {
            API,
            WEBVIEW
        }

        private delegate void PlankOperation (Plank.DBusClient client);
        
        private const string SESSION_FILE = "session";
        private const string CONFIRMED_FILE = "confirmed_users";
        private const int RECONNECT_INTERVAL = 10*1000;
        private const int CHECK_AWAKE_INTERVAL = 4*1000;
        private const int64 QUERY_CONTACTS_INTERVAL = 20LL*60*1000000;
        private const int CONVERSATION_START_INTERVAL = 1000000 / 2;
        public const int THREADS_COUNT = 400;
        public const int SMALL_THREADS_COUNT = 30;
        
        private string get_session_path () {
            return Main.cache_path + "/" + SESSION_FILE;
        }
        
        private string get_confirmed_path () {
            return Main.cache_path + "/" + CONFIRMED_FILE;
        }
        
        private Soup.Session session;
        
        private SocketClient socket_client;
        
        private Ui.MainWindowManager window_manager;
        
        private Api api;
        
        private Ui.Conversation conversation;
        
        private string user_login = null;
        
        private AuthTarget auth_target = 0;
        
        public Plank.DockPreferences dock_preferences { get; private set; }
        private Plank.HideType plank_hide_type;
        private bool plank_settings_changed = false;
        
        private static Once<App> _instance;
        
        private bool _network_problem;
        
        private HashSet<string> confirmed_users = null;

        private int64 last_awake_check = 0;
        private int64 last_query_contacts = 0;
        private int64 last_conversation_time = 0;

        private bool webview_auth_fail = false;
        private bool show_login_dialog_infobar = false;

        private Ui.LoginDialog login_dialog = null;

        private HashMap<Id?, Notify.Notification> notifications;

        private HashMap<Id?, int> hidden_unread_count;
        private int hidden_unread_sum = 0;

        private string plank_launcher_uri = null;
        
        public bool network_problem {
            get { return _network_problem; }
            private set {
                if (value) {
                    window_manager.current.network_error ();
                }
                if (_network_problem != value) {
                    _network_problem = value;
                    if (value) {
                        reconnect ();
                        Timeout.add (RECONNECT_INTERVAL, reconnect);
                    } else {
                        window_manager.current.network_ok ();
                        query_threads (SMALL_THREADS_COUNT);
                        conversation.reload (true);
                    }
                }
            }
        }
        
        public Data data { get; private set; }
        
        public string user_name { get; private set; }

        public static Granite.Application application { get; set; }

        public Ui.Settings settings { get; private set; }
                
        public static unowned App instance () {
            return _instance.once(() => { return new App (); });
        }
        
        private int load_session () {
            try {
                var parser = new Json.Parser ();
                if (!parser.load_from_file (get_session_path ())) {
                    return -1;
                }
                
                var obj = parser.get_root ().get_object ();
                
                string[] required = { "cid", "did", "mid" };
                foreach (var member in required) {
                    if (!obj.has_member (member) || obj.get_null_member (member)) {
                        return -1;
                    }
                }
                api.cid = obj.get_string_member ("cid");
                api.did = obj.get_string_member ("did");
                api.mid = uint64.parse(obj.get_string_member ("mid"));
                
                required = { "stoken", "token", "uid", "login" };
                foreach (var member in required) {
                    if (!obj.has_member (member) || obj.get_null_member (member)) {
                        api.stoken = null;
                        api.token = null;
                        api.uid = 0;
                        user_login = null;
                        return 0;
                    }
                }
                api.stoken = obj.get_string_member ("stoken");
                api.token = obj.get_string_member ("token");
                api.uid = int64.parse (obj.get_string_member ("uid"));
                user_login = obj.get_string_member ("login");
            } catch (Error e) {
                warning ("Load session error %d: %s\n", e.code, e.message);
                return -1;
            }
            return 1;
        }
        
        private void load_confirmed_users () {
            try {
                confirmed_users.clear ();
                var file = File.new_for_path (get_confirmed_path ());
                var stream = new DataInputStream (file.read ());
                string line;
                while ((line = stream.read_line_utf8 (null, null)) != null) {
                    confirmed_users.add (line);
                }
            } catch (Error e) {
                warning ("Load confirmed users error %d: %s\n", e.code, e.message);
            }
        }
        
        private void save_confirmed_user (string user) {
            try {
                var file = File.new_for_path (get_confirmed_path ());
                var stream = new DataOutputStream (file.append_to (FileCreateFlags.PRIVATE));
                stream.put_string (user + "\n");
            } catch (Error e) {
                warning ("Save confirmed users error %d: %s\n", e.code, e.message);
            }
        }

        public void query_threads (int count = THREADS_COUNT) {
            api.threads_func (count);
        }

        public void query_thread (Fb.Id id) {
            api.thread_func (id);
        }

        public void query_contacts () {
            api.contacts_func ();
            last_query_contacts = get_real_time ();
        }

        public void query_contact (Fb.Id id) {
            api.contact_func (id);
        }

        public void connect_api () {
            api.connect_func (false);
        }

        public void disconnect_api () {
            api.disconnect_func ();
        }
        
        public void authenticate (string username, string password) {
            api.auth_func (username, password);
        }

        public void create_group_thread (GLib.SList<Id?> ids, string name) {
            api.thread_create_func (ids, name);
            window_manager.threads.show_toast ("Group thread is being created");
        }

        public void thread_created (int64 id) {
            query_thread (id);
            Timeout.add (1000, () => {
                window_manager.threads.hide_toast ();
                return false;
            });
        }

        public bool check_awake () {
            var time = get_real_time ();
            if (last_awake_check != 0 && time - last_awake_check > 2 * 1000 * CHECK_AWAKE_INTERVAL) {
                connect_api ();
                query_threads (SMALL_THREADS_COUNT);
                //conversation.reload (true);
            }
            last_awake_check = time;
            if (data != null && last_query_contacts != 0 &&
                 time - last_query_contacts > QUERY_CONTACTS_INTERVAL) {
                print ("query contacts\n");
                query_contacts ();
                last_query_contacts = time;
            }
            return true;
        }
        
        public bool reconnect () {
            if (data == null || !network_problem) { 
                return false;
            }
            connect_api ();
            return true;
        }
        
        public void auth_error () {
            window_manager.current.auth_error ();
        }
        
        public void network_error () {
            network_problem = true;
        }
        
        public void auth_needed () {
            if (window_manager.current == window_manager.threads || window_manager.current == window_manager.password) {
                window_manager.set_screen ("password");
                conversation.close (true);
                window_manager.show ();
            }
        }
        
        private void save_session () {
            try {
                var builder = new Json.Builder ();
                builder.begin_object ();
                
                builder.set_member_name ("cid");
                builder.add_string_value (api.cid);
                
                builder.set_member_name ("did");
                builder.add_string_value (api.did);
                
                builder.set_member_name ("mid");
                builder.add_string_value (api.mid.to_string ());
                
                if (api.stoken != null) {
                    builder.set_member_name ("stoken");
                    builder.add_string_value (api.stoken);
                }
                
                builder.set_member_name ("token");
                builder.add_string_value (api.token);
                
                builder.set_member_name ("uid");
                builder.add_string_value (api.uid.to_string ());
                
                builder.set_member_name ("login");
                builder.add_string_value (user_login);
                
                builder.end_object ();
                var gen = new Json.Generator ();
                gen.root = builder.get_root ();
                gen.pretty = true;
                
                gen.to_file (get_session_path ());
                
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }
        
        public void auth_target_done (AuthTarget target) {
            if ((target & AuthTarget.WEBVIEW) != 0) {
                webview_auth_fail = false;
            } 
            auth_target &= ~target;
            if ((auth_target & AuthTarget.API) == 0 && webview_auth_fail && login_dialog == null) {
                login_dialog = new Ui.LoginDialog (show_login_dialog_infobar);
                login_dialog.finished.connect (() => {
                    auth_target_done (AuthTarget.WEBVIEW);
                    login_dialog.destroy ();
                    login_dialog = null;
                    conversation.reload (true);
                });
                login_dialog.canceled.connect (() => { auth_error (); login_dialog = null; });
                login_dialog.show_all ();
                login_dialog.present ();
            }
            if (auth_target == 0) {
                auth_done ();
            }
        }
        
        private void auth_done () {
            data = new Data (session, socket_client, this, api);
            window_manager.set_screen ("loading");
            data.new_message.connect (message_notification);
            data.unread_count.connect (update_unread_count);
            data.new_thread.connect ((thread) => {
                if (thread.id == api.uid) {
                    print ("found me!\n");
                    user_name = thread.name == null ? "" : thread.name;
                    thread.name_updated.connect (() => {
                        user_name = thread.name;
                    });
                    window_manager.header.set_photo (thread.get_icon (window_manager.header.PHOTO_SIZE, true));
                    thread.photo_updated.connect (() => {
                        window_manager.header.set_photo (thread.get_icon (window_manager.header.PHOTO_SIZE, true));
                    });
                }
                thread.notify ["is-present"].connect ((s, p) => {
                    var t = (Thread) s;
                    update_presence (t.id, t.is_present);
                });
                update_presence (thread.id, thread.is_present);
            });
            
            query_contacts ();
            connect_api ();
        }
        
        private void connect_done () {
            print ("connected!\n");
            network_problem = false;
            save_session ();
        }

        private void api_error (void *ptr) {
            unowned Error e = (Error)ptr;
            Quark[] network_quarks = { Fb.Mqtt.error_quark (),
                                     ResolverError.quark (), Fb.http_error_quark () };
            warning ("Api error: %s %d %s\n", e.domain.to_string (), e.code, e.message);
            if (e.matches (Fb.Api.error_quark (), ApiError.AUTH) ||
                e.matches (Fb.Mqtt.error_quark (), MqttError.USERPASS)) {
                
                auth_error ();
            } else if (e.matches (Fb.Mqtt.error_quark (), MqttError.UNAUTHORIZED)) {
                auth_needed ();
            } else if (e.domain in network_quarks) {
                network_error ();
            } else {
                var regex = new Regex ("\\((\\d+)\\)");
                MatchInfo info;
                var match = regex.match (e.message, 0, out info);
                int error_code = -1;
                if (match) {
                    error_code = int.parse (info.fetch (1));
                }
                if (error_code == 406) {
                    window_manager.current.twostep_verification ();
                } else {
                    warning ("Unexpected api error: %s %d %s\n", e.domain.to_string (), e.code, e.message);
                    window_manager.current.other_error ();
                }
            }
        }

        private void update_presence (Fb.Id id, bool present) {
            if (!settings.show_available_users) {
                return;
            }
            if (id == 0) {
                var client = Plank.DBusClient.get_instance ();
                
                int tries = 10;
                Timeout.add (50, () => {
                    if (!client.is_connected) {
                        return tries-- > 0;
                    }
                    var apps = client.get_persistent_applications ();
                    foreach (var app in apps) {
                        var f = File.new_for_uri (app);
                        var name = f.get_basename ().split (".")[0];
                        int64 tid;
                        if (int64.try_parse (name, out tid) && f.get_path ().has_prefix (Main.data_path)) {
                            var entry = LauncherEntry.get_for_desktop_file (data.desktop_file_uri (tid));
                            if (!settings.show_available_users) {
                                entry.progress_visible = false;
                            }
                            else {
                                var thread = data.try_get_thread (tid);
                                if (thread != null) {
                                    entry.progress_visible = thread.is_present;
                                }
                            }
                        }
                    }
                    return false;
                });
            } else if (settings.show_available_users) {
                var client = Plank.DBusClient.get_instance ();
                var uri = data.desktop_file_uri (id);
                if (uri in client.get_persistent_applications ()) {
                    var entry = LauncherEntry.get_for_desktop_file (data.desktop_file_uri (id));
                    entry.progress = 1;
                    entry.progress_visible = present;
                }
            }
        }

        private void update_hidden_unread (Fb.Id id, int count) {
            int diff = 0;
            if (hidden_unread_count [id] == 0 && count > 0) diff = 1;
            else if (hidden_unread_count [id] > 0 && count == 0) diff = -1;
            hidden_unread_count [id] = count;
            hidden_unread_sum += diff;

            if (diff != 0) {
                bool on_plank = false;
                var client = Plank.DBusClient.get_instance ();
                foreach (var app in client.get_transient_applications ()) {
                    if (app.has_suffix(Main.APP_LAUNCHER)) {
                        on_plank = true;
                        break;
                    }
                }
                foreach (var app in client.get_persistent_applications ()) {
                    if (app.has_suffix(Main.APP_LAUNCHER)) {
                        on_plank = true;
                        break;
                    }
                }
                if (on_plank) {
                    var entry = LauncherEntry.get_for_desktop_id (Main.APP_LAUNCHER);
                    if (entry != null) {
                        entry.count = hidden_unread_sum;
                        entry.count_visible = hidden_unread_sum > 0;
                    }
                }
            }
        }
        
        private void add_to_plank (Fb.Id id) {
            var client = Plank.DBusClient.get_instance ();
            var uri = data.desktop_file_uri (id);
            client.add_item (uri);
            Timeout.add (1000, () => {
                var thread = data.try_get_thread (id);
                if(thread != null) {
                    update_presence (id, thread.is_present);
                    update_unread_count(id, thread.unread);
                }
                return false;
            });
        }
        
        private void message_notification (Thread thread, string message) {
            if (conversation.is_active && conversation.current_id == thread.id) {
                return;
            }
            if (settings.create_new_bubbles) {
                add_to_plank (thread.id);
            }
            Notify.Notification not;
            if (thread.id in notifications) {
                not = notifications [thread.id];
                not.update (thread.notification_text, message, null);
            } else {
                not = new Notify.Notification (thread.notification_text, message, null);
                not.add_action ("default", "View", (n, a) => {
                    print ("starting conversaion: %lld\n", thread.id);
                    start_conversation (thread.id);
                });
                notifications.set (thread.id, not);
            }
            not.set_image_from_pixbuf (thread.photo);
            try {
                not.show ();
            } catch (Error e) {
                warning ("Notification error: %d %s\n", e.code, e.message);
            }
        }
        
        private void update_unread_count (Id id, int count) {
            if (count != 0 && conversation.is_active && conversation.current_id == id) {
                data.read_all (id);
                return;
            }
            var client = Plank.DBusClient.get_instance ();
            var uri = data.desktop_file_uri (id);
            if (uri in client.get_persistent_applications ()) {
                var entry = LauncherEntry.get_for_desktop_file (data.desktop_file_uri (id));
                entry.count = count;
                entry.count_visible = count > 0;
                update_hidden_unread (id, 0);
            } else if (!settings.create_new_bubbles) {
                update_hidden_unread (id, count);
            }
        }

        public string get_plank_launcher_uri () {
            if (plank_launcher_uri != null) {
                return plank_launcher_uri;
            }
            var client = Plank.DBusClient.get_instance ();
            foreach (var app in client.get_transient_applications ()) {
                if (app.has_suffix(Main.APP_LAUNCHER)) {
                    plank_launcher_uri = app;
                    break;
                }
            }
            foreach (var app in client.get_persistent_applications ()) {
                if (app.has_suffix(Main.APP_LAUNCHER)) {
                    plank_launcher_uri = app;
                    break;
                }
            }
            return plank_launcher_uri;
        }
        
        public void show_login_dialog (bool show_infobar) {
            show_login_dialog_infobar = show_infobar;
            webview_auth_fail = true;
            auth_target_done (0);
        }

        public void log_out () {
            if (data == null) {
                return;
            }
            try {
                //window_manager.set_screen ("welcome");
                remove_heads ();
                conversation.log_out ();
                Fb.Data.delete_files ();
                data.close ();
                user_name = null;
                data = null;
                notifications.clear ();
                disconnect_api ();
                api.stoken = null;
                api.token = null;
                api.uid = 0;
                save_session ();
                window_manager.header.clear_photo ();
                hidden_unread_sum = 0;
                hidden_unread_count.clear ();
                update_hidden_unread (0, 0);
                print ("logged out\n");
                quit ();

            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }
        
        public void log_in (string? username, string password) {
            if (username != null && !(username in confirmed_users)) {
                var dialog = new MessageDialog (window_manager.window, DialogFlags.MODAL, MessageType.WARNING, ButtonsType.YES_NO,
                    _("Please note that this is NOT an official Facebook Messenger app. Use it at your own risk. Do you still want to continue?"));
                dialog.response.connect ((response_id) => {
                    if (response_id == ResponseType.YES) {
                        confirmed_users.add (username);
                        save_confirmed_user (username);
                        log_in (username, password);
                    } else {
                        window_manager.current.cowardly_user ();
                    }
                    dialog.destroy ();
                });
                dialog.show ();
                return;
            }
        
            if (username == null) {
                username = user_login;
            } else {
                user_login = username;
            }
            Data.delete_files ();
            auth_target = AuthTarget.API | AuthTarget.WEBVIEW;
            webview_auth_fail = false;
            show_login_dialog_infobar = false;
            conversation.log_in (username, password);
            authenticate (username, password);
        }
        
        public App () {
            Data.init_paths ();
            settings = new Ui.Settings (); 

            session = new Soup.Session ();
            session.use_thread_context = true;
            session.timeout = 10;
            socket_client = new SocketClient ();
            socket_client.timeout = 10;

            api = new Api (socket_client, session);
            
            api.auth.connect (() => { auth_target_done (AuthTarget.API); });
            api.connect.connect (connect_done);
            api.error.connect (api_error);
            api.thread_create.connect (thread_created);
            
            window_manager = new Ui.MainWindowManager (this);
            window_manager.window.show.connect (() => { if (network_problem) network_error (); });
            
            var menu = new GLib.Menu ();
            var account_section = new GLib.Menu ();
            menu.append_section (_("Your account"), account_section);
            window_manager.append_menu_item (account_section, _("Reconnect"), () => {
                data.close ();
                data = null;
                auth_done ();
            });
            window_manager.append_menu_item (account_section, _("Close all conversations"), () => {
                remove_heads (); 
            });
            window_manager.append_menu_item (account_section, _("Log Out & Quit"), log_out);
            var app_section = new GLib.Menu ();
            menu.append_section (_("App"), app_section);
            window_manager.append_menu_item (app_section, _("Preferences"), () => {
                var settings_window = new Ui.SettingsWindow (window_manager.window, settings);
                settings_window.show_all ();
            });
            window_manager.append_menu_item (app_section, _("About"), () => {
                application.show_about (window_manager.window);
            });
            window_manager.append_menu_item (app_section, _("Quit"), () => {
                quit ();
            });
            
            window_manager.header.set_menu (menu);
            
            conversation = new Ui.Conversation (this);
            conversation.hide.connect (() => {
                if (plank_settings_changed) {
                    dock_preferences.HideMode = plank_hide_type;
                    plank_settings_changed = false;
                }
            });
            conversation.close_bubble.connect (remove_head);
            
            notifications = new HashMap<Id?, Notify.Notification> (my_id_hash, my_id_equal);

            hidden_unread_count = new HashMap<Id?, int> (my_id_hash, my_id_equal);

            confirmed_users = new HashSet<string> ();
            load_confirmed_users ();
            
            int loaded = load_session ();
            if (loaded == 1) {
                auth_done ();
            } else {
                window_manager.set_screen ("welcome");
                if (loaded == -1) {
                    api.rehash();
                }
            }

            dock_preferences = new Plank.DockPreferences ("dock1");

            Timeout.add (CHECK_AWAKE_INTERVAL, check_awake);

            update_presence (0, false);
            settings.notify ["show-available-users"].connect ((s, p) => {
                update_presence (0, false);
            });
        }
        
        public void start_conversation (Fb.Id id) {
            if (data == null) {
                return;
            }
            var time = get_monotonic_time ();
            if (time - last_conversation_time < CONVERSATION_START_INTERVAL) {
                return;
            }
            last_conversation_time = time;
            conversation.load_conversation (id);
            add_to_plank (id);
            data.check_unread_count (id);
            if (!plank_settings_changed && dock_preferences.HideMode != Plank.HideType.NONE) {
                plank_settings_changed = true;
                plank_hide_type = dock_preferences.HideMode;
                dock_preferences.HideMode = window_manager.window.is_maximized ?
                     Plank.HideType.NONE : Plank.HideType.INTELLIGENT;
            }
            Timeout.add (500, () => {
                var client = Plank.DBusClient.get_instance ();
                var uri = data.desktop_file_uri (id);
                try {
                    int x, y;
                    Gtk.PositionType position_type;
                    var ok = client.get_hover_position (uri, out x, out y, out position_type);
                    if (conversation.current_id == id && ok) {
                        print ("plank position: %s\n", position_type.to_string ());
                        conversation.show(x, y, position_type);
                        data.read_all (id);
                        if (notifications.has_key (id)) {
                            notifications [id].close ();
                        }
                    }
                } catch (Error e) {
                    warning ("Plank DBus error %d: %s\n", e.code, e.message);
                }
                return false;
            });
        }

        private static void plank_operation (PlankOperation op) {
            try {
                var client = Plank.DBusClient.get_instance ();

                if (client.is_connected) {
                    op (client);
                } else {
                    int tries = 10;
                    Timeout.add (50, () => {
                        if (!client.is_connected) {
                            return tries-- > 0;
                        }
                        op (client);
                        return false;
                    });
                }
            } catch (Error e) {
                warning ("Plank operation error %s\n", e.message);
            }
        }
        
        public static void remove_head (Fb.Id removed_id) {
            plank_operation ((client) => {
                var apps = client.get_persistent_applications ();
                foreach (var app in apps) {
                    var f = File.new_for_uri (app);
                    var name = f.get_basename ().split (".")[0];
                    int64 id;
                    if (int64.try_parse (name, out id) && id == removed_id && f.get_path ().has_prefix (Main.data_path)) {
                        client.remove_item (app);
                    }
                }
            });
        }
        
        public static void remove_heads (Fb.Id except = 0) {
            plank_operation ((client) => {
                var apps = client.get_persistent_applications ();
                foreach (var app in apps) {
                    var f = File.new_for_uri (app);
                    var name = f.get_basename ().split (".")[0];
                    int64 id;
                    if (int64.try_parse (name, out id) && id != except && f.get_path ().has_prefix (Main.data_path)) {
                        client.remove_item (app);
                    }
                }
            });
        }
        
        public void reload_conversation (Fb.Id id) {
            conversation.reload (true);
        }
        
        public void show_window () {
            window_manager.show ();
        }
        
        public void run () {
            Gtk.main ();
        }

        public void quit () {
            if (settings.close_bubbles_on_quit) {
                remove_heads ();
            }
            window_manager.window.destroy ();
        }
    
    }

}
