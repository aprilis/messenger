using GLib;
using Gdk;

namespace Fb {

    public abstract class Thread : Object {
    
        public abstract bool is_group { get; }
    
        public signal void photo_updated ();
        public signal void photo_changed ();
        
        public signal void name_updated ();
        public signal void name_changed ();
    
        public string last_message { get; set; }

        public string message_sender { get; set; }
        
        public int unread { get; set; default = 0; }

        public int64 mute_until { get; set; default = 0; }
        
        public int64 update_time { get; set; default = 0; }
        
        public bool is_loaded { get; private set; default = false; }
        
        public int64 id { get; protected set; }
         
        public abstract Pixbuf photo { get; }
        
        public abstract string name { get; }
        
        public abstract string participants_list { get; }

        public abstract string notification_text { owned get; }
        
        public int64 update_request_time { get; set; default = 0; }

        private Utils.DelayedOps when_ready;

        public Thread () {
            when_ready = new Utils.DelayedOps ();
            if (photo != null) {
                when_ready.release ();
            } else {
                photo_updated.connect (() => {
                    if (photo != null) {
                        when_ready.release ();
                    }
                });
            }
        }
    
        public virtual bool load_from_api (Fb.ApiThread thread) {
            id = thread.tid;
            mute_until = thread.mute_until;
            if (update_time < thread.update_time) {
                update_time = thread.update_time;
                last_message = thread.last_message;
                message_sender = thread.message_sender;
                unread = thread.unread;
                is_loaded = true;
                return true;
            } else {
                is_loaded = true;
                return false;
            }
        }
        
        public virtual void load_from_json (Json.Node node) {
            var object = node.get_object ();
            id = object.get_int_member ("id");
            last_message = object.get_string_member ("last_message");
            unread = (int) object.get_int_member ("unread");
            mute_until = (int) object.get_int_member ("mute_until");
            update_time = object.get_int_member ("update_time");
            is_loaded = true;
        }
        
        public virtual void to_json_specific (Json.Builder builder) {
        }
        
        public void to_json (Json.Builder builder) {
            builder.begin_object ();
            
            builder.set_member_name ("id");
            builder.add_int_value (id);
            
            builder.set_member_name ("last_message");
            builder.add_string_value (last_message);
            
            builder.set_member_name ("unread");
            builder.add_int_value (unread);
            
            builder.set_member_name ("mute_until");
            builder.add_int_value (mute_until);

            builder.set_member_name ("is_group");
            builder.add_boolean_value (is_group);
            
            builder.set_member_name ("update_time");
            builder.add_int_value (update_time);
            
            to_json_specific (builder);
            
            builder.end_object ();
        }
        
        public Pixbuf get_icon (int size, bool line = false) {  
            return Utils.make_icon (photo, size, line);
        }

        public void do_when_ready (owned Utils.Operation op) {
            when_ready.add ((owned) op);
        }
    }

}
