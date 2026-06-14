using Gtk;
using GLib;

namespace HackerOSSteam {

    public class AppCSS : GLib.Object {

        public static void load () {
            var css = new Gtk.CssProvider ();
            css.load_from_string (CSS_DATA);
            Gtk.StyleContext.add_provider_for_display (
                Gdk.Display.get_default (),
                css,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );
        }

        private const string CSS_DATA = """
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
            .header-logo   { color: @accent; opacity: 0.9; }
            .app-title {
                font-family: 'Rajdhani', 'Exo 2', sans-serif;
                font-size: 18px;
                font-weight: 700;
                color: @text-pri;
                letter-spacing: 1px;
            }
            .app-subtitle  { font-size: 10px; color: @text-sec; letter-spacing: 0.5px; }
            .header-spinner { color: @accent; margin-left: 8px; }

            /* ── Sidebar ── */
            .sidebar {
                background-color: @bg-surface;
                padding: 12px 10px;
                min-width: 200px;
            }
            .sidebar-sep   { background-color: @border-sub; }
            .section-label {
                font-size: 9px;
                font-weight: 700;
                color: @text-dim;
                letter-spacing: 2px;
                padding: 14px 8px 6px 8px;
            }
            .section-sep   { background-color: @border-sub; margin: 6px 0; }
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
            .btn-danger:hover  { background-color: #3a1015; border-color: @red; }
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
            .terminal-panel    { background-color: #0a0c10; }
            .terminal-header {
                background-color: #0d0f14;
                border-bottom: 1px solid @border-sub;
                padding: 8px 14px;
                min-height: 36px;
            }
            .terminal-title { font-size: 11px; color: @text-dim; letter-spacing: 1px; }
            .wm-dot         { font-size: 11px; margin-right: 1px; }
            .dot-red        { color: #ff5f57; }
            .dot-yellow     { color: #ffbd2e; }
            .dot-green      { color: #28ca41; }

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
            .status-sep   { color: @text-dim; font-size: 11px; }
            .status-image { font-family: monospace; font-size: 10px; color: @text-dim; }

            /* ── Status badge ── */
            .status-dot   { font-size: 10px; }
            .status-text  { font-size: 11px; color: @text-sec; }
            .dot-running  { color: @green; }
            .dot-stopped  { color: @yellow; }
            .dot-missing  { color: @red; }
            .dot-checking { color: @text-dim; }
        """;
    }
}
