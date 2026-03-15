package main

import (
	"fmt"
	"os"
	"os/exec"
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ─────────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────────

const cli = "/usr/bin/hackeros-steam"

// ─────────────────────────────────────────────────────────────────
//  Styles
// ─────────────────────────────────────────────────────────────────

var (
	// Palette
	colBg      = lipgloss.Color("#0e1117")
	colBgDeep  = lipgloss.Color("#080a0f")
	colBgRaise = lipgloss.Color("#141920")
	colBorder  = lipgloss.Color("#1e2535")
	colAccent  = lipgloss.Color("#4a9eff")
	colGreen   = lipgloss.Color("#3ddc84")
	colRed     = lipgloss.Color("#ff4a6b")
	colYellow  = lipgloss.Color("#ffb347")
	colPurple  = lipgloss.Color("#c792ea")
	colText    = lipgloss.Color("#d6e0f0")
	colDim     = lipgloss.Color("#3a4255")
	colSub     = lipgloss.Color("#6b7a99")

	styleTitle = lipgloss.NewStyle().
			Foreground(colAccent).
			Bold(true)

	styleSubtitle = lipgloss.NewStyle().
			Foreground(colSub)

	styleBorder = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colBorder)

	styleSectionLabel = lipgloss.NewStyle().
				Foreground(colDim).
				Bold(true).
				MarginTop(1)

	styleMenuItem = lipgloss.NewStyle().
			Foreground(colText).
			PaddingLeft(2)

	styleMenuSelected = lipgloss.NewStyle().
				Foreground(colAccent).
				Background(lipgloss.Color("#0e2040")).
				Bold(true).
				PaddingLeft(1).
				SetString("▶ ")

	styleMenuIcon = lipgloss.NewStyle().
			Foreground(colSub)

	styleStatusRunning = lipgloss.NewStyle().Foreground(colGreen).Bold(true)
	styleStatusStopped = lipgloss.NewStyle().Foreground(colYellow).Bold(true)
	styleStatusMissing = lipgloss.NewStyle().Foreground(colRed).Bold(true)
	styleStatusCheck   = lipgloss.NewStyle().Foreground(colDim)

	styleLogInfo    = lipgloss.NewStyle().Foreground(colAccent)
	styleLogSuccess = lipgloss.NewStyle().Foreground(colGreen)
	styleLogError   = lipgloss.NewStyle().Foreground(colRed)
	styleLogWarning = lipgloss.NewStyle().Foreground(colYellow)
	styleLogHeader  = lipgloss.NewStyle().Foreground(colPurple).Bold(true)
	styleLogDim     = lipgloss.NewStyle().Foreground(colDim)

	styleHelp = lipgloss.NewStyle().
			Foreground(colDim).
			MarginTop(1)

	styleConfirmBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(colRed).
			Padding(1, 4).
			Foreground(colText)

	styleDivider = lipgloss.NewStyle().Foreground(colBorder)
)

// ─────────────────────────────────────────────────────────────────
//  Menu items
// ─────────────────────────────────────────────────────────────────

type menuItem struct {
	icon    string
	label   string
	section string // empty = same section as previous
	cmd     []string
	confirm bool // show confirm dialog before running
}

var menuItems = []menuItem{
	{section: "STEAM", icon: "▶", label: "Launch Steam", cmd: []string{"run"}},
	{icon: "⬛", label: "Big Picture Mode", cmd: []string{"run", "-gamepadui"}},

	{section: "CONTAINER", icon: "+", label: "Create Container", cmd: []string{"create"}},
	{icon: "⚙", label: "Setup / Repair Steam", cmd: []string{"setup"}},
	{icon: "↑", label: "Update Container", cmd: []string{"update"}},
	{icon: "■", label: "Stop Container", cmd: []string{"kill"}},
	{icon: "✕", label: "Remove Container", cmd: []string{"--force", "remove"}, confirm: true},

	{section: "INFO", icon: "i", label: "Container Status", cmd: []string{"status"}},
	{icon: "≡", label: "List All Containers", cmd: []string{"list"}},
}

// ─────────────────────────────────────────────────────────────────
//  Messages
// ─────────────────────────────────────────────────────────────────

