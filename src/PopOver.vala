using GLib;
using Gtk;
using Granite.Widgets;

public class Ui.PopOver : CompositedWindow {

    protected int arrow_offset { get; set; default = 0; }
    protected const int ARROW_WIDTH = 20;
    protected const int ARROW_HEIGHT = 10;
    protected const int BORDER_RADIUS = 10;
    protected const int BORDER_WIDTH = 1;
    protected const int SHADOW_SIZE = 20;

    protected Granite.Drawing.BufferSurface? main_buffer = null;

    private bool dont_close = false;
    
    
    public Requisition size {
        get {
            var req = get_requisition ();
            return { req.width, req.height - ARROW_HEIGHT };
        }
    }
     
    private bool button_release (Gdk.EventButton event) {
        close ();
        return false;
    }
    
    private bool key_release (Gdk.EventKey event) {
        if (Gdk.keyval_name (event.keyval) == "Escape") {
            close ();
        }
        return false;
    }
    
    private bool focus_out (Gdk.EventFocus event) {
        close ();
        return false;
    }
    
    //Code from Granite.Widgets.PopOver
    protected void cairo_popover (Cairo.Context cr, double x, double y, double width, double height, double border_radius) {
        var arrow_offset = (width - ARROW_WIDTH) / 2 + this.arrow_offset + x;
        var arrow_up = false;
        // The top half
        if (arrow_up) {
            cr.arc (x + border_radius, y + ARROW_HEIGHT + border_radius, border_radius, Math.PI, Math.PI * 1.5);
            cr.line_to (arrow_offset, y + ARROW_HEIGHT);
            cr.rel_line_to (ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
            cr.rel_line_to (ARROW_WIDTH / 2.0, ARROW_HEIGHT);
            cr.arc (x + width - border_radius, y + ARROW_HEIGHT + border_radius, border_radius, Math.PI * 1.5, Math.PI * 2.0);
        } else {
            cr.arc (x + border_radius, y + border_radius, border_radius, Math.PI, Math.PI * 1.5);
            cr.arc (x + width - border_radius, y + border_radius, border_radius, Math.PI * 1.5, Math.PI * 2.0);
        }

        // The bottom half
        if (arrow_up) {
            cr.arc (x + width - border_radius, y + height - border_radius, border_radius, 0, Math.PI * 0.5);
            cr.arc (x + border_radius, y + height - border_radius, border_radius, Math.PI * 0.5, Math.PI);
        } else {
            cr.arc (x + width - border_radius, y + height - ARROW_HEIGHT - border_radius, border_radius, 0, Math.PI * 0.5);
            cr.line_to (arrow_offset + ARROW_WIDTH, y + height - ARROW_HEIGHT);
            cr.rel_line_to (-ARROW_WIDTH / 2.0, ARROW_HEIGHT);
            cr.rel_line_to (-ARROW_WIDTH / 2.0, -ARROW_HEIGHT);
            cr.arc (x + border_radius, y + height - ARROW_HEIGHT - border_radius, border_radius, Math.PI * 0.5, Math.PI);
        }
        cr.close_path ();
    } 
    
    //Code from Granite.Widgets.PopOver
    void compute_shadow (int w, int h) {
          main_buffer = new Granite.Drawing.BufferSurface (w, h);
  
          // Shadow first
          cairo_popover (main_buffer.context, SHADOW_SIZE + BORDER_WIDTH / 2.0, SHADOW_SIZE + BORDER_WIDTH / 2.0,
                         w - SHADOW_SIZE * 2 - BORDER_WIDTH, h - SHADOW_SIZE - BORDER_WIDTH, BORDER_RADIUS);
          main_buffer.context.set_source_rgba (0.0, 0.0, 0.0, 0.4);
          main_buffer.context.fill_preserve ();
          main_buffer.exponential_blur (SHADOW_SIZE / 2 - 1); // rough approximation
  
          // Background
          main_buffer.context.set_source_rgba (1, 1, 1, 1);
          main_buffer.context.set_operator (Cairo.Operator.CLEAR);
          main_buffer.context.fill_preserve ();
  
          // Outer border
          main_buffer.context.set_operator (Cairo.Operator.SOURCE);
          main_buffer.context.set_line_width (BORDER_WIDTH);
          main_buffer.context.set_source_rgba (0.5, 0.5, 0.5, 0.5);
          main_buffer.context.stroke_preserve ();
      }
        
    public new void close (bool force = false) {
        if (force || !dont_close) {
            FocusGrabber.ungrab ();
            hide ();
        }
    }
    
    public void activate () {
        dont_close = true;
        show_all ();
        FocusGrabber.grab (get_window (), false, true);
        Timeout.add (200, () => {
            dont_close = false;
            return false;
        });
    }
    
    public PopOver () {
        type_hint = Gdk.WindowTypeHint.DOCK;
        skip_taskbar_hint = true;
        skip_pager_hint = true;
        set_keep_above (true);
        stick ();
        
        button_release_event.connect (button_release);
        key_release_event.connect (key_release);
        focus_out_event.connect (focus_out);
        size_allocate.connect(on_size_allocate);
        notify ["arrow-offset"].connect ((s, p) => {
            compute_shadow (old_w, old_h);
        });
    }
    
    //Code from Granite.Widgets.PopOver
    int old_w = 0;
    int old_h = 0;
    void on_size_allocate(Gtk.Allocation alloc)
    {
        int w = get_allocated_width();
        int h = get_allocated_height();
        if(old_w == w && old_h == h)
            return;

        compute_shadow (w, h);

        old_w = w;
        old_h = h;
    }
    
    //Code from Granite.Widgets.PopOver
    public override bool draw (Cairo.Context cr) {
        cr.new_path ();
        cr.append_path (main_buffer.context.copy_path ());
        cr.clip ();
        cr.set_source_rgba (1, 1, 1, 1);
        cr.paint ();
        var ret = base.draw (cr);
        cr.reset_clip ();
        cr.set_source_surface (main_buffer.surface, 0, 0);
        cr.paint ();
        return ret;
    }
    
    public new void move (int x, int y) {
        var w = width_request, h = height_request, cx = x + w / 2, cy = y + h / 2;
        Gdk.Rectangle rect;
        screen.get_monitor_geometry (screen.get_monitor_at_point (cx, cy), out rect);
        var offset = 0.clamp (rect.x - x, rect.x + rect.width - x - w);
        arrow_offset = -offset;
        base.move (x + offset, y);
    }
}

