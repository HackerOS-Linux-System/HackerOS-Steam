using Gtk;
using GLib;

namespace HackerOSSteam {

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
        private Gtk.Button btn_export;
        private Gtk.Button btn_shell;
        private Gtk.Button btn_install;

        private const string CLI = "/usr/bin/hackeros-steam";

        public MainWindow (Gtk.Application app) {
            Object (application: app);
            this.set_title ("HackerOS Steam");
            this.set_default_size (960, 680);
            this.set_resizable (true);

            build_ui ();
            AppCSS.load ();
            check_status ();
        }

        // ─────────────────────────────────────────
        //  Layout assembly
        // ─────────────────────────────────────────

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

        // ─────────────────────────────────────────
        //  Header bar
        // ─────────────────────────────────────────

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

        // ─────────────────────────────────────────
        //  Sidebar
        // ─────────────────────────────────────────

        private Gtk.Widget build_sidebar () {
            var sidebar = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            sidebar.add_css_class ("sidebar");
            sidebar.set_size_request (210, -1);

            // ── STEAM ─────────────────────────────
            sidebar.append (section_label ("STEAM"));

            btn_run = new ActionButton ("Launch Steam", "media-playback-start-symbolic", "btn-primary");
            btn_run.clicked.connect (() => run_command ({"run"}));
            sidebar.append (btn_run);

            var btn_gamepad = new ActionButton ("Big Picture", "input-gaming-symbolic", "btn-secondary");
            btn_gamepad.clicked.connect (() => run_command ({"run", "-gamepadui"}));
            sidebar.append (btn_gamepad);

            var btn_deck = new ActionButton ("Steam Deck Mode", "input-gaming-symbolic", "btn-secondary");
            btn_deck.clicked.connect (() => run_command ({"run", "-steamos3", "-steamdeck"}));
            sidebar.append (btn_deck);

            // ── CONTAINER ─────────────────────────
            sidebar.append (section_sep ());
            sidebar.append (section_label ("CONTAINER"));

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

            // ── TOOLS ─────────────────────────────
            sidebar.append (section_sep ());
            sidebar.append (section_label ("TOOLS"));

            btn_export = new ActionButton ("Export to Desktop", "document-send-symbolic", "btn-ghost");
            btn_export.clicked.connect (() => run_command ({"export"}));
            sidebar.append (btn_export);

            btn_shell = new ActionButton ("Open Shell", "utilities-terminal-symbolic", "btn-ghost");
            btn_shell.clicked.connect (() => open_shell_terminal ());
            sidebar.append (btn_shell);

            btn_install = new ActionButton ("Install Packages", "list-add-symbolic", "btn-ghost");
            btn_install.clicked.connect (() => show_package_dialog ());
            sidebar.append (btn_install);

            var btn_logs = new ActionButton ("View Logs", "document-open-symbolic", "btn-ghost");
            btn_logs.clicked.connect (() => run_command ({"logs", "80"}));
            sidebar.append (btn_logs);

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

            // Spacer + version
            var spacer = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            spacer.set_vexpand (true);
            sidebar.append (spacer);

            var ver = new Gtk.Label ("v2.1.0");
            ver.add_css_class ("version-label");
            sidebar.append (ver);

            return sidebar;
        }

        private Gtk.Widget section_label (string text) {
            var lbl = new Gtk.Label (text);
            lbl.add_css_class ("section-label");
            lbl.set_xalign (0);
            return lbl;
        }

        private Gtk.Widget section_sep () {
            var sep = new Gtk.Separator (Gtk.Orientation.HORIZONTAL);
            sep.add_css_class ("section-sep");
            return sep;
        }

        // ─────────────────────────────────────────
        //  Terminal panel
        // ─────────────────────────────────────────

        private Gtk.Widget build_terminal_panel () {
            var panel = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
            panel.set_hexpand (true);
            panel.add_css_class ("terminal-panel");

            var pheader = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
            pheader.add_css_class ("terminal-header");

            foreach (string col in new string[]{"dot-red","dot-yellow","dot-green"}) {
                var dot = new Gtk.Label ("●");
                dot.add_css_class ("wm-dot");
                dot.add_css_class (col);
                pheader.append (dot);
            }

            var term_title = new Gtk.Label ("Output Log");
            term_title.add_css_class ("terminal-title");
            term_title.set_hexpand (true);
            term_title.set_xalign (0.5f);
            pheader.append (term_title);

            panel.append (pheader);

            terminal = new TerminalView ();
            panel.append (terminal.get_widget ());

            terminal.append ("  HackerOS Steam GUI  —  ready.", "header");
            terminal.append ("  Use the sidebar to manage your container.", "dim");

            return panel;
        }