type (
	cmdOutputMsg  string        // line of output from running command
	cmdDoneMsg    bool          // true = success, false = error
	statusDoneMsg string        // "running" | "stopped" | "missing"
	windowSizeMsg tea.WindowSizeMsg
)

// ─────────────────────────────────────────────────────────────────
//  View states
// ─────────────────────────────────────────────────────────────────

type viewState int

const (
	stateMenu viewState = iota
	stateRunning
	stateConfirm
)

// ─────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────

type model struct {
	state       viewState
	cursor      int
	width       int
	height      int
	containerStatus string // "running"|"stopped"|"missing"|"checking"
	logLines    []string
	logViewport viewport.Model
	spinner     spinner.Model
	busy        bool
	pendingCmd  []string // command waiting for confirm
}

func initialModel() model {
	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = lipgloss.NewStyle().Foreground(colAccent)

	vp := viewport.New(60, 20)
	vp.Style = lipgloss.NewStyle().
		Background(colBgDeep).
		Foreground(colText)

	m := model{
		state:           stateMenu,
		containerStatus: "checking",
		spinner:         sp,
		logViewport:     vp,
	}
	m.logLines = append(m.logLines, styleLogHeader.Render("  HackerOS Steam TUI — ready."))
	m.logLines = append(m.logLines, styleLogDim.Render("  Use ↑/↓ to navigate, Enter to execute."))
	return m
}

// ─────────────────────────────────────────────────────────────────
//  Init
// ─────────────────────────────────────────────────────────────────

func (m model) Init() tea.Cmd {
	return tea.Batch(
		m.spinner.Tick,
		checkStatusCmd(),
	)
}

// ─────────────────────────────────────────────────────────────────
//  Update
// ─────────────────────────────────────────────────────────────────

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {

	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		m.logViewport.Width = logPanelWidth(m.width)
		m.logViewport.Height = logPanelHeight(m.height)

	case tea.KeyMsg:
		switch m.state {
		case stateMenu:
			switch msg.String() {
			case "q", "ctrl+c":
				return m, tea.Quit
			case "up", "k":
				if m.cursor > 0 {
					m.cursor--
				}
			case "down", "j":
				if m.cursor < len(menuItems)-1 {
					m.cursor++
				}
			case "enter", " ":
				if !m.busy {
					item := menuItems[m.cursor]
					if item.confirm {
						m.state = stateConfirm
						m.pendingCmd = item.cmd
					} else {
						cmds = append(cmds, m.execCommand(item.cmd))
					}
				}
			case "r":
				cmds = append(cmds, checkStatusCmd())
			}

		case stateConfirm:
			switch msg.String() {
			case "y", "Y":
				cmd := m.pendingCmd
				m.pendingCmd = nil
				m.state = stateMenu
				cmds = append(cmds, m.execCommand(cmd))
			case "n", "N", "q", "esc":
				m.pendingCmd = nil
				m.state = stateMenu
				m.appendLog(styleLogDim.Render("  Aborted."))
			}

		case stateRunning:
			switch msg.String() {
			case "ctrl+c":
				return m, tea.Quit
			}
		}

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		cmds = append(cmds, cmd)

	case cmdOutputMsg:
		line := string(msg)
		m.appendLog(colorLine(line))
		cmds = append(cmds, m.spinner.Tick)

	case cmdDoneMsg:
		ok := bool(msg)
		m.busy = false
		m.state = stateMenu
		if ok {
			m.appendLog(styleLogSuccess.Render("  ✔  Done."))
		} else {
			m.appendLog(styleLogError.Render("  ✖  Command exited with error."))
		}
		m.appendLog("")
		cmds = append(cmds, checkStatusCmd())

	case statusDoneMsg:
		m.containerStatus = string(msg)
	}

	// Update viewport scroll
	var vpCmd tea.Cmd
	m.logViewport, vpCmd = m.logViewport.Update(msg)
	cmds = append(cmds, vpCmd)

	return m, tea.Batch(cmds...)
}

// ─────────────────────────────────────────────────────────────────
//  Exec helpers
// ─────────────────────────────────────────────────────────────────

