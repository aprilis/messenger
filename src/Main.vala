using GLib;
using Gtk;

public class Main : Granite.Application {

    public const string APP_ID = "com.github.aprilis.messenger.app";
    public const string APP_NAME = "messenger";
    
    private bool is_fake;
    
    private Main (bool fake) {
        Object (application_id: APP_ID,
                flags: ApplicationFlags.HANDLES_COMMAND_LINE);
        inactivity_timeout = 500;
        is_fake = fake;
        app_icon = "internet-chat";
        app_launcher = APP_ID + ".desktop";
        about_authors = { "Jarosław Kwiecień <kwiecienjaro@gmail.com>" };
        about_license_type = License.GPL_3_0;
        app_copyright = "2017";
        app_years = "2017";
        build_version = "0.2";
        //bug_url = "https://github.com/aprilis/messenger/issues";
        help_url = "https://github.com/aprilis/messenger/wiki";
        main_url = "https://github.com/aprilis/messenger";
        program_name = "Messenger";
        exec_name = APP_NAME;
        startup.connect (_startup);

        data_path = Environment.get_user_data_dir () + "/" + APP_NAME;
        cache_path = Environment.get_user_cache_dir () + "/" + APP_NAME;
        
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
        hold ();
        
        Plank.DBusClient.get_instance ();
        
        make_dir (data_path);
        make_dir (cache_path);

        var app = Fb.App.instance ();
        app.quit.connect (release);
        app.send_notification.connect ((id, not) => {
            var str = APP_ID;
            if (id != null) {
                str += "." + id;
            }
            send_notification (str, not);
        });
        app.withdraw_notification.connect ((id) => {
            var str = APP_ID;
            if (id != null) {
                str += "." + id;
            }
            withdraw_notification (str);
        });
        app.application = this;
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
        if (is_fake && id_open != 0) {
            hold ();
            var msg = new MessageDialog (null, DialogFlags.MODAL, MessageType.INFO, ButtonsType.OK,
                "Messenger is not running. To start the conversation, close this dialog and run the Messenger app first");
            msg.response.connect ((id) => { release (); });
            msg.show ();
        }
        return 0;
    }

    
    public static int main (string[] args) {
        bool fake = false;
        string[] fake_args = { "--open-chat", "--reload-chat", "--close-all-but-one", "--close-all" };
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