        // ─────────────────────────────────────────
        //  Status bar
        // ─────────────────────────────────────────

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

        public void run_command (string[] args) {
            if (busy) return;
            set_busy (true);

            terminal.append ("", null);
            terminal.append ("  $ hackeros-steam " + string.joinv (" ", args), "info");
            terminal.append ("", null);

            var full_args = new string[args.length + 1];
            full_args[0] = CLI;
            for (int i = 0; i < args.length; i++) full_args[i + 1] = args[i];

            try {
                int stdout_fd, stderr_fd;
                Pid pid;

                Process.spawn_async_with_pipes (
                    null, full_args, null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null, out pid, null, out stdout_fd, out stderr_fd
                );

                var stdout_ch = new IOChannel.unix_new (stdout_fd);
                stdout_ch.add_watch (IOCondition.IN | IOCondition.HUP, (ch, cond) => {
                    if (IOCondition.HUP in cond) return false;
                    try {
                        string line; size_t _len;
                        if (ch.read_line (out line, out _len, null) == IOStatus.NORMAL && line != null)
                            terminal.append_raw (line.chomp ());
                    } catch {}
                    return true;
                });

                var stderr_ch = new IOChannel.unix_new (stderr_fd);
                stderr_ch.add_watch (IOCondition.IN | IOCondition.HUP, (ch, cond) => {
                    if (IOCondition.HUP in cond) return false;
                    try {
                        string line; size_t _len;
                        if (ch.read_line (out line, out _len, null) == IOStatus.NORMAL && line != null)
                            terminal.append (line.chomp (), "warning");
                    } catch {}
                    return true;
                });

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
            btn_export.set_sensitive (!b);
            btn_shell.set_sensitive  (!b);
            btn_install.set_sensitive (!b);
        }

        // ─────────────────────────────────────────
        //  Silent status check
        // ─────────────────────────────────────────

        public void check_status () {
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
                        string line; size_t _len;
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
            dialog.set_detail ("This will permanently delete the HackerOS-Steam container and all data inside it.");
            string[] buttons = {"Cancel", "Remove"};
            dialog.set_buttons (buttons);
            dialog.set_cancel_button (0);
            dialog.set_default_button (0);

            dialog.choose.begin (this, null, (obj, res) => {
                try {
                    int choice = dialog.choose.end (res);
                    if (choice == 1) run_command ({"--force", "remove"});
                } catch {}
            });
        }

        // ─────────────────────────────────────────
        //  Package install dialog
        // ─────────────────────────────────────────

        private void show_package_dialog () {
            var dlg = new PackageDialog (this);
            dlg.response.connect ((id) => {
                if (id == Gtk.ResponseType.OK) {
                    string pkgs = dlg.get_packages ();
                    if (pkgs.length > 0) {
                        string[] parts = pkgs.split (" ");
                        string[] cmd = new string[parts.length + 1];
                        cmd[0] = "install";
                        for (int i = 0; i < parts.length; i++) cmd[i + 1] = parts[i];
                        run_command (cmd);
                    }
                }
                dlg.destroy ();
            });
            dlg.present ();
        }

        // ─────────────────────────────────────────
        //  Open shell in an external terminal
        // ─────────────────────────────────────────

        private void open_shell_terminal () {
            // Try common terminal emulators in order of preference
            string[] terminals = {
                "kitty", "alacritty", "foot", "wezterm", "gnome-terminal", "xterm"
            };
            foreach (string term in terminals) {
                try {
                    string[] argv;
                    if (term == "gnome-terminal") {
                        argv = {term, "--", CLI, "shell"};
                    } else {
                        argv = {term, "-e", CLI + " shell"};
                    }
                    Process.spawn_async (null, argv, null, SpawnFlags.SEARCH_PATH, null, null);
                    terminal.append ("  → Opened shell in " + term, "info");
                    return;
                } catch {}
            }
            terminal.append ("  ✖  No supported terminal emulator found.", "error");
            terminal.append ("  Run manually: hackeros-steam shell", "dim");
        }
    }
}