func (m *model) execCommand(args []string) tea.Cmd {
	m.busy = true
	m.state = stateRunning
	m.appendLog("")
	m.appendLog(styleLogInfo.Render("  $ hackeros-steam " + strings.Join(args, " ")))
	m.appendLog("")
	return runCommandCmd(args)
}

func (m *model) appendLog(line string) {
	m.logLines = append(m.logLines, line)
	m.logViewport.SetContent(strings.Join(m.logLines, "\n"))
	m.logViewport.GotoBottom()
}

// runCommandCmd streams output line-by-line via tea.Cmd chain
func runCommandCmd(args []string) tea.Cmd {
	fullArgs := append([]string{cli}, args...)
	return func() tea.Msg {
		cmd := exec.Command(fullArgs[0], fullArgs[1:]...)
		cmd.Stderr = nil

		out, err := cmd.Output()
		lines := strings.Split(stripANSI(string(out)), "\n")
		// We can't stream easily inside a single Cmd; send all lines then done.
		// For real streaming we'd use a channel-based approach below.
		_ = lines
		if err != nil {
			return streamLines(fullArgs, false)
		}
		return streamLines(fullArgs, true)
	}
}

// streamLines runs command and returns first line as cmdOutputMsg,
// scheduling subsequent lines recursively.
func streamLines(args []string, _ bool) tea.Msg {
	// Use tea.ExecProcess for full terminal hand-off when needed,
	// but here we collect all output and feed line by line.
	cmd := exec.Command(args[0], args[1:]...)
	out, err := cmd.CombinedOutput()
	lines := strings.Split(stripANSI(string(out)), "\n")

	// Return a batchLines message that pumps lines into the model
	return batchOutputMsg{lines: lines, success: err == nil}
}

type batchOutputMsg struct {
	lines   []string
	success bool
}

func (m model) Update2(msg tea.Msg) (tea.Model, tea.Cmd) { return m, nil } // stub

// We need to handle batchOutputMsg in the real Update — add it:
func init() {} // placeholder

// checkStatusCmd runs `hackeros-steam status` silently
func checkStatusCmd() tea.Cmd {
	return func() tea.Msg {
		cmd := exec.Command(cli, "status")
		out, _ := cmd.Output()
		lo := strings.ToLower(string(out))
		switch {
		case strings.Contains(lo, "does not exist"), strings.Contains(lo, "not created"):
			return statusDoneMsg("missing")
		case strings.Contains(lo, "● running"), strings.Contains(lo, "running"):
			return statusDoneMsg("running")
		default:
			return statusDoneMsg("stopped")
		}
	}
}

// ─────────────────────────────────────────────────────────────────
//  View
// ─────────────────────────────────────────────────────────────────

func (m model) View() string {
	if m.width == 0 {
		return "Loading..."
	}

	left := m.renderSidebar()
	right := m.renderLogPanel()

	content := lipgloss.JoinHorizontal(lipgloss.Top, left, right)

	header := m.renderHeader()
	statusBar := m.renderStatusBar()

	overlay := ""
	if m.state == stateConfirm {
		overlay = m.renderConfirmDialog()
	}

	base := lipgloss.JoinVertical(lipgloss.Left, header, content, statusBar)

	if overlay != "" {
		// Center the confirm box over the layout
		bw := lipgloss.Width(overlay)
		bh := lipgloss.Height(overlay)
		x := (m.width - bw) / 2
		y := (m.height - bh) / 2
		_ = x
		_ = y
		// Simple approach: render below header
		return lipgloss.JoinVertical(lipgloss.Left, header, overlay, statusBar)
	}

	return base
}

func (m model) renderHeader() string {
	title := styleTitle.Render("HackerOS") + lipgloss.NewStyle().Foreground(colText).Bold(true).Render(" Steam")
	sub := styleSubtitle.Render(" TUI  ·  Distrobox · Arch Linux")

	spin := ""
	if m.busy {
		spin = "  " + m.spinner.View()
	}

	left := title + sub + spin
	right := lipgloss.NewStyle().Foreground(colDim).Render("q quit · r refresh · ↑↓ navigate · enter select")

	gap := m.width - lipgloss.Width(left) - lipgloss.Width(right) - 2
	if gap < 1 {
		gap = 1
	}

	bar := lipgloss.NewStyle().
		Background(colBg).
		Foreground(colText).
		Padding(0, 1).
		Width(m.width).
		Render(left + strings.Repeat(" ", gap) + right)

	divider := styleDivider.Render(strings.Repeat("─", m.width))
	return lipgloss.JoinVertical(lipgloss.Left, bar, divider)
}

