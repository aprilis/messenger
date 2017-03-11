using GLib;
using Gdk;
using Gee;

namespace Fb {

    public class GroupThread : Thread {
    
        public override bool is_group { get { return true; } }
        
        private Pixbuf _photo;
        
        private string _name = "";
        
        private string _participants_list = "";
        
        private string topic;
        
        private HashMap<Id?, Contact> participants;
        
        private void update_photo () {
            Pixbuf[] pixbufs = { };
            foreach (var contact in participants.values) {
                if (contact.photo != null) {
                    pixbufs += contact.photo;
                    if (pixbufs.length == 4) {
                        break;
                    }
                }
            }
            
            if (pixbufs.length == 0) {
                _photo = null;
            } else if (pixbufs.length == 1) {
                _photo = pixbufs [0];
            } else {
                var size = pixbufs [0].width, half = size / 2;
                _photo = new Pixbuf (Colorspace.RGB, true, 8, size, size);
                _photo.fill (0xffffffffu);
                switch (pixbufs.length) {
                case 2:
                    pixbufs[0].copy_area (0, 0, half, size, _photo, 0, 0);
                    pixbufs[1].copy_area (half, 0, half, size, _photo, half, 0);
                    break;
                case 3:
                    pixbufs[0].copy_area (0, 0, half, size, _photo, 0, 0);
                    var scaled = pixbufs[1].scale_simple (half, half, InterpType.BILINEAR);
                    scaled.copy_area (0, 0, half, half, _photo, half, 0);
                    scaled = pixbufs[2].scale_simple (half, half, InterpType.BILINEAR);
                    scaled.copy_area (0, 0, half, half, _photo, half, half);
                    break;
                case 4:
                    for (int i = 0; i < 4; i++) {
                        var scaled = pixbufs[i].scale_simple (half, half, InterpType.BILINEAR);
                        scaled.copy_area (0, 0, half, half, _photo, half * (i / 2), half * (i % 2));
                    }
                    break;
                }
                
            }
            
            photo_updated();
        }
        
        private void update_name () {
            if (topic != null) {
                _name = topic;
            } else {
                _name = "";
                int count = 0;
                
                foreach (var contact in participants.values) {
                    if (contact.name == null) {
                        continue;
                    }
                    count++;
                    if (count > 2 && participants.size > count + 1) {
                        _name = "%s and %d other users\n".printf(_name, participants.size - count + 1);
                        break;
                    }
                    if (count != 1) {
                        _name += ", ";
                    }
                    _name += contact.name;
                }
            }
            string[] names = { };
            foreach (var contact in participants.values) {
                if (contact.name != null) {
                    names += contact.name + ";";
                }
            }
            _participants_list = string.joinv (";", names);
            name_updated();
        }
        
        private void connect_signals (Contact contact) {
            contact.notify ["photo"].connect ((s, p) => {
                update_photo ();
            });
            contact.notify ["name"].connect ((s, p) => {
                update_name ();
            });
            contact.photo_changed.connect (() => {
                photo_changed ();
            });
            contact.name_changed.connect (() => {
                name_changed ();
            });            
        }
        
        public override bool load_from_api (Fb.ApiThread thread) {
            var result = base.load_from_api (thread);
            if (thread.topic != null && topic != thread.topic) {
                topic = thread.topic;
                update_name();
                name_changed ();
            }
            
            if (thread.users == null || thread.users.length () == 0) {
                return result;
            }
            
            int count = 0;
            bool equal = true;
            var data = App.instance ().data;
            foreach (var uid in thread.users) {
                if (uid in data.null_contacts) {
                    continue;
                }
                count++;
                if (!participants.has_key (uid)) {
                    equal = false;
                    break;
                }
            }
            if (equal && count == participants.size) {
                return result;
            }
            
            var new_participants = new HashMap<Id?, Contact> (my_id_hash, my_id_equal);
            foreach (var uid in thread.users) {
                var contact = data.get_contact (uid, true);
                new_participants.set (uid, contact);
                if (!participants.has_key (uid)) {
                    connect_signals (contact);
                }
            }
            
            participants = new_participants;
            update_name ();
            update_photo ();
            name_changed ();
            photo_changed ();
            return result;
        }
        
        public override void load_from_json (Json.Node node) {
            participants.clear ();    
            base.load_from_json (node);    
            var object = node.get_object ();
            if (object.has_member ("topic")) {
                topic = object.get_string_member ("topic");
            }
            
            var array = object.get_array_member ("participants");
            var data = App.instance ().data;
            foreach (var elem in array.get_elements()) {
                var uid = elem.get_int ();
                var contact = data.get_contact (uid, false);
                participants.set (uid, contact);
                connect_signals (contact);
            }
            
            update_name ();
            update_photo ();
        }
        
        public override void to_json_specific (Json.Builder builder) {
            if (topic != null) {
                builder.set_member_name ("topic");
                builder.add_string_value (topic);
            }
            
            builder.set_member_name ("participants");
            builder.begin_array ();
            foreach (var part in participants.values) {
                builder.add_int_value (part.id);
            }
            builder.end_array ();
        }
        
        public override Pixbuf photo {
            get { return _photo; }
        }
        
        public override string name {
            get { return _name; }
        }
        
        public override string participants_list {
            get { return _participants_list; }
        }
        
        public GroupThread (Id tid) {
            id = tid;
            participants = new HashMap<Id?, Contact> (my_id_hash, my_id_equal);
        }
        
    }

}
