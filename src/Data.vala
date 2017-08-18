using GLib;
using Gee;
using Gdk;
using Utils;

namespace Fb {

    public class Data : Object {
        
        private struct DownloadTask {
            int64 priority;
            string uri;
            int64 contact_id;
        }

        private struct LoadTask {
            string path;
            Promise<Pixbuf> promise;
        }

        private static string DATA_PATH;
        private static string CONTACTS_PATH;
        private static string THREADS_PATH;
        private static string PICTURES_PATH;
        private static string DESKTOP_PATH;
        
        private const int64 UPDATE_THREAD_INTERVAL = 1000000; //one second
        private const int DOWNLOAD_LIMIT = 3;
        
        private HashMap<Id?, Contact> contacts;
    
        private HashMap<Id?, Thread> threads;

        public HashSet<Id?> null_contacts { get; private set; }
        
        private Soup.Session session;
        
        private SocketClient client;
        
        private App app;
        
        private Api api;

        private Ui.ConvData conv_data;
                
        private ThreadPool<DownloadTask?> photo_downloader;

        private GLib.Queue<LoadTask?> load_queue;
        private int opened_files = 0;
        private const int OPENED_FILES_LIMIT = 100;

        private bool closed = false;

        private DelayedOps collective_updates;
        private DelayedOps selective_updates;
        
        public signal void new_contact (Contact contact);
        public signal void new_thread (Thread thread);
        public signal void new_message (Thread thread, string message);
        public signal void unread_count (Id id, int count);
        public signal void loading_finished ();
        
        private string photo_path (Id id) {
            return PICTURES_PATH + "/" + id.to_string () + ".jpg";
        }
        
