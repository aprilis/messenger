using Gtk;
using GLib;

namespace Ui {

    public class Screen : Object {
    
        public signal void change_screen (string name);
    
        public string title { get; protected set; }
        
        public string name { get; protected set; }
        
        public Widget widget { get; protected set; }
        
        public virtual void show () { }
        
        public virtual void hide () { }
        
        public virtual void network_error () { }
        
        public virtual void auth_error () { }
        
        public virtual void network_ok () { }
        
        public virtual void cowardly_user () { }

        public virtual void other_error () { }
    
    }

}
