namespace Ui {

    /////////////////////////////////////////////////////////////////////////
    /// Some helper methods which focus the input on a given Gtk.Window.
    /////////////////////////////////////////////////////////////////////////

    public class FocusGrabber : GLib.Object {

        /////////////////////////////////////////////////////////////////////
        /// Utilities for grabbing focus.
        /// Code roughly from Gnome-Do/Synapse.
        /////////////////////////////////////////////////////////////////////

        public static void grab(Gdk.Window window, bool keyboard = true, bool pointer = true, bool owner_events = true) {
            if (keyboard || pointer) {
                window.raise();
                window.focus(Gdk.CURRENT_TIME);

                if (!try_grab_window(window, keyboard, pointer, owner_events)) {
                    int i = 0;
                    Timeout.add(100, () => {
                        if (++i >= 100) {
                            warning ("grab failed");
                            return false;
                        }
                        return !try_grab_window(window, keyboard, pointer, owner_events);
                    });
                }
            }
        }

        /////////////////////////////////////////////////////////////////////
        /// Code roughly from Gnome-Do/Synapse.
        /////////////////////////////////////////////////////////////////////

        public static void ungrab(bool keyboard = true, bool pointer = true) {
            var display = Gdk.Display.get_default();
            var manager = display.get_device_manager();

            GLib.List<weak Gdk.Device?> list = manager.list_devices(Gdk.DeviceType.MASTER);

            foreach(var device in list) {
                if ((device.input_source == Gdk.InputSource.KEYBOARD && keyboard)
                 || (device.input_source != Gdk.InputSource.KEYBOARD && pointer))

                    device.ungrab(Gdk.CURRENT_TIME);
            }
        }

        /////////////////////////////////////////////////////////////////////
        /// Code roughly from Gnome-Do/Synapse.
        /////////////////////////////////////////////////////////////////////

        private static bool try_grab_window(Gdk.Window window, bool keyboard, bool pointer, bool owner_events) {
            var display = Gdk.Display.get_default();
            var manager = display.get_device_manager();

            bool grabbed_all = true;

            GLib.List<weak Gdk.Device?> list = manager.list_devices(Gdk.DeviceType.MASTER);

            foreach(var device in list) {
                if ((device.input_source == Gdk.InputSource.KEYBOARD && keyboard)
                 || (device.input_source != Gdk.InputSource.KEYBOARD && pointer)) {

                    var status = device.grab(window, Gdk.GrabOwnership.APPLICATION, owner_events,
                                             Gdk.EventMask.ALL_EVENTS_MASK, null, Gdk.CURRENT_TIME);

                    if (status != Gdk.GrabStatus.SUCCESS)
                        grabbed_all = false;
                }
            }

            if (grabbed_all) {
                return true;
            }

            ungrab(keyboard, pointer);

            return false;
        }
    }

}
