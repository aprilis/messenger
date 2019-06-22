using Gtk;

namespace Ui {

    public class LoadingScreen : Screen {

        private InfoBar network_error_bar;

        public LoadingScreen (Fb.App app) {
            title = _("Loading");
            name = "loading";

            network_error_bar = Utils.create_infobar (_("No connection"), MessageType.ERROR, false);
            network_error_bar.add_button (_("Retry"), 1);
            network_error_bar.response.connect ((id) => { if (id == 1) app.reconnect (); });

            var box = new Box (Orientation.VERTICAL, 0);
            box.pack_start (network_error_bar, false);
            box.pack_start (new Loading (40));
            widget = box;

            if (app.data != null) {
                app.data.loading_finished.connect (() => { change_screen ("threads"); });
            }
            app.notify["data"].connect ((s, p) => {
                app.data.loading_finished.connect (() => { change_screen ("threads"); });
            });
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