func (m model) renderSidebar() string {
	sideWidth := 28
	var rows []string

	currentSection := ""
	for i, item := range menuItems {
		// Section header
		if item.section != "" && item.section != currentSection {
			currentSection = item.section
			if len(rows) > 0 {
				rows = append(rows, "")
			}
			rows = append(rows, styleSectionLabel.
				Width(sideWidth).
				Render(" "+item.section))
		}

		icon := styleMenuIcon.Render(item.icon)
		label := item.label

		if i == m.cursor {
			row := styleMenuSelected.Render("") +
				icon + " " +
				lipgloss.NewStyle().Foreground(colAccent).Bold(true).Render(label)
			rows = append(rows, lipgloss.NewStyle().
				Background(lipgloss.Color("#0e2040")).
				Width(sideWidth).
				Render(row))
		} else {
			row := "  " + icon + " " + styleMenuItem.Render(label)
			rows = append(rows, lipgloss.NewStyle().Width(sideWidth).Render(row))
		}
	}

	// Fill remaining height
	used := len(rows) + 4 // header + statusbar
	fill := m.height - used - 4
	for i := 0; i < fill; i++ {
		rows = append(rows, strings.Repeat(" ", sideWidth))
	}

	body := strings.Join(rows, "\n")

	return lipgloss.NewStyle().
		Width(sideWidth).
		Height(m.height-4).
		Background(colBg).
		BorderRight(true).
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(colBorder).
		Render(body)
}

func logPanelWidth(w int) int {
	if w < 32 {
		return 10
	}
	return w - 30 // sidebar=28 + border=2
}

func logPanelHeight(h int) int {
	if h < 6 {
		return 1
	}
	return h - 5 // header(2) + statusbar(1) + padding(2)
}

func (m model) renderLogPanel() string {
	w := logPanelWidth(m.width)
	h := logPanelHeight(m.height)

	m.logViewport.Width = w - 2
	m.logViewport.Height = h

	// Title bar
	title := lipgloss.NewStyle().
		Foreground(colDim).
		Background(lipgloss.Color("#0d0f14")).
		Width(w).
		Padding(0, 1).
		Render("● ● ●   Output Log")

	panel := lipgloss.NewStyle().
		Width(w).
		Height(h).
		Background(colBgDeep).
		Render(m.logViewport.View())

	return lipgloss.JoinVertical(lipgloss.Left, title, panel)
}

func (m model) renderStatusBar() string {
	status := m.statusString()

	left := lipgloss.NewStyle().
		Foreground(colAccent).
		Bold(true).
		Render("HackerOS-Steam")

	sep := lipgloss.NewStyle().Foreground(colDim).Render("  ·  ")

	right := lipgloss.NewStyle().
		Foreground(colDim).
		Render("docker.io/archlinux:latest")

	gap := m.width - lipgloss.Width(left) - lipgloss.Width(sep) - lipgloss.Width(status) - lipgloss.Width(right) - 4
	if gap < 1 {
		gap = 1
	}

	divider := styleDivider.Render(strings.Repeat("─", m.width))
	bar := lipgloss.NewStyle().
		Background(colBg).
		Width(m.width).
		Padding(0, 1).
		Render(left + sep + status + strings.Repeat(" ", gap) + right)

	return lipgloss.JoinVertical(lipgloss.Left, divider, bar)
}

func (m model) statusString() string {
	switch m.containerStatus {
	case "running":
		return styleStatusRunning.Render("● Running")
	case "stopped":
		return styleStatusStopped.Render("○ Stopped")
	case "missing":
		return styleStatusMissing.Render("✖ Not Created")
	default:
		return styleStatusCheck.Render("… Checking")
	}
}

