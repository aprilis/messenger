using GLib;
using Gdk;

namespace Fb {

    public class Contact : Object {
    
        public signal void photo_changed ();
        
        public signal void name_changed ();
    
        private string photo_csum;

        private string download_photo_request = null;
        
        public Pixbuf photo { get; private set; }
            
        public string name { get; private set; }
        
        public int64 id { get; private set; }
        
        public bool is_friend { get; set; }
        
        public bool is_loaded { get; private set; default = false; }
        
        public bool is_present { get; set; default = false; }
        
        public void download_photo (int64 priority) {
            if (download_photo_request != null) {
                var req = download_photo_request;
                download_photo_request = null;
                try {
                    var data = App.instance ().data;
                    data.download_photo (req, priority, id);
                } catch (Error e) {
                    warning ("Error: %s\n", e.message);
                }
            }
        }

        public void photo_downloaded (Pixbuf downloaded) {
            var data = App.instance ().data;
            photo = downloaded;
            photo_changed ();
        }
        
        private async void load_photo_from_disk () {
            photo = yield App.instance ().data.load_photo (id);
            if (photo == null) {
                photo_csum = null;
                App.instance ().query_contact (id);
            }
        }
        
        public void to_json (Json.Builder builder) {
            builder.begin_object ();
            
            builder.set_member_name ("name");
            builder.add_string_value (name);
            
            builder.set_member_name ("id");
            builder.add_int_value (id);
            
            builder.set_member_name ("is_friend");
            builder.add_boolean_value (is_friend);
            
            builder.set_member_name ("photo_csum");
            builder.add_string_value (photo_csum);
            
            builder.end_object ();
        }
        
        public Contact (int64 fid) {
            id = fid;
        }
        
        public Contact.from_api (ApiUser user) {
            load_from_api (user);
        }
        
        public Contact.from_disk (Json.Node node) {
            var object = node.get_object();
            name = object.get_string_member("name");
            id = object.get_int_member("id");
            is_friend = object.get_boolean_member("is_friend");
            photo_csum = object.get_string_member("photo_csum");
            load_photo_from_disk ();
            is_loaded = true;
        }
        
        public void load_from_api (ApiUser user) {        
            id = user.uid;
            is_friend = user.is_friend;
            if (user.name != null && name != user.name) {
                name = user.name;
                name_changed ();
            }
            if (user.csum != null && photo_csum != user.csum) {
                photo_csum = user.csum;
                download_photo_request = user.icon;
            }
            is_loaded = true;
        }
    }

}
