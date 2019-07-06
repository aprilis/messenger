using GLib;
using Gtk;

private void signal_handler (int signum) {
    Posix.signal (signum, signal_handler);
    print ("Received signal %s\n", Posix.strsignal (signum));
    Fb.App.instance ().quit ();
}

public class Main : Gtk.Application {

    public const string APP_ID = "com.github.aprilis.messenger";
    public const string APP_NAME = "com.github.aprilis.messenger";
    public const string OPEN_CHAT_NAME = "com.github.aprilis.messenger-open-chat";
    public const string APP_LAUNCHER = APP_ID + ".desktop";
    public const string VERSION = "0.2.3";
    
    private bool is_fake;

    private LoginManager login;
    
    private Main (bool fake) {
        Object (application_id: APP_ID,
                flags: ApplicationFlags.HANDLES_COMMAND_LINE);
        Fb.App.application = this;
        
        inactivity_timeout = 500;
        is_fake = fake;
        startup.connect (_startup);

        data_path = Environment.get_user_data_dir () + "/" + APP_NAME;
        cache_path = Environment.get_user_cache_dir () + "/" + APP_NAME;

        Version.update_version (VERSION, data_path);
        
        var open_chat = new SimpleAction ("open-chat", VariantType.INT64);
        open_chat.activate.connect ((id) => {
            Fb.App.instance ().start_conversation (id.get_int64 ());
        });
        add_action (open_chat);
        var close_all = new SimpleAction ("close-all", null);
        close_all.activate.connect (() => {
            remove_heads ();
        });
        add_action (close_all);
        var close_all_but_one = new SimpleAction ("close-all-but-one", VariantType.INT64);
        close_all_but_one.activate.connect ((id) => {
            remove_heads (id.get_int64 ());
        });
        add_action (close_all_but_one);
    }

    private void remove_heads (int64 id = 0) {
        hold ();
        Fb.App.remove_heads (id);
        release ();
    }
    
    private void make_dir (string path) {
        var dir = File.new_for_path (path);
        if (!dir.query_exists ()) {
            try {
                dir.make_directory ();
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }
    }
    
    public static string data_path { get; private set; }
    public static string cache_path { get; private set; }
    
    public override void activate () {
        if (is_fake) {
            return;
        }
        hold ();
        Fb.App.instance ().show_window ();
        release ();
    }
    
    public void _startup () {
        if (is_fake) {
            return;
        }
        
        Notify.init (APP_NAME);
        make_dir (data_path);
        make_dir (cache_path);

        Fb.App.instance ();

        Posix.signal (Posix.Signal.TERM, signal_handler);

        login = get_login_manager ();
        login.prepare_for_shutdown.connect ((active) => {
            Fb.App.instance ().quit ();
        });
    }

    public override int command_line (ApplicationCommandLine command_line) {
        // keep the application running until we are done with this commandline
        hold ();
        int res = _command_line (command_line);
        release ();
        return res;
    }
    
    private int _command_line (ApplicationCommandLine command_line) {
        
        bool close_all = false, act = false;
        int64 id_open = 0, id_close = 0, id_reload = 0;
        var entries = new OptionEntry [5];
        entries[0] = { "activate", 'a', 0, OptionArg.NONE, out act, "Activates the main window", null };
        entries[1] = { "open-chat", 'o', 0, OptionArg.INT64, out id_open, "Opens chat with specified id", null };
        entries[2] = { "reload-chat", 'r', 0, OptionArg.INT64, out id_reload, "Reloads chat with specified id", null };
        entries[3] = { "close-all", 'c', 0, OptionArg.NONE, out close_all, "Removes all chat heads from dock", null };
        entries[4] = { "close-all-but-one", 'b', 0, OptionArg.INT64, out id_close,
             "Removes all chat heads from dock (except specified one)", null };
             
        var context = new OptionContext ("Options");
        context.add_main_entries (entries, null);
        context.set_help_enabled (true);
        context.add_group (Gtk.get_option_group (true));

        string[] args = command_line.get_arguments ();
        /*foreach (var arg in args) {
            print ("ARGS: %s\n", arg);
        }*/

        try {
            unowned string[] tmp = args;
            context.parse (ref tmp);
        } catch (Error e) {
            stdout.printf ("Error " + e.message + "\n");
            return 0;
        }
        
        if (!is_fake) {
            if (act) {
                activate ();
            }
            if (id_open != 0) {
                Fb.App.instance ().start_conversation (id_open);
            }
            if (id_reload != 0 && command_line.is_remote) {
                Fb.App.instance ().reload_conversation (id_reload);
            }
        }
        if (close_all) {
            remove_heads ();
        }
        if (id_close != 0) {
            remove_heads (id_close);
        }
        return 0;
    }

    
    public static int main (string[] args) {
        bool fake = false;
        string[] fake_args = { "--reload-chat", "--close-all-but-one", "--close-all" };
        foreach (var arg in args) {
            if (arg in fake_args) {
                fake = true;
            }
        }
		Main app = new Main (fake);
		int status = app.run (args);
		return status;
	}

}
