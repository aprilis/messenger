//Code from elementaryOS Switchboard plugin
//https://github.com/elementary/switchboard-plug-keyboard/blob/master/src/Shortcuts/Shortcut.vala

namespace Ui
{
	// stores a shortcut, converts to gsettings format and readable format
	// and checks for validity
	public class Shortcut : GLib.Object
	{
		private Gdk.ModifierType  modifiers;
		private uint              accel_key;
		
		private const string SEPARATOR = " · ";
		
		// constructors
		public Shortcut (uint key = 0, Gdk.ModifierType mod = (Gdk.ModifierType) 0)
		{
			accel_key = key;
			modifiers = mod;
		}
		
		public Shortcut.parse (string? str)
		{
			if (str == null)
			{
				accel_key = 0;
				modifiers = (Gdk.ModifierType) 0;
				return;
			}
			Gtk.accelerator_parse (str, out accel_key, out modifiers);
		}
		
		// converters
		public string to_gsettings ()
		{
			if (!valid())
				return "";
			return Gtk.accelerator_name (accel_key, modifiers);
        }
		
		public string to_readable  ()
		{
			if (!valid())
				return "Disabled";
				
			string tmp = "";
			
			if ((modifiers & Gdk.ModifierType.SHIFT_MASK) > 0)
			    tmp += "⇧" + SEPARATOR;
			if ((modifiers & Gdk.ModifierType.SUPER_MASK) > 0)
			    tmp += "⌘" + SEPARATOR;
			if ((modifiers & Gdk.ModifierType.CONTROL_MASK) > 0)
			    tmp += "Ctrl" + SEPARATOR;
			if ((modifiers & Gdk.ModifierType.MOD1_MASK) > 0)
			    tmp += "⎇" + SEPARATOR;
			if ((modifiers & Gdk.ModifierType.MOD2_MASK) > 0)
			    tmp += "Mod2" + SEPARATOR;
			if ((modifiers & Gdk.ModifierType.MOD3_MASK) > 0)
			    tmp += "Mod3" + SEPARATOR;
			if ((modifiers & Gdk.ModifierType.MOD4_MASK) > 0)
			    tmp += "Mod4" + SEPARATOR;

            switch (accel_key) {
            
                case Gdk.Key.Tab:   tmp += "↹"; break;
                case Gdk.Key.Up:    tmp += "↑"; break;
                case Gdk.Key.Down:  tmp += "↓"; break;
                case Gdk.Key.Left:  tmp += "←"; break;
                case Gdk.Key.Right: tmp += "→"; break;
                default:
                    tmp += Gtk.accelerator_get_label (accel_key, 0);
                    break;
            }
            
			return tmp;
        }
        
        public bool activated (Gdk.EventKey event) {
            return valid() && event.keyval == accel_key && ((event.state & modifiers) == modifiers);
        }
		
		public bool is_equal (Shortcut shortcut)
		{
			if (shortcut.modifiers == modifiers)
				if (shortcut.accel_key == accel_key)
					return true;
			return false;
		}
		
		// validator
		public bool valid()
		{
			if (accel_key == 0 || (modifiers == (Gdk.ModifierType) 0))
				return false;
            
			return true;
		}

	}
}