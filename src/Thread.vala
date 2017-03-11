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
        
        public int unread { get; set; default = 0; }
        
        public int64 update_time { get; set; default = 0; }
        
        public bool is_loaded { get; private set; default = false; }
        
        public int64 id { get; protected set; }
         
        public abstract Pixbuf photo { get; }
        
        public abstract string name { get; }
        
        public abstract string participants_list { get; }
        
        public int64 update_request_time { get; set; default = 0; }
    
        public virtual bool load_from_api (Fb.ApiThread thread) {
            id = thread.tid;
            if (update_time < thread.update_time) {
                update_time = thread.update_time;
                last_message = thread.last_message;
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
            
            builder.set_member_name ("is_group");
            builder.add_boolean_value (is_group);
            
            builder.set_member_name ("update_time");
            builder.add_int_value (update_time);
            
            to_json_specific (builder);
            
            builder.end_object ();
        }
        
        public Pixbuf get_icon (int size, bool line = false) {  
            Pixbuf pixbuf;
            if (photo == null) {
                pixbuf = new Pixbuf(Colorspace.RGB, true, 8, size, size);
                pixbuf.fill ((uint32)0xaaaaaaff);
            } else {
                pixbuf = photo;
            }
        
            var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, size, size);
            var context = new Cairo.Context (surface);
            var center = size * 0.5, radius = center * 0.95;
            
            context.arc (center, center, radius, 0, 2 * Math.PI);
            var scale = size / (double)pixbuf.width;
            context.scale (scale, scale);
            cairo_set_source_pixbuf (context, pixbuf, 0, 0);
            context.fill_preserve ();
            if (line) {
                context.scale (1 / scale, 1 / scale);
                context.set_source_rgba (0, 0, 0, 0.5);
                context.set_line_width (0.5);
                context.stroke ();
            }
            
            pixbuf = pixbuf_get_from_surface (surface, 0, 0, size, size);
            if (pixbuf == null) {
                warning ("Failed to create pixbuf");
                pixbuf = new Pixbuf(Colorspace.RGB, true, 8, size, size);
                pixbuf.fill ((uint32)0xaaaaaaff);
            }
            return pixbuf;
        }
    }

}
