using GLib;
using Gtk;
using Gdk;
using Gee;

namespace Ui { 
    
    public class GroupCreator : Object {
        
        private enum Index {
            ID,
            PHOTO,
            NAME,
            IS_FRIEND,
            COUNT
        }
        
        const int ICON_SIZE = 40;
        const int FADED_BORDER = 5;
    
        private class ViewerItem : Object {
            private TreePath path;
            private Fb.Contact contact;
            private Gtk.ListStore list;

            private bool get_iter (out TreeIter iter) {
                if (list.get_iter (out iter, path)) {
                    Fb.Id id;
                    list.get (iter, Index.ID, out id); 
                    if (id == contact.id) {
                        return true;
                    }
                }
                list.get_iter_first (out iter);
                do {
                    Fb.Id id;
                    list.get (iter, Index.ID, out id);
                    if (id == contact.id) {
                        return true;
                    }
                } while (list.iter_next (ref iter));
                return false;
            }
            
            private void update_contact () {
                TreeIter iter;
                if (!get_iter (out iter)) {
                    return;
                }
                list.set (iter, Index.NAME, contact.name,
                                Index.IS_FRIEND, contact.is_friend, -1);
            }

            private Pixbuf get_photo () {
                if (contact.photo == null) {
                    return null;
                }
                return Utils.make_icon (contact.photo, ICON_SIZE);
            }
            
            private void update_photo () {
                TreeIter iter;
                if (!get_iter (out iter)) {
                    return;
                }
                list.set (iter, Index.PHOTO, get_photo (), -1);
            }

            public void change_list (Gtk.ListStore new_list) {
                if (new_list == list) {
                    return;
                }
                TreeIter iter;
                if (get_iter (out iter)) {
                    list.remove (ref iter);
                }
                list = new_list;
                list.prepend (out iter);
                list.set (iter, Index.ID, contact.id,
                    Index.PHOTO, get_photo (),
                    Index.NAME, contact.name,
                    Index.IS_FRIEND, contact.is_friend, 
                    -1);
                path = list.get_path (iter);
            }
            
            public ViewerItem (Fb.Contact _contact, Gtk.ListStore _list) {
                contact = _contact;
                list = _list;
                
                TreeIter iter;
                list.append (out iter);
                list.set (iter, Index.ID, contact.id,
                    Index.PHOTO, get_photo (),
                    Index.NAME, contact.name,
                    Index.IS_FRIEND, contact.is_friend, 
                    -1);
                path = list.get_path (iter);
                contact.notify["photo"].connect (update_photo);
                contact.notify["name"].connect (update_contact);
                contact.notify["is-friend"].connect ((s, p) => { update_contact (); });
            }
        }

        public signal void create_group (GLib.SList<Fb.Id?> ids, string name);
        
        private HashMap<Fb.Id?, ViewerItem> items;
        
        private TreeView search_view;
        
        private Gtk.ListStore search_list;
        
        private TreeModelSort sorted;
        
        private TreeModelFilter filtered;

        private TreeView group_view;

        private Gtk.ListStore group_list;
        
        private string _search_query = "";
        
        private bool inactive = false;

        private Fb.Data data;

        private MenuButton button;

        private Stack stack;

        private Button create_button;

        private Entry name_entry;

        private Popover popover;

        private void update_create_button () {
            create_button.sensitive = selected > 1;
        }

        private int _selected = 0;

        private int selected {
            get { return _selected; }
            set {
                _selected = value;
                if (value == 0) {
                    stack.visible_child_name = "placeholder";
                } else {
                    stack.visible_child_name = "list";
                }
                update_create_button ();
            }
        }

        public Widget widget {
            get {
                return button;
            }
        }

        public bool active {
            get {
                return button.active;
            }
        }

        public string search_query { 
            get { return _search_query; }
            set {
                _search_query = value;
                inactive = true;
                filtered.refilter ();
                Timeout.add (100, () => {
                    inactive = false;
                    search_view.scroll_to_point (0, 0);
                    return false;
                });
            }
        }

        private void add_item (Fb.Contact contact) {
            if (contact.id != data.user_id) {
                items [contact.id] = new ViewerItem (contact, search_list);
            }
        }

        public void clear () {
            search_list.clear ();
            items.clear ();
        }
        
        public new void set_data (Fb.Data _data) {
            data = _data;
            data.new_contact.connect (add_item);
        }

