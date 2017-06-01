using GLib;
using Gdk;

namespace Fb {

    public class SingleThread : Thread {
    
        public override bool is_group { get { return false; } }
    
        private Contact _contact;
        
        public Contact contact {
            get { return _contact; }
            set {
                if (_contact != null) {
                    warning ("Contact %s already set\n", _contact.name);
                    return;
                }
            
                _contact = value;
                id = _contact.id;
                
                _contact.notify ["photo"].connect((s, p) => {
                    photo_updated();
                });
                _contact.notify ["name"].connect((s, p) => {
                    name_updated();
                });
                _contact.photo_changed.connect (() => { photo_changed(); });
                _contact.name_changed.connect (() => { name_changed(); });
                
                name_updated ();
                photo_updated ();
            }
        }
        
        public override bool load_from_api (Fb.ApiThread thread) {
            var result = base.load_from_api (thread);
            if (contact == null) {
                var data = App.instance ().data;
                contact = data.get_contact (id);
            }
            contact.download_photo (update_time);
            return result;
        }
        
        public override void load_from_json (Json.Node node) {
            base.load_from_json (node);
            if (contact == null) {
                var data = App.instance ().data;
                contact = data.get_contact (id);
            }
        }
        
        public SingleThread (Id fid) {
            var data = App.instance ().data;
            contact = data.get_contact (fid);
        }
        
        public SingleThread.with_contact (Contact cnt) {
            contact = cnt;   
        }
        
        public override Pixbuf photo {
            get {
                return contact == null ? null : contact.photo;
            }
        }
        
        public override string name {
            get {
                return contact == null ? "" : contact.name;
            }
        }
        
        public override string participants_list {
            get {
                return contact == null ? "" : contact.name;
            }
        }
               
    }

}
