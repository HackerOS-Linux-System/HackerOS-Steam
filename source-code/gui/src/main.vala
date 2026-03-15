using Gtk;
using GLib;

namespace HackerOSSteam {

    // ─────────────────────────────────────────────
    //  Terminal output buffer
    //  NOTE: Composition instead of inheriting GtkScrolledWindow.
    //  Vala subclassing GtkScrolledWindow causes incomplete-type
    //  errors in the generated C because the GTK C headers keep
    //  GtkScrolledWindowClass opaque.  We own a ScrolledWindow
    //  internally and expose it via get_widget().
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

        // Return the real GTK widget to embed in layouts
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

            // Auto-scroll to bottom
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

    // ─────────────────────────────────────────────
    //  Action button widget
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
    //  Status badge
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
    //  Main Window
    // ─────────────────────────────────────────────
    public class MainWindow : Gtk.ApplicationWindow {
        private TerminalView terminal;
        private StatusBadge  status_badge;
        private Gtk.Spinner  spinner;
        private bool         busy = false;

        private Gtk.Button btn_run;
        private Gtk.Button btn_create;
        private Gtk.Button btn_setup;
        private Gtk.Button btn_update;
        private Gtk.Button btn_stop;
        private Gtk.Button btn_remove;

        private const string CLI = "/usr/bin/hackeros-steam";

        public MainWindow (Gtk.Application app) {
            Object (application: app);
            this.set_title ("HackerOS Steam");
            this.set_default_size (900, 640);
            this.set_resizable (true);

            build_ui ();
            load_css ();
            check_status ();
        }

        private void build_ui () {
            var root = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);

            root.append (build_header ());

            var content = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            content.set_vexpand (true);
            content.append (build_sidebar ());

            var sep = new Gtk.Separator (Gtk.Orientation.VERTICAL);
            sep.add_css_class ("sidebar-sep");
            content.append (sep);

            content.append (build_terminal_panel ());
            root.append (content);
            root.append (build_statusbar ());

            this.set_child (root);
        }

        private Gtk.Widget build_header () {
            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
            bar.add_css_class ("app-header");
            bar.set_hexpand (true);

            var title_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
            title_box.set_hexpand (true);

            var logo = new Gtk.Image.from_icon_name ("utilities-terminal-symbolic");
            logo.set_pixel_size (28);
            logo.add_css_class ("header-logo");

            var vbox  = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            var title = new Gtk.Label ("HackerOS Steam");
            title.add_css_class ("app-title");
            title.set_xalign (0);
            var sub = new Gtk.Label ("Distrobox · Arch Linux · Container Manager");
            sub.add_css_class ("app-subtitle");
            sub.set_xalign (0);
            vbox.append (title);
            vbox.append (sub);

            title_box.append (logo);
            title_box.append (vbox);
            bar.append (title_box);

            spinner = new Gtk.Spinner ();
            spinner.add_css_class ("header-spinner");
            bar.append (spinner);

            return bar;
        }

        private Gtk.Widget build_sidebar () {
            var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            sidebar.add_css_class ("sidebar");
            sidebar.set_size_request (200, -1);

            // STEAM section
            var sec1 = new Gtk.Label ("STEAM");
            sec1.add_css_class ("section-label");
            sec1.set_xalign (0);
            sidebar.append (sec1);

            btn_run = new ActionButton ("Launch Steam", "media-playback-start-symbolic", "btn-primary");
            btn_run.clicked.connect (() => run_command ({"run"}));
            sidebar.append (btn_run);

            var btn_gamepad = new ActionButton ("Big Picture", "input-gaming-symbolic", "btn-secondary");
            btn_gamepad.clicked.connect (() => run_command ({"run", "-gamepadui"}));
            sidebar.append (btn_gamepad);

            // CONTAINER section
            var sep1 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep1.add_css_class ("section-sep");
            sidebar.append (sep1);

            var sec2 = new Gtk.Label ("CONTAINER");
            sec2.add_css_class ("section-label");
            sec2.set_xalign (0);
            sidebar.append (sec2);

            btn_create = new ActionButton ("Create", "list-add-symbolic", "btn-secondary");
            btn_create.clicked.connect (() => run_command ({"create"}));
            sidebar.append (btn_create);

            btn_setup = new ActionButton ("Setup / Repair", "emblem-system-symbolic", "btn-secondary");
            btn_setup.clicked.connect (() => run_command ({"setup"}));
            sidebar.append (btn_setup);

            btn_update = new ActionButton ("Update", "software-update-available-symbolic", "btn-secondary");
            btn_update.clicked.connect (() => run_command ({"update"}));
            sidebar.append (btn_update);

            btn_stop = new ActionButton ("Stop", "media-playback-stop-symbolic", "btn-warning");
            btn_stop.clicked.connect (() => run_command ({"kill"}));
            sidebar.append (btn_stop);

            btn_remove = new ActionButton ("Remove", "user-trash-symbolic", "btn-danger");
            btn_remove.clicked.connect (() => confirm_remove ());
            sidebar.append (btn_remove);

            // TOOLS section
            var sep2 = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep2.add_css_class ("section-sep");
            sidebar.append (sep2);

            var sec3 = new Gtk.Label ("TOOLS");
            sec3.add_css_class ("section-label");
            sec3.set_xalign (0);
            sidebar.append (sec3);

            var btn_status = new ActionButton ("Refresh Status", "view-refresh-symbolic", "btn-ghost");
            btn_status.clicked.connect (() => {
                terminal.clear ();
                run_command ({"status"});
                check_status ();
            });
            sidebar.append (btn_status);

            var btn_clear = new ActionButton ("Clear Log", "edit-clear-symbolic", "btn-ghost");
            btn_clear.clicked.connect (() => terminal.clear ());
            sidebar.append (btn_clear);

            var spacer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            spacer.set_vexpand (true);
            sidebar.append (spacer);

            var ver = new Gtk.Label ("v2.0.0");
            ver.add_css_class ("version-label");
            sidebar.append (ver);

            return sidebar;
        }

