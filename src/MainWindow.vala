using Gtk;
using Gdk;

namespace Ui {

    public class MainWindow : Gtk.ApplicationWindow {

        private const string STYLESHEET = """
            GtkTreeView#threads row:selected {
                background: white;
            }
        """;

        private const int TRANSITION = 100;
          
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
            set_focus (null);
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

        private void update_title_bar_color (Settings settings) {
            var col = new Gdk.RGBA ();
            if (col.parse(settings.title_bar_color)) {
                Granite.Widgets.Utils.set_color_primary (this, col);
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
            add_action (action);
        }
        
        public MainWindow (Fb.App app) {                    
            header = new HeaderBar ();
            header.subtitle = "Facebook Messenger";
            set_titlebar (header);

            stack = new Stack ();
            stack.transition_type = StackTransitionType.SLIDE_LEFT_RIGHT;
            stack.transition_duration = TRANSITION;
            add (stack);
            
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
            
            focus_in_event.connect ((event) => {
                 set_focus (null);
                 return false;
            });
            show.connect ((event) => {
                set_current_screen (current);
            });
            key_press_event.connect ((event) => {
                if (current == threads && !threads.group_creator_active) {
                    if (event.keyval == Key.Escape) {
                        threads.search_entry.text = "";
                        set_focus (null);
                    } else if (!threads.search_entry.has_focus) {
                        set_focus (threads.search_entry);
                    }
                }
                return false;
            });
            
            update_title_bar_color (app.settings);
            app.settings.changed.connect(() => {
                update_title_bar_color (app.settings);
            });
            size_allocate.connect ((alloc) => {
                int width, height;
                get_size (out width, out height);
                app.settings.window_width = width;
                app.settings.window_height = height;
            });
            Granite.Widgets.Utils.set_theming_for_screen (get_screen (), STYLESHEET,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
        }
    }

}
