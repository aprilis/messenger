using Gtk;

namespace Ui {

    public class SettingsWindow : Dialog {

        private Settings settings;

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

            var grid = new Gtk.Grid ();
            grid.row_spacing = 6;
            grid.column_spacing = 20;

            var header = new Gtk.Label ("Preferences");
            header.get_style_context ().add_class ("h4");
            header.halign = Gtk.Align.CENTER;
            header.valign = Gtk.Align.START;
            grid.attach (header, 0, 0, 2, 2);

            var close_and_remove_label = new Gtk.Label ("Close & forget shortcut:");
            close_and_remove_label.halign = Gtk.Align.END;
            var close_and_remove_shortcut = new ShotcutButton (settings.close_and_remove_shortcut);
            settings.schema.bind ("close-and-remove-shortcut", close_and_remove_shortcut, "shortcut", 
                SettingsBindFlags.DEFAULT);
            grid.attach (close_and_remove_label, 0, 2, 1, 1);
            grid.attach (close_and_remove_shortcut, 1, 2, 1, 1);

            var create_new_bubbles_label = new Gtk.Label ("Automatically add bubbles:");
            create_new_bubbles_label.halign = Gtk.Align.END;
            var create_new_bubbles_switch = new Gtk.Switch ();
            create_new_bubbles_switch.halign = Gtk.Align.START;
            create_new_bubbles_switch.active = false;
            settings.schema.bind ("create-new-bubbles", create_new_bubbles_switch, "active", 
                SettingsBindFlags.DEFAULT);

            grid.attach (create_new_bubbles_label, 0, 3, 1, 1);
            grid.attach (create_new_bubbles_switch, 1, 3, 1, 1);
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