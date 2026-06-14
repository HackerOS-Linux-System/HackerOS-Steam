using Gtk;
using GLib;

namespace HackerOSSteam {

    // ─────────────────────────────────────────────
    //  Action button
    // ─────────────────────────────────────────────
    public class ActionButton : Gtk.Button {
        public ActionButton (string label, string icon_name, string css_class) {
            Object ();
            var box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            box.set_halign (Gtk.Align.CENTER);

            var icon = new Gtk.Image.from_icon_name (icon_name);
            icon.set_pixel_size (16);
            box.append (icon);

            var lbl = new Gtk.Label (label);
            lbl.set_xalign (0.5f);
            box.append (lbl);

            this.set_child (box);
            this.add_css_class (css_class);
            this.add_css_class ("action-btn");
        }
    }

    // ─────────────────────────────────────────────
    //  Status badge (dot + text label)
    // ─────────────────────────────────────────────
    public class StatusBadge : Gtk.Box {
        private Gtk.Label dot_label;
        private Gtk.Label text_label;

        public StatusBadge () {
            Object (orientation: Gtk.Orientation.HORIZONTAL, spacing: 6);
            this.set_halign (Gtk.Align.CENTER);
            this.set_valign (Gtk.Align.CENTER);

            dot_label = new Gtk.Label ("●");
            dot_label.add_css_class ("status-dot");

            text_label = new Gtk.Label ("Checking...");
            text_label.add_css_class ("status-text");

            this.append (dot_label);
            this.append (text_label);
        }

        public void set_status (string state) {
            dot_label.remove_css_class ("dot-running");
            dot_label.remove_css_class ("dot-stopped");
            dot_label.remove_css_class ("dot-missing");
            dot_label.remove_css_class ("dot-checking");

            switch (state) {
                case "running":
                    dot_label.add_css_class ("dot-running");
                    text_label.set_text ("Running");
                    break;
                case "stopped":
                    dot_label.add_css_class ("dot-stopped");
                    text_label.set_text ("Stopped");
                    break;
                case "missing":
                    dot_label.add_css_class ("dot-missing");
                    text_label.set_text ("Not Created");
                    break;
                default:
                    dot_label.add_css_class ("dot-checking");
                    text_label.set_text ("Checking...");
                    break;
            }
        }
    }

    // ─────────────────────────────────────────────
    //  Package install dialog
    //  Lets the user type extra pacman packages to
    //  install into the container without using CLI.
    // ─────────────────────────────────────────────
    public class PackageDialog : Gtk.Dialog {
        private Gtk.Entry entry;

        public PackageDialog (Gtk.Window parent) {
            Object (
                title: "Install Packages",
                transient_for: parent,
                modal: true
            );
            this.add_button ("Cancel", Gtk.ResponseType.CANCEL);
            this.add_button ("Install", Gtk.ResponseType.OK);
            this.set_default_response (Gtk.ResponseType.OK);

            var content = this.get_content_area ();
            content.set_spacing (12);
            content.set_margin_top (16);
            content.set_margin_bottom (16);
            content.set_margin_start (16);
            content.set_margin_end (16);

            var lbl = new Gtk.Label ("Package names (space-separated):");
            lbl.set_xalign (0);
            content.append (lbl);

            entry = new Gtk.Entry ();
            entry.set_placeholder_text ("e.g. mangohud lib32-mangohud");
            entry.set_activates_default (true);
            content.append (entry);
        }

        public string get_packages () {
            return entry.get_text ().strip ();
        }
    }
}
