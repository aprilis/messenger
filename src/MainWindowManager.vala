using Gtk;
using Gdk;

namespace Ui {

    public class MainWindowManager {

        private const string STYLESHEET = """
            #threads *:selected {
                background: transparent;
            }
        """;

        private const int TRANSITION = 100;

        private Fb.App app;
          
        private Stack stack;
        
        private List<Screen> screens;

        private static int action_counter = 0;
        
        public Screen current { get; private set; default = null; }
    
        public HeaderBar header { get; private set; }
        
        public Welcome welcome { get; private set; }
        
        public SignIn sign_in { get; private set; }
        
        public SignUp sign_up { get; private set; }
        
        public ThreadsScreen threads { get; private set; }    
        
        public PasswordScreen password { get; private set; }

        public LoadingScreen loading { get; private set; }

        public ApplicationWindow window { get; private set; }

        public bool bubble { get; private set; }
        
        private bool detect_dark_theme () {
            var context = window.get_style_context ();
            var col_bg = context.get_background_color (Gtk.StateFlags.NORMAL), col_fg = context.get_color (Gtk.StateFlags.NORMAL);
            return col_bg.red + col_bg.green + col_bg.blue < col_fg.red + col_fg.green + col_fg.blue;
        }
        
        private void set_current_screen (Screen screen) {
            if (current != null) {
                var prev = current;
                Timeout.add (TRANSITION, () => {
                    prev.hide ();
                    return false;
                });
            }
            current = screen;
            if (current == null) {
                return;
            }
            current.show ();
            window.set_focus (null);
            header.title = current.title;
            stack.visible_child = screen.widget;
        }
        
        private void add_screen (Screen screen) {
            screens.append (screen);
            stack.add_named (screen.widget, screen.name);
            screen.notify ["title"].connect ((s, p) => {
                if (current != null) {
                    header.title = current.title;
                }
            });
            screen.change_screen.connect (set_screen);
        }

        private void update_settings (Settings settings) {
            if (bubble) {
                window.set_size_request (settings.window_bubble_width, settings.window_bubble_height);
            } else {
                window.set_default_size (settings.window_width, settings.window_height);
                
                if (!detect_dark_theme ()) {
                    var col = Gdk.RGBA ();   
                    if (col.parse(settings.title_bar_color)) {
                        Granite.Widgets.Utils.set_color_primary (window, col);
                    }   
                }
            }
        }
        
        public new void set_screen (string name) {
            print ("set screen %s\n", name);
            bool found = false;
            foreach (var s in screens) {
                if (s.name == name) {
                    set_current_screen (s);
                    found = true;
                    break;
                }
            }
            if (!found) {
                warning ("Unknown screen name: %s\n", name);
            }
        }

        public void append_menu_item (GLib.Menu menu, string label, Utils.Operation op) {
            menu.append (label, "win." + action_counter.to_string ());
            var action = new SimpleAction (action_counter.to_string (), null);
            action_counter++;
            action.activate.connect ((param) => { op (); });
            window.add_action (action);
        }

        public void show () {
            if (bubble) {
                var pop_over = (ApplicationPopOver) window;
                int tries = 10;
                Timeout.add (500, () => {
                    var client = Plank.DBusClient.get_instance ();
                    var uri = app.get_plank_launcher_uri ();
                    if (uri != null) {
                        Gtk.PositionType position_type;
                        int x, y;
                        var ok = client.get_hover_position (uri, out x, out y, out position_type);
                        if(ok) {
                            pop_over.set_position (x, y, position_type);
                            window.show_all ();
                            window.present ();
                        } 
                    } else {
                        return tries-- > 0;
                    }
                    
                    return false;
                });
            } else {
                window.show_all ();
                window.present ();
            }
        }
        
        public MainWindowManager (Fb.App _app) {
            app = _app;
            bubble = app.settings.main_window_bubble;
            
            window = bubble ? new ApplicationPopOver (Fb.App.application)
             : new Gtk.ApplicationWindow (Fb.App.application);

            var box = new Box (Orientation.VERTICAL, 0);
            window.add (box);

            header = new HeaderBar ();
            header.subtitle = _("Facebook Messenger");
            if (bubble) {
                header.margin = 5;
                box.pack_start (header, false, false, 0);
            } else {
                window.set_titlebar (header);
            }

            stack = new Stack ();
            stack.transition_type = StackTransitionType.SLIDE_LEFT_RIGHT;
            stack.transition_duration = TRANSITION;
            box.pack_start (stack, true, true, 0);
            
            welcome = new Welcome ();
            sign_in = new SignIn ();
            sign_in.log_in.connect (app.log_in);
            sign_up = new SignUp ();
            threads = new ThreadsScreen (app);
            password = new PasswordScreen ();
            password.done.connect ((pass) => app.log_in (null, pass));
            password.log_out.connect (() => app.log_out ());
            loading = new LoadingScreen (app);
            add_screen (welcome);
            add_screen (sign_in);
            add_screen (sign_up);
            add_screen (password);
            add_screen (loading);
            add_screen (threads);
            
            window.focus_in_event.connect ((event) => {
                 window.set_focus (null);
                 return false;
            });
            window.show.connect ((event) => {
                set_current_screen (current);
            });
            window.key_press_event.connect ((event) => {
                if (current == threads && !threads.group_creator_active) {
                    if (event.keyval == Key.Escape) {
                        threads.search_entry.text = "";
                        window.set_focus (null);
                    } else if (!threads.search_entry.has_focus) {
                        window.set_focus (threads.search_entry);
                    }
                }
                return false;
            });

            window.delete_event.connect (() => {
                if (app.data == null && !bubble) {
                    app.quit ();
                    return true;
                } else {
                    return window.hide_on_delete ();
                }
            });
            
            update_settings (app.settings);
            app.settings.changed.connect(() => {
                update_settings (app.settings);
            });
            
            window.size_allocate.connect ((alloc) => {
                if (bubble) {
                    return;
                }
                int width, height;
                window.get_size (out width, out height);
                if (app.settings.window_width != width) {
                    app.settings.window_width = width;
                }
                if (app.settings.window_height != height) {
                    app.settings.window_height = height;
                }
            });
            Granite.Widgets.Utils.set_theming_for_screen (window.get_screen (), STYLESHEET,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }

}