        public GroupCreator () {
            search_list = new Gtk.ListStore (Index.COUNT, typeof (Fb.Id), typeof (Pixbuf),
                                                     typeof (string), typeof (bool));
            sorted = new TreeModelSort.with_model (search_list);
            sorted.set_sort_column_id (Index.NAME, SortType.ASCENDING);
            filtered = new TreeModelFilter (sorted, null);
            filtered.set_visible_func ((model, iter) => {
                Value val;
                model.get_value (iter, Index.NAME, out val);
                if (val.type () == typeof (string) && val.get_string () != null && val.get_string () != ""
                     && search_query.casefold () in val.get_string ().casefold ()) {
                    return true;
                }
                return false;
            });
            items = new HashMap<Fb.Id?, ViewerItem> (Utils.my_id_hash, Utils.my_id_equal);
            search_view = new TreeView ();
            search_view.show ();
            search_view.set_model (filtered);
            search_view.headers_visible = false;
            search_view.activate_on_single_click = true;
            search_view.hover_selection = true;

            search_view.row_activated.connect ((path, column) => {
                TreeIter iter;
                Fb.Id id;

                filtered.get_iter (out iter, path);
                filtered.get (iter, Index.ID, out id);

                items [id].change_list (group_list);
                Timeout.add (50, () => {
                    group_view.scroll_to_point (0, 0);
                    return false;
                });
                selected++;
            });

            search_view.insert_column_with_attributes (-1, "Photo", new CellRendererPixbuf (), "pixbuf", Index.PHOTO);
            
            var name_renderer = new CellRendererText ();
            name_renderer.ellipsize = Pango.EllipsizeMode.END;
            name_renderer.ellipsize_set = true;
            search_view.insert_column_with_attributes (-1, "Text", name_renderer, "text", Index.NAME);
            
            var search_window = new ScrolledWindow (null, null);
            search_window.add (search_view);
            search_window.show ();

            var search_faded = new FadeOutBin (FADED_BORDER);
            search_faded.add (search_window);
            search_faded.show ();

            var search_entry = new SearchEntry ();
            search_entry.placeholder_text = "Search for friends...";
            search_entry.search_changed.connect (() => {
                search_query = search_entry.text;
            });
            search_entry.show ();

            group_list = new Gtk.ListStore (Index.COUNT, typeof (Fb.Id), typeof (Pixbuf),
                                             typeof (string), typeof (bool));
            group_view = new TreeView ();
            group_view.show ();
            group_view.set_model (group_list);
            group_view.headers_visible = false;
            group_view.activate_on_single_click = true;
            group_view.hover_selection = true;

            group_view.row_activated.connect ((path, column) => {
                if (column.title == "Delete") {
                    TreeIter iter;
                    Fb.Id id;

                    group_list.get_iter (out iter, path);
                    group_list.get (iter, Index.ID, out id);

                    items [id].change_list (search_list);
                    selected--;
                }
            });

            group_view.insert_column_with_attributes (-1, "Photo", new CellRendererPixbuf (), "pixbuf", Index.PHOTO);

            name_renderer = new CellRendererText ();
            name_renderer.ellipsize = Pango.EllipsizeMode.END;
            name_renderer.ellipsize_set = true;
            var name_column = new TreeViewColumn.with_attributes ("Text", name_renderer,
                "text", Index.NAME);
            name_column.expand = true;
            group_view.append_column (name_column);
            
            var delete_renderer = new CellRendererPixbuf ();
            delete_renderer.icon_name = "window-close";
            delete_renderer.xpad = 6;
            group_view.insert_column_with_attributes (-1, "Delete", delete_renderer);

            var group_window = new ScrolledWindow (null, null);
            group_window.add (group_view);
            group_window.show ();

            var group_faded = new FadeOutBin (FADED_BORDER);
            group_faded.add (group_window);
            group_faded.show ();

            var placeholder = new Label ("Select friends to make a new group");
            placeholder.wrap = true;
            placeholder.wrap_mode = Pango.WrapMode.WORD;
            placeholder.get_style_context ().add_class (Gtk.STYLE_CLASS_DIM_LABEL);
            placeholder.get_style_context ().add_class ("h3");
            placeholder.show ();

            name_entry = new Gtk.Entry ();
            name_entry.placeholder_text = "Group name (optional)";
            name_entry.show ();

            create_button = new Button.with_label ("Create!");
            create_button.sensitive = false;
            create_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            create_button.show ();
            create_button.clicked.connect (() => {
                var ids = new GLib.SList<Fb.Id?> ();
                TreeIter iter;
                group_list.get_iter_first (out iter);
                while (group_list.iter_is_valid (iter)) {
                    Fb.Id id;
                    group_list.get (iter, Index.ID, out id);
                    ids.append (id);
                    group_list.iter_next (ref iter);
                }
                create_group (ids, name_entry.text);
                popover.hide ();
            });
            create_button.tooltip_text = "You have to select at least 2 users";

            var bottom_box = new Box (Orientation.HORIZONTAL, 5);
            bottom_box.pack_start (name_entry, true, true);
            bottom_box.pack_start (create_button, false, false);
            bottom_box.show ();

            stack = new Gtk.Stack ();
            stack.add_named (placeholder, "placeholder");
            stack.add_named (group_faded, "list");
            stack.homogeneous = true;
            stack.transition_duration = 100;
            stack.transition_type = StackTransitionType.SLIDE_LEFT_RIGHT;
            stack.show ();

            var separator = new Separator (Orientation.HORIZONTAL);
            separator.show ();

            var box = new Box (Orientation.VERTICAL, 10);
            box.margin_left = box.margin_right = box.margin_top = box.margin_bottom = 10;
            box.pack_start (search_entry, false, false);
            box.pack_start (search_faded);
            box.pack_start (separator, false, false);
            box.pack_start (stack);
            box.pack_start (bottom_box, false, false);
            box.show ();

            button = new MenuButton ();

            popover = new Popover (button);
            popover.set_size_request (400, 350);
            popover.modal = true;
            popover.add (box);

            popover.closed.connect (() => {
                search_entry.text = "";
                name_entry.text = "";
                selected = 0;
                foreach (var item in items.values) {
                    item.change_list (search_list);
                }
            });

            var image = new Gtk.Image.from_icon_name ("system-users-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            button.image = image;
            button.popover = popover;
            button.tooltip_text = "Create a new group thread";
        }

    }

}