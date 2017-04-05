using Gtk;
using GLib;
using WebKit;

namespace Ui {

    class LoginDialog : Window {

        private const string MESSENGER_URL = "https://www.messenger.com";
        private const string LOGIN_URL = MESSENGER_URL + "/login";
        private const string SUCCESS_URL = MESSENGER_URL + "/t/";

        private const string INIT_SCRIPT = """
                document.onreadystatechange = function () {
                    if (document.readyState == 'complete') {
                        document.getElementById('u_0_3').checked = true;
                    }
                }​;
                """;

        private WebView webview;

        private bool is_finished = false;

        public signal void finished ();
        public signal void canceled ();

        public LoginDialog (bool show_infobar) {

            title = "Messenger - authentication";
            set_size_request(800, 600);
            webview = new WebView ();

            webview.load_changed.connect ((load_event) => {
                if (load_event == LoadEvent.FINISHED) {
                    var uri = webview.get_uri ();
                    if (uri.has_prefix (SUCCESS_URL) || uri == MESSENGER_URL + "/") {
                        print ("finished\n");
                        is_finished = true;
                        finished ();
                    } else if (uri.has_prefix (LOGIN_URL)) {
                        webview.run_javascript (INIT_SCRIPT, null);
                    }
                }
            });

            webview.load_uri (LOGIN_URL);

            var box = new Box (Orientation.VERTICAL, 0);

            if (show_infobar) {
                var infobar = Utils.create_infobar("Application password detected. Please log in with you real password here",
                                                MessageType.INFO, true);
                infobar.show ();
                box.pack_start (infobar, false, false);
            }

            box.pack_start (webview);
            add (box);

            destroy.connect (() => { if (!is_finished) { canceled (); } });
        }

    }

}