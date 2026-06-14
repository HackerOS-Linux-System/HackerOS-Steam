using Gtk;
using GLib;

namespace HackerOSSteam {

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
