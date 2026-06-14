using Gtk;
using GLib;

namespace HackerOSSteam {

    // ─────────────────────────────────────────────
    //  Terminal output buffer
    //  Composition instead of inheriting GtkScrolledWindow
    //  (opaque GtkScrolledWindowClass causes C errors in Vala).
    // ─────────────────────────────────────────────
    public class TerminalView : GLib.Object {
        private Gtk.ScrolledWindow scroll;
        private Gtk.TextView       text_view;
        private Gtk.TextBuffer     buffer;
        private Gtk.TextTag        tag_info;
        private Gtk.TextTag        tag_success;
        private Gtk.TextTag        tag_error;
        private Gtk.TextTag        tag_warning;
        private Gtk.TextTag        tag_header;
        private Gtk.TextTag        tag_dim;

        public TerminalView () {
            scroll = new Gtk.ScrolledWindow ();
            scroll.set_vexpand (true);
            scroll.set_hexpand (true);
            scroll.set_policy (Gtk.PolicyType.AUTOMATIC, Gtk.PolicyType.AUTOMATIC);

            text_view = new Gtk.TextView ();
            text_view.set_editable (false);
            text_view.set_cursor_visible (false);
            text_view.set_monospace (true);
            text_view.set_wrap_mode (Gtk.WrapMode.WORD_CHAR);
            text_view.set_left_margin (16);
            text_view.set_right_margin (16);
            text_view.set_top_margin (12);
            text_view.set_bottom_margin (12);

            var css = new Gtk.CssProvider ();
            css.load_from_string ("""
                textview {
                    background-color: #0a0c10;
                    color: #8892a4;
                    font-family: 'JetBrains Mono', 'Fira Code', 'Cascadia Code', monospace;
                    font-size: 12px;
                }
                textview text {
                    background-color: #0a0c10;
                }
            """);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            buffer = text_view.get_buffer ();
            tag_info    = buffer.create_tag ("info",    "foreground", "#4a9eff", null);
            tag_success = buffer.create_tag ("success", "foreground", "#3ddc84", null);
            tag_error   = buffer.create_tag ("error",   "foreground", "#ff4a6b", null);
            tag_warning = buffer.create_tag ("warning", "foreground", "#ffb347", null);
            tag_header  = buffer.create_tag ("header",  "foreground", "#c792ea", "weight", 700, null);
            tag_dim     = buffer.create_tag ("dim",     "foreground", "#3d4455", null);

            scroll.set_child (text_view);
        }

        public Gtk.Widget get_widget () {
            return scroll;
        }

        public void append (string line, string? style = null) {
            Gtk.TextIter end_iter;
            buffer.get_end_iter (out end_iter);

            Gtk.TextTag? tag = null;
            switch (style) {
                case "info":    tag = tag_info;    break;
                case "success": tag = tag_success; break;
                case "error":   tag = tag_error;   break;
                case "warning": tag = tag_warning; break;
                case "header":  tag = tag_header;  break;
                case "dim":     tag = tag_dim;     break;
            }

            if (tag != null) {
                buffer.insert_with_tags (ref end_iter, line + "\n", -1, tag);
            } else {
                buffer.insert (ref end_iter, line + "\n", -1);
            }

            var mark = buffer.get_mark ("insert");
            text_view.scroll_to_mark (mark, 0.0, true, 0.0, 1.0);
        }

        public void clear () {
            buffer.set_text ("", 0);
        }

        public void append_raw (string line) {
            string stripped = strip_ansi (line);
            if (stripped.strip () == "") return;

            string? style = null;
            if ("✔" in stripped || "ready" in stripped.down () || "complete" in stripped.down ()) {
                style = "success";
            } else if ("✖" in stripped || "error" in stripped.down () || "failed" in stripped.down ()) {
                style = "error";
            } else if ("⚠" in stripped || "warning" in stripped.down () || "skipped" in stripped.down ()) {
                style = "warning";
            } else if ("─ " in stripped || "LAUNCH" in stripped || "CREAT" in stripped ||
                       "SETUP" in stripped || "UPDAT" in stripped || "STOP" in stripped ||
                       "REMOV" in stripped || "STATUS" in stripped) {
                style = "header";
            } else if ("→" in stripped || "$" in stripped) {
                style = "info";
            } else if ("[" in stripped && "]" in stripped && "/" in stripped) {
                style = "dim";
            }

            append (stripped, style);
        }

        private string strip_ansi (string input) {
            try {
                var re = new Regex ("""\x1b\[[0-9;]*m""");
                return re.replace (input, -1, 0, "");
            } catch {
                return input;
            }
        }
    }
}
