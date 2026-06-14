package tui

// ─────────────────────────────────────────────────────────────────
//  Menu item definitions
// ─────────────────────────────────────────────────────────────────

type MenuItem struct {
	Icon    string
	Label   string
	Section string
	Cmd     []string
	Confirm bool
}

var MenuItems = []MenuItem{
	{Section: "STEAM", Icon: "▶", Label: "Launch Steam", Cmd: []string{"run"}},
	{Icon: "⬛", Label: "Big Picture Mode", Cmd: []string{"run", "-gamepadui"}},
	{Icon: "⬛", Label: "Steam Deck Mode", Cmd: []string{"run", "-steamos3", "-steamdeck"}},

	{Section: "CONTAINER", Icon: "+", Label: "Create Container", Cmd: []string{"create"}},
	{Icon: "⚙", Label: "Setup / Repair Steam", Cmd: []string{"setup"}},
	{Icon: "↑", Label: "Update Container", Cmd: []string{"update"}},
	{Icon: "■", Label: "Stop Container", Cmd: []string{"kill"}},
	{Icon: "✕", Label: "Remove Container", Cmd: []string{"--force", "remove"}, Confirm: true},

	{Section: "TOOLS", Icon: "↗", Label: "Export to Desktop", Cmd: []string{"export"}},
	{Icon: "⬜", Label: "Open Shell", Cmd: []string{"shell"}},
	{Icon: "≡", Label: "View Logs (50)", Cmd: []string{"logs", "50"}},

	{Section: "INFO", Icon: "i", Label: "Container Status", Cmd: []string{"status"}},
	{Icon: "≡", Label: "List All Containers", Cmd: []string{"list"}},
}
