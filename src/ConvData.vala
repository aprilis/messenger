using GLib;
using Gee;
using Gdk;

namespace Ui {

    public class ConvData {

        private struct SaveTask {
            Fb.Thread thread;
        }

        private static const int ICON_SIZE = 128;
        
        private string directory;
        private string exec;

        private static const int ICON_SAVERS = 10;
        private GLib.List<Thread<void*>> icon_savers;
        private AsyncQueue<SaveTask?> save_queue;
        private bool closed = false;
        
        private void* icon_saver_run () {
            while (true) {
                var task = save_queue.pop ();
                if (closed) {
                    break;
                }
                var thread = task.thread;
                var file = File.new_for_path (icon_path (thread.id));
                var icon = thread.get_icon (ICON_SIZE);
                if (icon != null) {
                    var stream = file.replace (null, true, FileCreateFlags.PRIVATE);
                    icon.save_to_stream (stream, "png", null);
                }
            }
            return null;
        }

        private void save_icon (Fb.Thread thread, bool overwrite = false) throws Error {
            if (thread.name == null) {
                return;
            }
            var file = File.new_for_path (icon_path (thread.id));
            if (overwrite == false && file.query_exists ()) {
                return;
            }
            save_queue.push ({ thread });
        }
        
        private async void save_desktop_file (Fb.Thread thread, bool overwrite = false) throws Error {
            Idle.add (save_desktop_file.callback, Priority.LOW);
            yield;
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
            var text = kf.to_data ();
            yield file.replace_contents_async (text.data, null, true, FileCreateFlags.PRIVATE, null, null);
        }
        
        public void add_thread (Fb.Thread thread) {
            save_icon (thread);
            save_desktop_file.begin (thread);
            
            thread.photo_changed.connect (() => {
                save_icon (thread, true);
            });
            thread.name_changed.connect (() => {
                save_desktop_file.begin (thread, true);
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
            save_queue = new AsyncQueue<SaveTask?> ();
            for (int i = 0; i < ICON_SAVERS; i++) {
                icon_savers.append(new Thread<void*> (null, icon_saver_run));
            }
        }

        public void close () {
            closed = true;
            for (int i = 0; i < ICON_SAVERS; i++) {
                save_queue.push ({ null });
            }
            foreach (var saver in icon_savers) {
                saver.join ();
            }
        }
    }
}
