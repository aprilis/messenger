using GLib;
using Gee;
using Gdk;

namespace Fb {

    bool my_id_equal (Fb.Id? a, Fb.Id? b) {
        return a == b;
    }
    
    uint my_id_hash (Fb.Id? id) {
        return (uint) id;
    }

    public class Data : Object {
        
        private string DATA_PATH;
        private string CONTACTS_PATH;
        private string THREADS_PATH;
        private string PICTURES_PATH;
        private string DESKTOP_PATH;
        
        private const int64 UPDATE_THREAD_INTERVAL = 1000000; //one second
        
        private HashMap<Id?, Contact> contacts;
    
        private HashMap<Id?, Thread> threads;
        
        private Soup.Session session;
        
        private SocketClient client;
        
        private Api api;
        
        private Ui.ConvData conv_data;
        
        private SList<ApiUser> waiting_users;
        private SList<ApiThread> waiting_threads;
        
        private bool _contacts_allowed = false;
        private bool contacts_allowed {
            get { return _contacts_allowed; }
            set {
                _contacts_allowed = value;
                check_waiting ();
            }
        }
        
        private bool _threads_allowed = false;
        private bool threads_allowed {
            get { return _threads_allowed; }
            set {
                _threads_allowed = value;
                check_waiting ();
            }
        }
        
        public signal void new_contact (Contact contact);
        public signal void new_thread (Thread thread);
        public signal void new_message (Thread thread, string message);
        public signal void unread_count (Id id, int count);
        public signal void loading_finished ();
        
        private string photo_path (Id id) {
            return PICTURES_PATH + "/" + id.to_string () + ".jpg";
        }
        
        private async void load_from_disk () {
            contacts.clear ();
            threads.clear ();
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
                    var thread = get_thread (id, group, false);
                    thread.load_from_json (node);
                }
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
            contacts_allowed = true;
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
        
        public void delete_files () {
            try {
                var file = File.new_for_path (THREADS_PATH);
                file.delete ();
                file = File.new_for_path (CONTACTS_PATH);
                file.delete ();
            } catch (Error e) {
                warning ("%s\n", e.message);
            }
        }
        
        public Contact get_contact (Id id, bool send_query) {
            if (!contacts.has_key (id)) {
                contacts [id] = new Contact (id);
                new_contact (contacts [id]);
            }
            var contact = contacts [id];
            if (send_query && !contact.is_loaded) {
                api.contact_func (id);
            }
            return contact;
        }
        
        public Thread get_thread (Id id, bool group, bool send_query) {
            if (!threads.has_key (id)) {
                var thread = group ? new GroupThread (id) as Thread : new SingleThread (id, send_query) as Thread;
                add_thread (thread);
            }
            var thread = threads [id];
            if (send_query) {
                if (!thread.is_group && !(thread as SingleThread).contact.is_loaded) {
                    api.contact_func (id);
                }
                if (!thread.is_loaded) {
                    api.thread_func (id);
                }
            }
            return thread;
        }
        
        public async Pixbuf download_photo (string uri) throws Error {
            var request = session.request (uri);
            var stream = yield request.send_async (null);
            return yield new Pixbuf.from_stream_async (stream, null);
        }
        
        public async void save_photo (Pixbuf photo, Id id) throws Error {
            var file = File.new_for_path (photo_path (id));
            var stream = yield file.replace_async (null, true, FileCreateFlags.PRIVATE);
            photo.save_to_stream_async.begin (stream, "jpeg", null, (obj, res) => { });
        }
        
        public async Pixbuf load_photo (Id id) throws Error {
            var file = File.new_for_path (photo_path (id));
            var stream = yield file.read_async ();
            return yield new Pixbuf.from_stream_async (stream, null);
        }
        
        public void parse_contacts (SList<ApiUser> users, bool friends_only = false) {
            foreach (var user in users) {
                if(user.name == null || (friends_only && !user.is_friend)) {
                    continue;
                }
                get_contact (user.uid, false).load_from_api (user);
                if (user.is_friend && !threads.has_key (user.uid)) {
                    add_thread (new SingleThread.with_contact (contacts[user.uid]));
                }
            }
            save_contacts ();
            threads_allowed = true;
        }
        
        public void contacts_done (void *ptr, bool complete) {
            unowned SList<ApiUser> users = (SList<ApiUser>) ptr;
            if (contacts_allowed) {
                parse_contacts (users);
            } else {
                if(waiting_users == null) {
                    waiting_users = new SList<ApiUser> ();
                }            
                foreach (unowned ApiUser user in users) {
                    waiting_users.append (user.dup (true));
                }
                check_waiting ();
            }
        }
        
        public void contact_done (void *ptr) {
            unowned ApiUser user = (ApiUser) ptr;
            get_contact (user.uid, false).load_from_api (user);
            if (user.is_friend && !threads.has_key (user.uid)) {
                add_thread (new SingleThread.with_contact (contacts[user.uid]));
            }
            save_contacts ();
        }
        
        private void update_thread (Fb.ApiThread thread) {
            var th = get_thread (thread.tid, thread.is_group, false);
            if (th.load_from_api (thread) && th.unread > 0) {
                new_message (th, th.last_message);
            }
            unread_count (th.id, th.unread);
        }
        
        public void parse_threads (SList<ApiThread> threads) {
            foreach (var thread in threads) {
                update_thread (thread);
            }
            save_threads ();
            loading_finished ();
        }
        
        public void threads_done (void *ptr) {
            unowned SList<Fb.ApiThread> threads = (SList<Fb.ApiThread>) ptr;
            if (threads_allowed) {
                parse_threads (threads);
            } else {
                if (waiting_threads == null) {
                    waiting_threads = new SList<ApiThread> ();
                }
                foreach (var thread in threads) {
                    waiting_threads.append (thread.dup (true));
                }
                check_waiting ();
            }
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
                    api.thread_func (msg.tid);
                } else if (last_time < time) {
                    threads [msg.tid].update_request_time = time + UPDATE_THREAD_INTERVAL;
                    Timeout.add ((uint)(UPDATE_THREAD_INTERVAL / 1000), () => {
                        api.thread_func (msg.tid);
                        return false;
                    });
                }
            }
        }
        
        private void check_waiting () {
            if (waiting_users != null && contacts_allowed) {
                parse_contacts (waiting_users);
                waiting_users = null;
            }
            if (waiting_threads != null && threads_allowed) {
                parse_threads (waiting_threads);
                waiting_threads = null;
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
                api.thread_func (id);
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
        
        public Data (Soup.Session ses, SocketClient cli, Api ap) {
            DATA_PATH = Main.data_path + "/data";
            CONTACTS_PATH = DATA_PATH + "/contacts";
            THREADS_PATH = DATA_PATH + "/threads";
            PICTURES_PATH = DATA_PATH + "/pictures";
            DESKTOP_PATH = DATA_PATH + "/desktop";
        
            session = ses;
            client = cli;
            api = ap;
            
            conv_data = new Ui.ConvData (DESKTOP_PATH, Main.APP_NAME);
            new_thread.connect (conv_data.add_thread);
            
            contacts = new HashMap<Id?, Contact> (my_id_hash, my_id_equal);
            threads = new HashMap<Id?, Thread> (my_id_hash, my_id_equal);
            
            make_dir (DATA_PATH);
            make_dir (PICTURES_PATH);
            make_dir (DESKTOP_PATH);
            
            load_from_disk.begin ();
            
            api.contacts.connect (contacts_done);
            api.contact.connect (contact_done);
            api.threads.connect (threads_done);
            api.thread.connect (thread_done);
            api.messages.connect (messages);
        }
    }

}