        private Gtk.Widget build_terminal_panel () {
            var panel = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            panel.set_hexpand (true);
            panel.add_css_class ("terminal-panel");

            // macOS-style window chrome dots
            var pheader = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            pheader.add_css_class ("terminal-header");

            var dot_r = new Gtk.Label ("●");
            dot_r.add_css_class ("wm-dot");
            dot_r.add_css_class ("dot-red");
            var dot_y = new Gtk.Label ("●");
            dot_y.add_css_class ("wm-dot");
            dot_y.add_css_class ("dot-yellow");
            var dot_g = new Gtk.Label ("●");
            dot_g.add_css_class ("wm-dot");
            dot_g.add_css_class ("dot-green");

            pheader.append (dot_r);
            pheader.append (dot_y);
            pheader.append (dot_g);

            var term_title = new Gtk.Label ("Output Log");
            term_title.add_css_class ("terminal-title");
            term_title.set_hexpand (true);
            term_title.set_xalign (0.5f);
            pheader.append (term_title);

            panel.append (pheader);

            // TerminalView uses composition — embed via get_widget()
            terminal = new TerminalView ();
            panel.append (terminal.get_widget ());

            terminal.append ("  HackerOS Steam GUI  —  ready.", "header");
            terminal.append ("  Use the sidebar to manage your container.", "dim");

            return panel;
        }

        private Gtk.Widget build_statusbar () {
            var bar = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 16);
            bar.add_css_class ("status-bar");

            var cont_label = new Gtk.Label ("HackerOS-Steam");
            cont_label.add_css_class ("status-container-name");
            bar.append (cont_label);

            var sep = new Gtk.Label ("·");
            sep.add_css_class ("status-sep");
            bar.append (sep);

            status_badge = new StatusBadge ();
            bar.append (status_badge);

