using Gtk;
using Gdk;
using GLib;

namespace Ui {
    
    public class ThreadsViewer : Object {
    
        public signal void thread_selected (Fb.Id id);
    
        private enum Index {
            ID,
            PHOTO,
            NAME,
            MESSAGE,
            PARTICIPANTS,
            TEXT,
            UNREAD,
            UPDATE_TIME,
            COUNT
        }
        
        const int ICON_SIZE = 60;
        const int LINES_LIMIT = 5;
    
        private class ViewerItem : Object {
            private TreePath path;
            private Fb.Thread thread;
            private Gtk.ListStore list;
            
            private string limit_lines (string text) {
                var lines = text.split("\n");
                if (lines.length > LINES_LIMIT) {
                    lines.resize (LINES_LIMIT);
                    lines[LINES_LIMIT-1] = "...";
                }
                return string.joinv ("\n", lines);
            }

            private bool get_iter (out TreeIter iter) {
                if (!list.get_iter (out iter, path)) {
                    warning ("Failed to get iter");
                    return false;
                }
                return true;
            }
            
            private void update_name () {
                TreeIter iter;
                if (!get_iter (out iter)) {
                    return;
                }
                list.set (iter, Index.PARTICIPANTS, thread.participants_list,
                                Index.NAME, thread.name,
                                Index.TEXT, get_user_markup (), -1);
            }
            
            private void update_photo () {
                TreeIter iter;
                if (!get_iter (out iter)) {
                    return;
                }
                list.set (iter, Index.PHOTO, thread.get_icon (ICON_SIZE), -1);
            }
            
            private void update_time () {
                TreeIter iter;
                if (!get_iter (out iter)) {
                    return;
                }
                list.set (iter, Index.UPDATE_TIME, thread.update_time, -1);
            }
            
            private static string nullable_string (string? str) {
                return str != null ? str : "";
            }
            
            private string get_user_markup () {
                var weight = thread.unread > 0 ? "\"bold\"" : "\"normal\"";
                return "<span font_desc = \"10.0\" weight = %s>%s</span>\n<span font_desc = \"9.0\"
                        foreground = %s weight = %s>%s</span>".printf(
                    weight,
                    Markup.escape_text(nullable_string(thread.name)),
                    thread.unread > 0 ? "\"black\"" : "\"gray\"", weight, 
                    Markup.escape_text(limit_lines(nullable_string(thread.last_message))));
            }
            
            public ViewerItem (Fb.Thread _thread, Gtk.ListStore _list) {
                thread = _thread;
                list = _list;
                
                TreeIter iter;
                list.append (out iter);
                list.set (iter, Index.ID, thread.id,
                    Index.PHOTO, thread.get_icon (ICON_SIZE),
                    Index.NAME, thread.name,
                    Index.MESSAGE, thread.last_message,
                    Index.PARTICIPANTS, thread.participants_list,
                    Index.TEXT, get_user_markup (),
                    Index.UNREAD, thread.unread > 0,
                    Index.UPDATE_TIME, thread.update_time, -1);
                path = list.get_path (iter);
                thread.photo_updated.connect (update_photo);
                thread.name_updated.connect (update_name);
                thread.notify["last-message"].connect ((s, p) => { update_name (); });
                thread.notify["unread"].connect ((s, p) => { update_name (); });
                thread.notify["update-time"].connect ((s, p) => { update_time (); });
            }
        }
        
        private List<ViewerItem> items;
        
        private TreeView view;
        
        private Gtk.ListStore list;
        
        private Gtk.TreeModelSort sorted;
        
        private Gtk.TreeModelFilter filtered;
        
        private string _search_query = "";
        
        private bool inactive = false;
        
        public Widget widget { get { return view; } }
        
        public string search_query { 
            get { return _search_query; }
            set {
                _search_query = value;
                inactive = true;
                filtered.refilter ();
                Timeout.add (100, () => {
                    inactive = false;
                    view.scroll_to_point (0, 0);
                    return false;
                });
            }
        }
        
        private void add_item (Fb.Thread thread) {
            items.append (new ViewerItem (thread, list));
        }
        
        public void clear () {
            list.clear ();
            items = new List<ViewerItem> ();
        }
        
        public new void set_data (Fb.Data data) {
            data.new_thread.connect (add_item);
        }
        
        public ThreadsViewer () {
            list = new Gtk.ListStore (Index.COUNT, typeof (Fb.Id), typeof (Pixbuf), typeof (string), typeof (string),
                                     typeof (string), typeof (string), typeof (bool), typeof(int64), typeof(string));
            sorted = new TreeModelSort.with_model (list);
            sorted.set_sort_column_id (Index.UPDATE_TIME, SortType.DESCENDING);
            filtered = new TreeModelFilter (sorted, null);
            filtered.set_visible_func ((model, iter) => {
                if (search_query == "") {
                    return true;
                }
                int[] ind = { Index.NAME, Index.PARTICIPANTS };
                foreach (var i in ind) {
                    Value val;
                    model.get_value (iter, i, out val);
                    if (val.type () == typeof (string) && search_query.casefold () in val.get_string ().casefold ()) {
                        return true;
                    }
                }
                return false;
            });
            items = new List<ViewerItem> ();
            view = new TreeView ();
            view.set_model (filtered);
            view.can_focus = false;
            view.headers_visible = false;
            view.enable_grid_lines = TreeViewGridLines.HORIZONTAL;
            view.insert_column_with_attributes (-1, "Photo", new CellRendererPixbuf (), "pixbuf", Index.PHOTO);
            
            var name_renderer = new CellRendererText ();
            name_renderer.ellipsize = Pango.EllipsizeMode.END;
            name_renderer.ellipsize_set = true;
            view.insert_column_with_attributes (-1, "Text", name_renderer, "markup", Index.TEXT);
            
            var selection = view.get_selection ();
            selection.mode = SelectionMode.MULTIPLE;
            selection.changed.connect(() => {
                TreeModel model;
                var selected = selection.get_selected_rows (out model);
                if (!inactive && selected.length () != 0) {
                    var path = selected.data;
                    TreeIter iter;
                    model.get_iter (out iter, path);
                    Fb.Id id;
                    model.get (iter, Index.ID, out id, -1);
                    thread_selected (id);
                }
                selection.unselect_all ();
            });
        }
        
    }
    
}
