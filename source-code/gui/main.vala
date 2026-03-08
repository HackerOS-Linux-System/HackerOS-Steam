using Gtk;

namespace HackerOSSteamGUI {

    public class Application : Gtk.Application {
        private TextView log_view;
        private CheckButton force_check;
        private Entry flags_entry;
        private Entry packages_entry;

        public Application () {
            Object (
                application_id: "com.hackeros.steam.gui",
                flags: ApplicationFlags.FLAGS_NONE
            );
        }

        protected override void activate () {
            var window = new Window (this);
            window.title = "HackerOS-Steam GUI";
            window.set_default_size (800, 600);

            var main_box = new Box (Orientation.VERTICAL, 10);
            main_box.margin_top = 10;
            main_box.margin_bottom = 10;
            main_box.margin_start = 10;
            main_box.margin_end = 10;
            window.set_child (main_box);

            var header_label = new Label ("<b>HackerOS-Steam: Steam Container Manager</b>");
            header_label.use_markup = true;
            main_box.append (header_label);

            var grid = new Grid ();
            grid.column_spacing = 10;
            grid.row_spacing = 10;
            main_box.append (grid);

            // Create
            var create_button = new Button.with_label ("Create");
            grid.attach (create_button, 0, 0);
            force_check = new CheckButton.with_label ("Force");
            grid.attach (force_check, 1, 0);
            create_button.clicked.connect (on_create_clicked);

            // Run
            var run_button = new Button.with_label ("Run");
            grid.attach (run_button, 0, 1);
            flags_entry = new Entry ();
            flags_entry.placeholder_text = "Flags (e.g., -gamepadui -steamos3)";
            grid.attach (flags_entry, 1, 1);
            run_button.clicked.connect (on_run_clicked);

            // Install
            var install_button = new Button.with_label ("Install");
            grid.attach (install_button, 0, 2);
            packages_entry = new Entry ();
            packages_entry.placeholder_text = "Packages (space-separated)";
            grid.attach (packages_entry, 1, 2);
            install_button.clicked.connect (on_install_clicked);

            // Update
            var update_button = new Button.with_label ("Update");
            grid.attach (update_button, 0, 3);
            update_button.clicked.connect (on_update_clicked);

            // Restart
            var restart_button = new Button.with_label ("Restart");
            grid.attach (restart_button, 0, 4);
            restart_button.clicked.connect (on_restart_clicked);

            // Kill
            var kill_button = new Button.with_label ("Kill");
            grid.attach (kill_button, 0, 5);
            kill_button.clicked.connect (on_kill_clicked);

            // Remove
            var remove_button = new Button.with_label ("Remove");
            grid.attach (remove_button, 0, 6);
            remove_button.clicked.connect (on_remove_clicked);

            // Status
            var status_button = new Button.with_label ("Status");
            grid.attach (status_button, 0, 7);
            status_button.clicked.connect (on_status_clicked);

            // List
            var list_button = new Button.with_label ("List");
            grid.attach (list_button, 0, 8);
            list_button.clicked.connect (on_list_clicked);

            // Clear Log
            var clear_button = new Button.with_label ("Clear Log");
            grid.attach (clear_button, 0, 9);
            clear_button.clicked.connect (on_clear_clicked);

            // Log view
            var scrolled = new ScrolledWindow ();
            log_view = new TextView ();
            log_view.editable = false;
            log_view.wrap_mode = WrapMode.WORD;
            scrolled.set_child (log_view);
            scrolled.vexpand = true;
            main_box.append (scrolled);

            window.present ();
        }

        private void append_log (string text) {
            var buffer = log_view.buffer;
            TextIter end_iter;
            buffer.get_end_iter (out end_iter);
            buffer.insert (ref end_iter, text + "\n", -1);
            log_view.scroll_to_iter (end_iter, 0.0, false, 0.0, 0.0);
        }

        private void run_sync_command (string args) {
            string cmd = "/usr/bin/HackerOS-Steam " + args;
            append_log ("Executing: " + cmd);

            string? std_out = null;
            string? std_err = null;
            int exit_status;

            try {
                Process.spawn_command_line_sync (cmd, out std_out, out std_err, out exit_status);
                if (std_out != null && std_out.length > 0) {
                    append_log (std_out);
                }
                if (std_err != null && std_err.length > 0) {
                    append_log ("Error: " + std_err);
                }
                append_log ("Exit status: " + exit_status.to_string ());
            } catch (SpawnError e) {
                append_log ("Failed to execute: " + e.message);
            }
        }

        private void run_async_command (string args) {
            string cmd = "/usr/bin/HackerOS-Steam " + args;
            append_log ("Launching asynchronously: " + cmd);

            try {
                Process.spawn_command_line_async (cmd);
                append_log ("Launched successfully.");
            } catch (SpawnError e) {
                append_log ("Failed to launch: " + e.message);
            }
        }

        private void on_create_clicked () {
            string args = "create";
            if (force_check.active) {
                args += " --force";
            }
            run_sync_command (args);
        }

        private void on_run_clicked () {
            string args = "run " + flags_entry.text.strip ();
            run_async_command (args);
        }

        private void on_install_clicked () {
            string pkgs = packages_entry.text.strip ();
            if (pkgs == "") {
                append_log ("No packages specified.");
                return;
            }
            run_sync_command ("install " + pkgs);
        }

        private void on_update_clicked () {
            run_sync_command ("update");
        }

        private void on_restart_clicked () {
            run_async_command ("restart");
        }

        private void on_kill_clicked () {
            run_sync_command ("kill");
        }

        private void on_remove_clicked () {
            run_sync_command ("remove");
        }

        private void on_status_clicked () {
            run_sync_command ("status");
        }

        private void on_list_clicked () {
            run_sync_command ("list");
        }

        private void on_clear_clicked () {
            log_view.buffer.text = "";
        }
    }
}

int main (string[] args) {
    return new HackerOSSteamGUI.Application ().run (args);
}