            var spacer = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 0);
            spacer.set_hexpand (true);
            bar.append (spacer);

            var img_label = new Gtk.Label ("docker.io/archlinux:latest");
            img_label.add_css_class ("status-image");
            bar.append (img_label);

            return bar;
        }

        // ─────────────────────────────────────────
        //  Run CLI command asynchronously
        // ─────────────────────────────────────────
        private void run_command (string[] args) {
            if (busy) return;
            set_busy (true);

            terminal.append ("", null);
            terminal.append ("  $ hackeros-steam " + string.joinv (" ", args), "info");
            terminal.append ("", null);

            // Build full argv: CLI binary + subcommand args
            var full_args = new string[args.length + 1];
            full_args[0] = CLI;
            for (int i = 0; i < args.length; i++) {
                full_args[i + 1] = args[i];
            }

            try {
                int stdout_fd, stderr_fd;
                Pid pid;

                Process.spawn_async_with_pipes (
                    null,
                    full_args,
                    null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null,
                    out pid,
                    null,
                    out stdout_fd,
                    out stderr_fd
                );

                // stdout → terminal (colored)
                var stdout_ch = new IOChannel.unix_new (stdout_fd);
                stdout_ch.add_watch (IOCondition.IN | IOCondition.HUP, (ch, cond) => {
                    if (IOCondition.HUP in cond) return false;
                    try {
                        string line;
                        size_t _len;
                        if (ch.read_line (out line, out _len, null) == IOStatus.NORMAL && line != null)
                            terminal.append_raw (line.chomp ());
                    } catch {}
                    return true;
                });

                // stderr → terminal (yellow)
                var stderr_ch = new IOChannel.unix_new (stderr_fd);
                stderr_ch.add_watch (IOCondition.IN | IOCondition.HUP, (ch, cond) => {
                    if (IOCondition.HUP in cond) return false;
                    try {
                        string line;
                        size_t _len;
                        if (ch.read_line (out line, out _len, null) == IOStatus.NORMAL && line != null)
                            terminal.append (line.chomp (), "warning");
                    } catch {}
                    return true;
                });

                // Process exit
                ChildWatch.add (pid, (p, exit_status) => {
                    Process.close_pid (p);
                    bool ok = Process.check_wait_status (exit_status);
                    terminal.append ("", null);
                    terminal.append (ok ? "  ✔  Done." : "  ✖  Command exited with error.",
                                     ok ? "success"   : "error");
                    terminal.append ("", null);
                    set_busy (false);
                    check_status ();
                });

            } catch (Error e) {
                terminal.append ("  ✖  Failed to launch: " + e.message, "error");
                set_busy (false);
            }
        }

        private void set_busy (bool b) {
            busy = b;
            if (b) spinner.start (); else spinner.stop ();
            btn_run.set_sensitive    (!b);
            btn_create.set_sensitive (!b);
            btn_setup.set_sensitive  (!b);
            btn_update.set_sensitive (!b);
            btn_stop.set_sensitive   (!b);
            btn_remove.set_sensitive (!b);
        }

        // ─────────────────────────────────────────
        //  Silent status check
        // ─────────────────────────────────────────
        private void check_status () {
            status_badge.set_status ("checking");

            string[] argv = {CLI, "status"};
            try {
                int stdout_fd;
                Pid pid;
                string output = "";

                Process.spawn_async_with_pipes (
                    null, argv, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out pid, null, out stdout_fd, null
                );

                var ch = new IOChannel.unix_new (stdout_fd);
                ch.add_watch (IOCondition.IN | IOCondition.HUP, (channel, cond) => {
                    if (IOCondition.HUP in cond) return false;
                    try {
                        string line;
                        size_t _len;
                        if (channel.read_line (out line, out _len, null) == IOStatus.NORMAL)
                            output += line;
                    } catch {}
                    return true;
                });

                ChildWatch.add (pid, (p, _exit) => {
                    Process.close_pid (p);
                    string lo = output.down ();
                    if ("does not exist" in lo || "not created" in lo)
                        status_badge.set_status ("missing");
                    else if ("● running" in lo || "running" in lo)
                        status_badge.set_status ("running");
                    else
                        status_badge.set_status ("stopped");
                });
            } catch {
                status_badge.set_status ("missing");
            }
        }

        // ─────────────────────────────────────────
        //  Remove confirmation dialog
        // ─────────────────────────────────────────
        private void confirm_remove () {
            var dialog = new Gtk.AlertDialog ("Remove Container?");
            dialog.set_detail ("This will permanently delete the HackerOS-Steam container and all its data.");
            // Explicit cast to const string[] fixes the incompatible-pointer-types warning
            string[] buttons = {"Cancel", "Remove"};
            dialog.set_buttons (buttons);
            dialog.set_cancel_button (0);
            dialog.set_default_button (0);

            dialog.choose.begin (this, null, (obj, res) => {
                try {
                    int choice = dialog.choose.end (res);
                    if (choice == 1)
                        run_command ({"remove"});
                } catch {}
            });
        }

        // ─────────────────────────────────────────
        //  CSS
        // ─────────────────────────────────────────
        private void load_css () {
            var css = new Gtk.CssProvider ();
            css.load_from_string ("""
                @define-color bg-deep    #080a0f;
                @define-color bg-surface #0e1117;
                @define-color bg-raised  #141920;
                @define-color bg-hover   #1a2130;
                @define-color border-sub #1e2535;
                @define-color border-act #2a3a5c;
                @define-color accent     #4a9eff;
                @define-color accent-dim #1d3a6e;
                @define-color green      #3ddc84;
                @define-color red        #ff4a6b;
                @define-color yellow     #ffb347;
                @define-color purple     #c792ea;
                @define-color text-pri   #d6e0f0;
                @define-color text-sec   #6b7a99;
                @define-color text-dim   #3a4255;

                window {
                    background-color: @bg-deep;
                    color: @text-pri;
                }

                /* ── Header ── */
                .app-header {
                    background-color: @bg-surface;
                    border-bottom: 1px solid @border-sub;
                    padding: 14px 20px;
                    min-height: 60px;
                }
                .header-logo { color: @accent; opacity: 0.9; }
                .app-title {
                    font-family: 'Rajdhani', 'Exo 2', sans-serif;
                    font-size: 18px;
                    font-weight: 700;
                    color: @text-pri;
                    letter-spacing: 1px;
                }
                .app-subtitle {
                    font-size: 10px;
                    color: @text-sec;
                    letter-spacing: 0.5px;
                }
                .header-spinner { color: @accent; margin-left: 8px; }

                /* ── Sidebar ── */
                .sidebar {
                    background-color: @bg-surface;
                    padding: 12px 10px;
                    min-width: 200px;
                }
                .sidebar-sep { background-color: @border-sub; }
                .section-label {
                    font-size: 9px;
                    font-weight: 700;
                    color: @text-dim;
                    letter-spacing: 2px;
                    padding: 14px 8px 6px 8px;
                }
                .section-sep { background-color: @border-sub; margin: 6px 0; }
                .version-label { font-size: 10px; color: @text-dim; padding: 10px 0; }

                /* ── Action Buttons ── */
                .action-btn {
                    border-radius: 6px;
                    padding: 9px 14px;
                    margin: 2px 0;
                    font-size: 13px;
                    font-weight: 500;
                    border: 1px solid transparent;
                    transition: all 150ms ease;
                    box-shadow: none;
                }
                .btn-primary {
                    background: linear-gradient(135deg, #1a4a8a, #0e2d5a);
                    color: @accent;
                    border-color: @accent-dim;
                }
                .btn-primary:hover {
                    background: linear-gradient(135deg, #1e5299, #122f66);
                    border-color: @accent;
                }
                .btn-secondary {
                    background-color: @bg-raised;
                    color: @text-pri;
                    border-color: @border-sub;
                }
                .btn-secondary:hover {
                    background-color: @bg-hover;
                    border-color: @border-act;
                }
                .btn-warning {
                    background-color: #2a1f0a;
                    color: @yellow;
                    border-color: #3a2c0f;
                }
                .btn-warning:hover { background-color: #3a2c10; border-color: @yellow; }
                .btn-danger {
                    background-color: #2a0a0e;
                    color: @red;
                    border-color: #3a0f12;
                }
                .btn-danger:hover { background-color: #3a1015; border-color: @red; }
                .btn-ghost {
                    background-color: transparent;
                    color: @text-sec;
                    border-color: transparent;
                }
                .btn-ghost:hover {
                    background-color: @bg-raised;
                    color: @text-pri;
                    border-color: @border-sub;
                }
                button:disabled { opacity: 0.4; }

                /* ── Terminal panel ── */
                .terminal-panel { background-color: #0a0c10; }
                .terminal-header {
                    background-color: #0d0f14;
                    border-bottom: 1px solid @border-sub;
                    padding: 8px 14px;
                    min-height: 36px;
                }
                .terminal-title { font-size: 11px; color: @text-dim; letter-spacing: 1px; }
                .wm-dot { font-size: 11px; margin-right: 1px; }
                .dot-red    { color: #ff5f57; }
                .dot-yellow { color: #ffbd2e; }
                .dot-green  { color: #28ca41; }

                /* ── Status bar ── */
                .status-bar {
                    background-color: @bg-surface;
                    border-top: 1px solid @border-sub;
                    padding: 6px 16px;
                    min-height: 32px;
                }
                .status-container-name {
                    font-family: monospace;
                    font-size: 11px;
                    font-weight: 700;
                    color: @accent;
                    letter-spacing: 0.5px;
                }
                .status-sep  { color: @text-dim; font-size: 11px; }
                .status-image { font-family: monospace; font-size: 10px; color: @text-dim; }

                /* ── Status badge ── */
                .status-dot  { font-size: 10px; }
                .status-text { font-size: 11px; color: @text-sec; }
                .dot-running  { color: @green; }
                .dot-stopped  { color: @yellow; }
                .dot-missing  { color: @red; }
                .dot-checking { color: @text-dim; }
            """);

            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }
    }

    // ─────────────────────────────────────────────
    //  Application
    // ─────────────────────────────────────────────
    public class App : Gtk.Application {
        public App () {
            Object (
                application_id: "io.hackeros.steam",
                flags: ApplicationFlags.DEFAULT_FLAGS
            );
        }

        protected override void activate () {
            var win = new MainWindow (this);
            win.present ();
        }
    }

    public static int main (string[] args) {
        return new App ().run (args);
    }
}