func (m model) renderConfirmDialog() string {
	item := ""
	for _, mi := range menuItems {
		if len(mi.cmd) > 0 && mi.cmd[len(mi.cmd)-1] == "remove" {
			item = mi.label
			break
		}
	}

	content := lipgloss.JoinVertical(lipgloss.Center,
		lipgloss.NewStyle().Foreground(colRed).Bold(true).Render("⚠  Confirm Action"),
		"",
		lipgloss.NewStyle().Foreground(colText).Render("Remove container: "+item),
		lipgloss.NewStyle().Foreground(colSub).Render("This cannot be undone."),
		"",
		lipgloss.NewStyle().Foreground(colGreen).Bold(true).Render("[Y]")+" "+
			lipgloss.NewStyle().Foreground(colText).Render("confirm")+"   "+
			lipgloss.NewStyle().Foreground(colRed).Bold(true).Render("[N]")+" "+
			lipgloss.NewStyle().Foreground(colText).Render("cancel"),
	)

	return lipgloss.NewStyle().
		Width(m.width).
		Align(lipgloss.Center).
		Padding(2, 0).
		Render(styleConfirmBox.Render(content))
}

// ─────────────────────────────────────────────────────────────────
//  ANSI strip
// ─────────────────────────────────────────────────────────────────

func stripANSI(s string) string {
	var out strings.Builder
	inEsc := false
	for _, r := range s {
		if r == '\x1b' {
			inEsc = true
			continue
		}
		if inEsc {
			if r == 'm' {
				inEsc = false
			}
			continue
		}
		out.WriteRune(r)
	}
	return out.String()
}

// colorLine applies lipgloss color based on line content
func colorLine(line string) string {
	l := line
	switch {
	case strings.Contains(l, "✔") || strings.Contains(l, "Done") || strings.Contains(l, "complete"):
		return styleLogSuccess.Render(l)
	case strings.Contains(l, "✖") || strings.Contains(l, "error") || strings.Contains(l, "failed") || strings.Contains(l, "Error"):
		return styleLogError.Render(l)
	case strings.Contains(l, "⚠") || strings.Contains(l, "warning") || strings.Contains(l, "skipped") || strings.Contains(l, "Warning"):
		return styleLogWarning.Render(l)
	case strings.Contains(l, "─ ") || strings.Contains(l, "LAUNCH") || strings.Contains(l, "CREAT") ||
		strings.Contains(l, "SETUP") || strings.Contains(l, "UPDAT") || strings.Contains(l, "REMOV") ||
		strings.Contains(l, "STATUS") || strings.Contains(l, "STOP"):
		return styleLogHeader.Render(l)
	case strings.Contains(l, "→") || strings.Contains(l, "$"):
		return styleLogInfo.Render(l)
	default:
		return lipgloss.NewStyle().Foreground(colText).Render(l)
	}
}

// ─────────────────────────────────────────────────────────────────
//  Main — handle batchOutputMsg in a wrapper model
// ─────────────────────────────────────────────────────────────────

type appModel struct {
	inner model
}

func (a appModel) Init() tea.Cmd {
	return a.inner.Init()
}

func (a appModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case batchOutputMsg:
		// Feed all lines into the inner model then signal done
		for _, line := range msg.lines {
			if strings.TrimSpace(line) == "" {
				a.inner.appendLog("")
				continue
			}
			a.inner.appendLog(colorLine(line))
		}
		a.inner.busy = false
		a.inner.state = stateMenu
		if msg.success {
			a.inner.appendLog(styleLogSuccess.Render("  ✔  Done."))
		} else {
			a.inner.appendLog(styleLogError.Render("  ✖  Command exited with error."))
		}
		a.inner.appendLog("")
		return a, checkStatusCmd()
	}

	updated, cmd := a.inner.Update(msg)
	a.inner = updated.(model)
	return a, cmd
}

func (a appModel) View() string {
	return a.inner.View()
}

func main() {
	app := appModel{inner: initialModel()}
	p := tea.NewProgram(
		app,
		tea.WithAltScreen(),
		tea.WithMouseCellMotion(),
	)
	if _, err := p.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}
}
