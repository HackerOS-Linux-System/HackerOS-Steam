using Gtk;
using GLib;

namespace HackerOSSteam {
    public class MainWindow : Gtk.ApplicationWindow {
        private Gtk.Button launch_button;
        private Gtk.Button update_button;
        private Gtk.ProgressBar progress_bar;
        private Gtk.Label status_label;
        private Pid update_pid;

        public MainWindow(Gtk.Application app) {
            Object(application: app);

            this.title = "HackerOS Steam";
            this.default_width = 400;
            this.default_height = 200;
            this.border_width = 10;

            var box = new Gtk.Box(Gtk.Orientation.VERTICAL, 10);
            this.add(box);

            launch_button = new Gtk.Button.with_label("Uruchom Steam");
            launch_button.clicked.connect(on_launch_clicked);
            box.pack_start(launch_button, true, true, 0);

            update_button = new Gtk.Button.with_label("Zaktualizuj Kontener");
            update_button.clicked.connect(on_update_clicked);
            box.pack_start(update_button, true, true, 0);

            progress_bar = new Gtk.ProgressBar();
            progress_bar.set_visible(false);
            box.pack_start(progress_bar, true, true, 0);

            status_label = new Gtk.Label("Status: Gotowy");
            box.pack_start(status_label, true, true, 0);
        }

        private void on_launch_clicked() {
            status_label.set_text("Status: Uruchamianie Steam...");
            try {
                string[] argv = {"~/.hackeros/HackerOS-Steam/container/hackerosteam-container", "run"};
                Process.spawn_async(GLib.Environment.get_home_dir(), argv, null, SpawnFlags.SEARCH_PATH, null, null);
                status_label.set_text("Status: Steam uruchomiony!");
            } catch (Error e) {
                status_label.set_text("Błąd: " + e.message);
            }
        }

        private void on_update_clicked() {
            update_button.sensitive = false;
            progress_bar.set_visible(true);
            progress_bar.set_fraction(0.0);
            status_label.set_text("Status: Aktualizacja w toku...");

            try {
                string[] argv = {"~/.hackeros/HackerOS-Steam/container/hackerosteam-container", "update"};
                int stdin_fd, stdout_fd, stderr_fd;
                Process.spawn_async_with_pipes(
                    GLib.Environment.get_home_dir(),
                    argv,
                    null,
                    SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD,
                    null,
                    out update_pid,
                    out stdin_fd,
                    out stdout_fd,
                    out stderr_fd
                );

                // Monitoruj output dla postępu
                var stdout_channel = new IOChannel.unix_new(stdout_fd);
                stdout_channel.add_watch(IOCondition.IN | IOCondition.HUP, on_update_output);

                // Monitoruj stderr
                var stderr_channel = new IOChannel.unix_new(stderr_fd);
                stderr_channel.add_watch(IOCondition.IN | IOCondition.HUP, on_update_error);

                ChildWatch.add(update_pid, on_update_finished);
            } catch (Error e) {
                status_label.set_text("Błąd: " + e.message);
                reset_ui();
            }
        }

        private bool on_update_output(IOChannel channel, IOCondition condition) {
            if ((condition & IOCondition.HUP) == IOCondition.HUP) {
                return false;
            }

            string line;
            try {
                channel.read_line(out line, null, null);
                // Parsuj postęp, zakładając format "Progress: XX%" z outputu Rust
                if (line.contains("Progress:")) {
                    var parts = line.split(":");
                    if (parts.length > 1) {
                        double progress = double.parse(parts[1].strip().replace("%", "")) / 100.0;
                        progress_bar.set_fraction(progress.clamp(0.0, 1.0));
                    }
                }
                print(line); // Loguj do konsoli
            } catch (Error e) {
                warning(e.message);
            }
            return true;
        }

        private bool on_update_error(IOChannel channel, IOCondition condition) {
            if ((condition & IOCondition.HUP) == IOCondition.HUP) {
                return false;
            }

            string line;
            try {
                channel.read_line(out line, null, null);
                warning("Błąd aktualizacji: %s", line);
            } catch (Error e) {
                warning(e.message);
            }
            return true;
        }

        private void on_update_finished(Pid pid, int status) {
            Process.close_pid(pid);
            if (status == 0) {
                status_label.set_text("Status: Aktualizacja ukończona!");
            } else {
                status_label.set_text("Status: Aktualizacja nieudana!");
            }
            reset_ui();
        }

        private void reset_ui() {
            update_button.sensitive = true;
            progress_bar.set_visible(false);
        }
    }

    public class Application : Gtk.Application {
        public Application() {
            Object(application_id: "org.hackeros.steam.gui", flags: ApplicationFlags.FLAGS_NONE);
        }

        protected override void activate() {
            var window = new MainWindow(this);
            window.show_all();
        }
    }
}

public int main(string[] args) {
    return new HackerOSSteam.Application().run(args);
}
