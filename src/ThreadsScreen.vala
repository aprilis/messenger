using Gtk;
using Gdk;
using Granite.Widgets;

namespace Ui {
    
    public class ThreadsScreen : Screen {
        
        public SearchEntry search_entry { get; private set; }

        public bool group_creator_active {
            get {
                return group_creator.active;
            }
        }

        private Toast toast;
        
        private ThreadsViewer threads_viewer;

        private GroupCreator group_creator;
        
        private InfoBar network_error_bar;
        
        public ThreadsScreen (Fb.App app) {
            title = app.user_name;
            name = "threads";
            
            app.notify["user-name"].connect ((s, p) => {
                title = app.user_name;
            });
                        
            threads_viewer = new ThreadsViewer ();
            group_creator = new GroupCreator ();
            if (app.data != null) {
                threads_viewer.set_data (app.data);
                group_creator.set_data (app.data);
            }
            threads_viewer.thread_selected.connect (app.start_conversation);
            group_creator.create_group.connect (app.create_group_thread);
            
            app.notify["data"].connect ((s, p) => {
                threads_viewer.clear ();
                group_creator.clear ();
                if (app.data != null) {
                    threads_viewer.set_data (app.data);   
                    group_creator.set_data (app.data);
                }
            });
            
            var scrolled = new ScrolledWindow(null, null);
            scrolled.hscrollbar_policy = PolicyType.NEVER;
            scrolled.vscrollbar_policy = PolicyType.AUTOMATIC;
            scrolled.add (threads_viewer.widget);
            
            search_entry = new SearchEntry ();
            search_entry.placeholder_text = _("Search for friends and groups...");
            search_entry.search_changed.connect (() => {
                threads_viewer.search_query = search_entry.text;
            });

            var search_bar = new Box (Orientation.HORIZONTAL, 5);
            search_bar.margin_start = search_bar.margin_end = 10;
            search_bar.margin_top = search_bar.margin_bottom = 5;
            search_bar.pack_start (search_entry);
            search_bar.pack_start (group_creator.widget, false, true);
            
            network_error_bar = Utils.create_infobar (_("No connection"), MessageType.ERROR, false);
            network_error_bar.add_button (_("Retry"), 1);
            network_error_bar.response.connect ((id) => { if (id == 1) app.reconnect (); });
           
            var box = new Box(Orientation.VERTICAL, 0);
            box.pack_start (network_error_bar, false);
            box.pack_start (search_bar, false, true);
            box.pack_start (scrolled, true, true);

            toast = new Toast ("toast");
            var overlay = new Overlay ();
            overlay.add_overlay (box);
            overlay.add_overlay (toast);

            widget = overlay;
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

        public void show_toast (string message) {
            toast.title = message;
            toast.send_notification ();
            toast.show ();
        }

        public void hide_toast () {
            toast.hide ();
        }
        
    }
    
}