        private async void load_from_disk () {
            try {
                var file = File.new_for_path (CONTACTS_PATH);
                var stream = yield file.read_async();
                var parser = new Json.Parser ();
                yield parser.load_from_stream_async (stream);
                
                Idle.add (load_from_disk.callback);
                yield;
                
                var array = parser.get_root ().get_array ();
                foreach (var node in array.get_elements ()) {
                    var contact = new Contact.from_disk (node);
                    new_contact (contact);
                    if (contact.is_friend) {
                        add_thread (new SingleThread.with_contact (contact));
                    }
                    contacts [contact.id] = contact;
                }
                
                file = File.new_for_path (THREADS_PATH);
                stream = yield file.read_async ();
                parser = new Json.Parser();
                yield parser.load_from_stream_async (stream);
                
                array = parser.get_root ().get_array ();
                foreach (var node in array.get_elements ()) {
                    var object = node.get_object ();
                    var id = object.get_int_member ("id");
                    var group = object.get_boolean_member ("is_group");
                    var thread = get_thread (id, group);
                    thread.load_from_json (node);
                }
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
            collective_updates.release ();
        }
        
        private async void save_contacts () {
            try {
                Idle.add (save_contacts.callback);
                yield;
                var builder = new Json.Builder();
                builder.begin_array ();
                foreach (var contact in contacts.values) {
                    contact.to_json (builder);
                }
                builder.end_array ();
                var generator = new Json.Generator ();
                generator.root = builder.get_root();
                
                var file = File.new_for_path (CONTACTS_PATH);
                var stream = file.replace (null, true, FileCreateFlags.PRIVATE);
                generator.to_stream (stream);
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }
        
        private async void save_threads () {
            try {
                Idle.add (this.save_threads.callback);
                yield;
                var builder = new Json.Builder();
                builder.begin_array ();
                foreach (var thread in threads.values) {
                    thread.to_json (builder);
                }
                builder.end_array ();
                var generator = new Json.Generator ();
                generator.root = builder.get_root();
                
                var file = File.new_for_path (THREADS_PATH);
                var stream = file.replace (null, true, FileCreateFlags.PRIVATE);
                generator.to_stream (stream);
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }
        
        private void add_thread (Thread thread) {
            threads [thread.id] = thread;
            new_thread (thread);
        }
        
        public static void delete_files () {
            try {
                var file = File.new_for_path (THREADS_PATH);
                if (file.query_exists ()) {
                    file.delete ();
                }
                file = File.new_for_path (CONTACTS_PATH);
                if (file.query_exists ()) {
                    file.delete ();
                }
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }
        
        public Contact get_contact (Id id, bool query = true) {
            if (!contacts.has_key (id)) {
                contacts [id] = new Contact (id);
                new_contact (contacts [id]);
            }
            var contact = contacts [id];
            if (query) {
                selective_updates.add (() => {
                    if (!contact.is_loaded) {
                        app.query_contact (contact.id);
                    }
                });
            }
            return contact;
        }

        public Thread get_thread (Id id, bool group) {
            if (!threads.has_key (id)) {
                var thread = group ? new GroupThread (id) as Thread : new SingleThread (id) as Thread;
                add_thread (thread);
            }
            var thread = threads [id];
            return thread;
        }
        
        public void download_photo (string uri, int64 priority, Fb.Id id) {
            if (closed) {
                return;
            }
            DownloadTask task = { priority, uri, id };
            photo_downloader.add (task);
        }
        
        public void save_photo (Pixbuf photo, Id id) throws Error {
            var file = File.new_for_path (photo_path (id));
            var stream = file.replace (null, true, FileCreateFlags.PRIVATE);
            photo.save_to_stream (stream, "jpeg");
        }

        private async bool update_load_queue () {
            if (!load_queue.is_empty () && opened_files < OPENED_FILES_LIMIT) {
                opened_files++;
                var task = load_queue.pop_head ();
                try {
                    var file = File.new_for_path (task.path);
                    var stream = yield file.read_async ();
                    var photo = yield new Pixbuf.from_stream_async (stream, null);
                    task.promise.set_value (photo);
                } catch (Error e) {
                    warning ("Error while loading photo: %d %s\n", e.code, e.message);
                    task.promise.set_value (null);
                }
                opened_files--;
                update_load_queue.begin();
            }
            return false;
        }
        
        public async Pixbuf load_photo (Id id) throws Error {
            var promise = new Promise<Pixbuf> ();
            load_queue.push_tail ({photo_path (id), promise});
            update_load_queue.begin ();
            return yield promise.future.wait_async ();
        }

        public bool parse_contact (ApiUser user, bool friends_only) {
            if (user.name == null) {
                null_contacts.add (user.uid);
                return false;
            }
            if (friends_only && !user.is_friend && !(user.uid in contacts)) {
                return false;
            }
            var contact = get_contact (user.uid, false);
            contact.load_from_api (user);
            if (user.uid == api.uid) {
                contact.download_photo (int64.MAX);
            }
            if (user.is_friend && !threads.has_key (user.uid)) {
                add_thread (new SingleThread.with_contact (contacts[user.uid]));
            }
            return true;
        }
        
        public void parse_contacts (SList<ApiUser?> users, bool friends_only = false) {
            bool any = false;
            foreach (var user in users) {
                if (user == null) {
                    selective_updates.release ();
                    save_contacts ();
                } else if (parse_contact (user, friends_only)) {
                    any = true;
                }
            }
            if (!any) {
                selective_updates.release ();
            }
        }
        
        public void contacts_done (void *ptr, bool complete) {
            unowned SList<ApiUser?> users = (SList<ApiUser?>) ptr;
            var copy = users.copy_deep ((user) => { return user.dup (true); });
            if (complete) {
                copy.append (null);
            }
            collective_updates.add (() => {
                parse_contacts (copy);
            });
        }
        
        public void contact_done (void *ptr) {
            unowned ApiUser user = (ApiUser) ptr;
            if (parse_contact (user, false)) {
                contacts[user.uid].download_photo (1);
                save_contacts ();
            }
        }
        
        private void update_thread (Fb.ApiThread thread) {
            if (thread.tid in null_contacts) {
                return;
            }
            var th = get_thread (thread.tid, thread.is_group);
            if (th.load_from_api (thread) && th.unread > 0 && th.mute_until == 0) {
                th.do_when_ready (() => { new_message (th, th.last_message); });
            }
            th.do_when_ready (() => { unread_count (th.id, th.unread); });
        }
        
        public void parse_threads (SList<ApiThread> threads) {
            foreach (var thread in threads) {
                update_thread (thread);
            }
            save_threads ();
            selective_updates.add (() => {
                foreach (var contact in contacts.values) {
                    contact.download_photo (1);
                }
            });
            loading_finished ();
        }
        
        public void threads_done (void *ptr) {
            unowned SList<ApiThread> threads = (SList<ApiThread>) ptr;
            var copy = threads.copy_deep ((thread) => { return thread.dup(true); });
            collective_updates.add (() => {
                parse_threads (copy);
            });
        }
        
        public void thread_done (void *ptr) {
            unowned Fb.ApiThread? thread = (Fb.ApiThread?)ptr;
            update_thread (thread);
            save_threads ();
        }
        
        private void messages (void *ptr) {
            unowned SList<ApiMessage?> msgs = (SList<ApiMessage?>)ptr;
            foreach (unowned ApiMessage? msg in msgs) {
                if (msg.tid == 0) {
                    msg.tid = msg.uid;
                }
                var time = get_monotonic_time () + UPDATE_THREAD_INTERVAL;
                var last_time = msg.tid in threads ? threads [msg.tid].update_request_time : 0;
                if (last_time + UPDATE_THREAD_INTERVAL < time) {
                    threads [msg.tid].update_request_time = time;
                    app.query_thread (msg.tid);
                } else if (last_time < time) {
                    threads [msg.tid].update_request_time = time + UPDATE_THREAD_INTERVAL;
                    Timeout.add ((uint)(UPDATE_THREAD_INTERVAL / 1000), () => {
                        app.query_thread (msg.tid);
                        return false;
                    });
                }
            }
        }
        
        private void make_dir (string path) {
            var dir = File.new_for_path (path);
            if (!dir.query_exists ()) {
                try {
                    dir.make_directory ();
                } catch (Error e) {
                    warning ("%s\n", e.message);
                }
            }
        }
        
        public string desktop_file_uri (Fb.Id id) {
            return conv_data.desktop_file_uri (id);
        }
        
        public string icon_path (Fb.Id id) {
            return conv_data.icon_path (id);
        }
        
        public void check_unread_count (Fb.Id id) {
            if (!(id in threads)) {
                app.query_thread (id);
            } else {
                unread_count (id, threads [id].unread);
            }
        }
        
        public void read_all (Fb.Id id) {
            if (id in threads) {
                threads [id].unread = 0;
                unread_count (id, 0);
            }
            api.read (id, id in threads ? threads [id].is_group : true);
        }

        private void photo_downloader_func (owned DownloadTask? task) {
            try {
                var request = session.request (task.uri);
                var stream = request.send ();
                var pixbuf = new Pixbuf.from_stream (stream);
                Idle.add (() => {
                    get_contact (task.contact_id).photo_downloaded (pixbuf);
                    return false;
                });
                save_photo (pixbuf, task.contact_id);
            } catch (Error e) {
                warning ("Photo downloader error: %s\n", e.message);
            }
        }
        
        public static void init_paths () {
            DATA_PATH = Main.data_path + "/data";
            CONTACTS_PATH = DATA_PATH + "/contacts";
            THREADS_PATH = DATA_PATH + "/threads";
            PICTURES_PATH = DATA_PATH + "/pictures";
            DESKTOP_PATH = DATA_PATH + "/desktop";
        }

        public Data (Soup.Session ses, SocketClient cli, App ap, Api a) {
            session = ses;
            client = cli;
            app = ap;
            api = a;
            
            conv_data = new Ui.ConvData (DESKTOP_PATH, Main.APP_NAME, Main.OPEN_CHAT_NAME);
            new_thread.connect (conv_data.add_thread);
            
            contacts = new HashMap<Id?, Contact> (my_id_hash, my_id_equal);
            threads = new HashMap<Id?, Thread> (my_id_hash, my_id_equal);
            null_contacts = new HashSet<Id?> (my_id_hash, my_id_equal);

            collective_updates = new DelayedOps ();
            selective_updates = new DelayedOps ();

            make_dir (DATA_PATH);
            make_dir (PICTURES_PATH);
            make_dir (DESKTOP_PATH);
            
            load_from_disk.begin ();
            
            api.contacts.connect (contacts_done);
            api.contact.connect (contact_done);
            api.threads.connect (threads_done);
            api.thread.connect (thread_done);
            api.messages.connect (messages);

            load_queue = new GLib.Queue<LoadTask?> ();

            photo_downloader = new ThreadPool<DownloadTask?>.with_owned_data (photo_downloader_func,
                DOWNLOAD_LIMIT, false);
            photo_downloader.set_sort_function ((task1, task2) => {
                if (task1.priority < task2.priority) {
                    return 1;
                } else if (task1.priority == task2.priority) {
                    return 0;
                } else {
                    return -1;
                }
            });
        }

        public void close () {
            if (!closed) {
                closed = true;
                ThreadPool.free ((owned) photo_downloader, true, false);
                conv_data.close ();
            }
        }

        ~Data () {
            close ();
        }
    }

}
