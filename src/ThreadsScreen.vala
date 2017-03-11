using Gtk;
using Gdk;

namespace Ui {
    
    public class ThreadsScreen : Screen {
        
        public SearchEntry search_entry { get; private set; }
        
        private ThreadsViewer threads_viewer;
        
        private InfoBar network_error_bar;
        
        public ThreadsScreen (Fb.App app) {
            title = app.user_name;
            name = "threads";
            
            app.notify["user-name"].connect ((s, p) => {
                title = app.user_name;
            });
                        
            threads_viewer = new ThreadsViewer ();
            if (app.data != null) {
                threads_viewer.set_data (app.data);
            }
            threads_viewer.thread_selected.connect (app.start_conversation);
            
            app.notify["data"].connect ((s, p) => {
                threads_viewer.clear();
                if (app.data != null) {
                    threads_viewer.set_data (app.data);   
                }
            });
            
            var scrolled = new ScrolledWindow(null, null);
            scrolled.hscrollbar_policy = PolicyType.NEVER;
            scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
            scrolled.add (threads_viewer.widget);
            
            search_entry = new SearchEntry ();
            search_entry.placeholder_text = "Search for friends and groups...";
            search_entry.margin_left = search_entry.margin_right = 10;
            search_entry.margin_top = search_entry.margin_bottom = 5;
            search_entry.search_changed.connect (() => {
                threads_viewer.search_query = search_entry.text;
            });
            
            network_error_bar = Utils.create_infobar ("No connection", MessageType.ERROR, false);
            network_error_bar.add_button ("Retry", 1);
            network_error_bar.response.connect ((id) => { if (id == 1) app.reconnect_async.begin (); });
           
            var box = new Box(Orientation.VERTICAL, 0);
            box.pack_start (network_error_bar, false);
            box.pack_start (search_entry, false, true);
            box.pack_start (scrolled, true, true);
            widget = box;
        }
        
        public override void hide () {
            network_error_bar.visible = false;
        }
        
        public override void network_error () {
            network_error_bar.visible = true;
        }
        
        public override void network_ok () {
            network_error_bar.visible = false;
        }
        
        public override void auth_error () {
            change_screen ("password");
        }
        
    }
    
}
