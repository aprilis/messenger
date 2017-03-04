using GLib;
using Gee;
using Gdk;

namespace Ui {

    public class ConvData {
        private static const int ICON_SIZE = 128;
        
        private string directory;
        private string exec;
        
        private async void save_icon (Fb.Thread thread, bool overwrite = false) throws Error {
            if (thread.name == null) {
                return;
            }
            var file = File.new_for_path (icon_path (thread.id));
            if (overwrite == false && file.query_exists ()) {
                return;
            }
            Idle.add (save_icon.callback);
            yield;
            var icon = thread.get_icon (ICON_SIZE);
            if (icon == null) {
                icon = new Pixbuf(Colorspace.RGB, true, 8, ICON_SIZE, ICON_SIZE);
                icon.fill ((uint32)0xffffffff);
            }
            
            var stream = yield file.replace_async (null, true, FileCreateFlags.PRIVATE);
            icon.save_to_stream_async.begin (stream, "png", null, (obj, res) => { });
        }
        
        private void save_desktop_file (Fb.Thread thread, bool overwrite = false) throws Error {
            if (thread.name == null) {
                return;
            }
            var file = File.new_for_path (directory + "/" + thread.id.to_string () + ".desktop");
            if (overwrite == false && file.query_exists ()) {
                return;
            }
            var kf = new KeyFile ();
            kf.set_value (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_NAME, thread.name);
            kf.set_value (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_COMMENT, "Start a conversation with " + thread.name);
            kf.set_value (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_TYPE, "Application");
            kf.set_value (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_EXEC, exec + " --open-chat " + thread.id.to_string ());
            kf.set_value (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_ICON, icon_path (thread.id));
            kf.set_value (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_TERMINAL, "false");
            kf.set_value (KeyFileDesktop.GROUP, KeyFileDesktop.KEY_ACTIONS, "Reload;CloseAll;CloseAllOther");
            kf.set_value ("Desktop Action CloseAll", KeyFileDesktop.KEY_NAME, "Close all conversations");
            kf.set_value ("Desktop Action CloseAllOther", KeyFileDesktop.KEY_NAME, "Close all other conversations");
            kf.set_value ("Desktop Action Reload", KeyFileDesktop.KEY_NAME, "Reload page");
            kf.set_value ("Desktop Action CloseAll", KeyFileDesktop.KEY_EXEC, exec + " --close-all");
            kf.set_value ("Desktop Action CloseAllOther", KeyFileDesktop.KEY_EXEC,
                         exec + " --close-all-but-one " + thread.id.to_string ());
            kf.set_value ("Desktop Action Reload", KeyFileDesktop.KEY_EXEC,
                         exec + " --reload-chat " + thread.id.to_string ());
            
            kf.save_to_file (desktop_file_path (thread.id));
        }
        
        public void add_thread (Fb.Thread thread) {
            save_icon.begin (thread);
            save_desktop_file (thread);
            
            thread.photo_changed.connect (() => {
                save_icon.begin (thread, true);
            });
            thread.name_changed.connect (() => {
                save_desktop_file (thread, true);
            });
        }
        
        public string desktop_file_path (Fb.Id id) {
            return directory + "/" + id.to_string () + ".desktop";
        }
        
        public string icon_path (Fb.Id id) {
            return directory + "/" + id.to_string () + ".png";
        }
        
        public string desktop_file_uri (Fb.Id id) {
            var file = File.new_for_path (desktop_file_path (id));
            return file.get_uri ();
        }
        
        public ConvData (string dir_path, string exe_path) {
            directory = dir_path;
            exec = exe_path;
        }       
    }
}
