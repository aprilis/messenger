using Gtk;
using Gdk;

namespace Ui { 
    
    public class FadeOutBin : Bin {

        private int border;

        public override bool draw (Cairo.Context cr) {
            var scale = get_scale_factor ();

            var w = get_allocated_width () * scale, h = get_allocated_height () * scale;
            var source = new Cairo.ImageSurface (Cairo.Format.A8, w, h);
            var cs = new Cairo.Context (source);
            cs.rectangle (0, border, w, h - border * 2);
            cs.set_source_rgba (1, 1, 1, 1);
            cs.fill ();
            
            var pattern = new Cairo.Pattern.linear (0, 0, 0, border);
            pattern.add_color_stop_rgba (1, 1, 1, 1, 1);
            pattern.add_color_stop_rgba (0, 1, 1, 1, 0);

            cs.rectangle (0, 0, w, border);
            cs.set_source (pattern);
            cs.fill ();

            pattern = new Cairo.Pattern.linear (0, h, 0, h - border);
            pattern.add_color_stop_rgba (1, 1, 1, 1, 1);
            pattern.add_color_stop_rgba (0, 1, 1, 1, 0);

            cs.rectangle (0, h - border, w, border);
            cs.set_source (pattern);
            cs.fill ();

            var surface = new Cairo.ImageSurface (Cairo.Format.ARGB32, w, h);
            surface.set_device_scale(scale, scale);
            var cx = new Cairo.Context (surface);
            var ret = base.draw (cx);
            cr.set_source_surface (surface, 0, 0);
            cr.mask_surface (source, 0, 0);
            return ret;
        }

        public FadeOutBin (int border_height) {
            border = border_height;
        }

    }

}