using Gtk;

namespace Ui {

    public class SettingsWindow : Dialog {

        private Settings settings;

        private Label create_label (string text) {
            var label = new Gtk.Label (text);
            label.halign = Gtk.Align.END;
            label.justify = Justification.RIGHT;
            label.wrap = true;
            label.wrap_mode = Pango.WrapMode.WORD_CHAR;
            label.max_width_chars = 30;
            return label;
        }

        private Switch create_switch (Settings settings, string property) {
            var swit = new Gtk.Switch ();
            swit.halign = Gtk.Align.START;
            swit.valign = Gtk.Align.CENTER;
            swit.active = false;
            settings.schema.bind (property, swit, "active", 
                SettingsBindFlags.DEFAULT);
            return swit;
        }

        public SettingsWindow (Gtk.Window? parent, Settings settings) {
            border_width = 10;
            deletable = false;
            resizable = false;
            title = "Preferences";
            transient_for = parent;
            destroy_with_parent = true;
            modal = true;
            window_position = Gtk.WindowPosition.CENTER_ON_PARENT;

            this.settings = settings;

            var close = add_button ("Close", Gtk.ResponseType.CLOSE);
            response.connect ((id) => { destroy(); });
            destroy.connect (() => {
                if (parent != null) {
                    parent.show_all ();
                }
            });

            var grid = new Gtk.Grid ();
            grid.row_spacing = 6;
            grid.column_spacing = 20;

            var header = new Gtk.Label ("Preferences");
            header.get_style_context ().add_class ("h4");
            header.halign = Gtk.Align.CENTER;
            header.valign = Gtk.Align.START;
            grid.attach (header, 0, 0, 2, 2);

            var close_and_remove_label = create_label ("Close & forget shortcut:");
            var close_and_remove_shortcut = new ShotcutButton (settings.close_and_remove_shortcut);
            settings.schema.bind ("close-and-remove-shortcut", close_and_remove_shortcut, "shortcut", 
                SettingsBindFlags.DEFAULT);
            grid.attach (close_and_remove_label, 0, 2, 1, 1);
            grid.attach (close_and_remove_shortcut, 1, 2, 1, 1);

            var create_new_bubbles_label = create_label ("Automatically add bubbles:");
            var create_new_bubbles_switch = create_switch (settings, "create-new-bubbles");
            grid.attach (create_new_bubbles_label, 0, 3, 1, 1);
            grid.attach (create_new_bubbles_switch, 1, 3, 1, 1);

            var window_bubble_label = create_label ("Main window in a bubble (restart required):");
            var window_bubble_switch = create_switch (settings, "main-window-bubble");
            grid.attach (window_bubble_label, 0, 4, 1, 1);
            grid.attach (window_bubble_switch, 1, 4, 1, 1);

            var close_bubbles_label = create_label ("Close bubbles on quit");
            var close_bubbles_switch = create_switch (settings, "close-bubbles-on-quit");
            grid.attach (close_bubbles_label, 0, 5, 1, 1);
            grid.attach (close_bubbles_switch, 1, 5, 1, 1);
                    
            grid.margin_bottom = 40;

            var content = (Gtk.Container) get_content_area ();
            content.add (grid);

        }
    }

    public class ShotcutButton : Button {

        private string _shortcut;
        private bool _listen = false;

        private bool listen {
            get { return _listen; }
            set {
                _listen = value;
                if (value) {
                    label = "Press some keys!";
                }
                else {
                    label = new Shortcut.parse (shortcut).to_readable ();
                }
            }
        }

        public string shortcut {
            get { return _shortcut; }
            set {
                _shortcut = value;
                label = new Shortcut.parse (_shortcut).to_readable ();
            }
        }

        public ShotcutButton (string initial) {
            width_request = 128;
            shortcut = initial;
            get_style_context ().add_class ("flat");
            set_focus_on_click (true);
            clicked.connect (() => {
                listen = !listen;
            });
            grab_broken_event.connect ((event) => {
                listen = false;
                return false;
            });
            focus_out_event.connect ((event) => {
                listen = false;
                return false;
            });
            key_press_event.connect ((event) => {
                if (event.keyval != 0 && event.is_modifier == 0) {
                    var sc = new Shortcut (event.keyval, event.state);
                    shortcut = sc.to_gsettings ();
                    listen = false;
                }
                return false;
            });
        }

    }

}