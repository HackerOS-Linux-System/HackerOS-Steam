package tui

import (
	"strings"

	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/viewport"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

// ─────────────────────────────────────────────────────────────────
//  View states
// ─────────────────────────────────────────────────────────────────

type ViewState int

const (
	StateMenu ViewState = iota
	StateRunning
	StateConfirm
)

// ─────────────────────────────────────────────────────────────────
//  Model
// ─────────────────────────────────────────────────────────────────

type Model struct {
	CliPath         string
	State           ViewState
	Cursor          int
	Width           int
	Height          int
	ContainerStatus string
	LogLines        []string
	LogViewport     viewport.Model
	Spinner         spinner.Model
	Busy            bool
	PendingCmd      []string
}

func NewModel(cliPath string) Model {
	sp := spinner.New()
	sp.Spinner = spinner.Dot
	sp.Style = lipgloss.NewStyle().Foreground(ColAccent)

	vp := viewport.New(60, 20)
	vp.Style = lipgloss.NewStyle().
		Background(ColBgDeep).
		Foreground(ColText)

	m := Model{
		CliPath:         cliPath,
		State:           StateMenu,
		ContainerStatus: "checking",
		Spinner:         sp,
		LogViewport:     vp,
	}
	m.LogLines = append(m.LogLines, StyleLogHeader.Render("  HackerOS Steam TUI — ready."))
	m.LogLines = append(m.LogLines, StyleLogDim.Render("  Use ↑/↓ to navigate, Enter to execute."))
	return m
}

func (m Model) Init() tea.Cmd {
	return tea.Batch(m.Spinner.Tick, CheckStatusCmd(m.CliPath))
}

// ─────────────────────────────────────────────────────────────────
//  Helpers
// ─────────────────────────────────────────────────────────────────

func (m *Model) ExecCommand(args []string) tea.Cmd {
	m.Busy = true
	m.State = StateRunning
	m.AppendLog("")
	m.AppendLog(StyleLogInfo.Render("  $ hackeros-steam " + strings.Join(args, " ")))
	m.AppendLog("")
	return RunCommandCmd(m.CliPath, args)
}

func (m *Model) AppendLog(line string) {
	m.LogLines = append(m.LogLines, line)
	m.LogViewport.SetContent(strings.Join(m.LogLines, "\n"))
	m.LogViewport.GotoBottom()
}

// ─────────────────────────────────────────────────────────────────
//  Update
// ─────────────────────────────────────────────────────────────────

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	var cmds []tea.Cmd

	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.Width = msg.Width
		m.Height = msg.Height
		m.LogViewport.Width = LogPanelWidth(m.Width)
		m.LogViewport.Height = LogPanelHeight(m.Height)

	case tea.KeyMsg:
		switch m.State {
		case StateMenu:
			switch msg.String() {
			case "q", "ctrl+c":
				return m, tea.Quit
			case "up", "k":
				if m.Cursor > 0 {
					m.Cursor--
				}
			case "down", "j":
				if m.Cursor < len(MenuItems)-1 {
					m.Cursor++
				}
			case "enter", " ":
				if !m.Busy {
					item := MenuItems[m.Cursor]
					if item.Confirm {
						m.State = StateConfirm
						m.PendingCmd = item.Cmd
					} else {
						cmds = append(cmds, m.ExecCommand(item.Cmd))
					}
				}
			case "r":
				cmds = append(cmds, CheckStatusCmd(m.CliPath))
			}

		case StateConfirm:
			switch msg.String() {
			case "y", "Y":
				cmd := m.PendingCmd
				m.PendingCmd = nil
				m.State = StateMenu
				cmds = append(cmds, m.ExecCommand(cmd))
			case "n", "N", "q", "esc":
				m.PendingCmd = nil
				m.State = StateMenu
				m.AppendLog(StyleLogDim.Render("  Aborted."))
			}

		case StateRunning:
			if msg.String() == "ctrl+c" {
				return m, tea.Quit
			}
		}

	case spinner.TickMsg:
		var cmd tea.Cmd
		m.Spinner, cmd = m.Spinner.Update(msg)
		cmds = append(cmds, cmd)

	case CmdDoneMsg:
		m.Busy = false
		m.State = StateMenu
		if bool(msg) {
			m.AppendLog(StyleLogSuccess.Render("  ✔  Done."))
		} else {
			m.AppendLog(StyleLogError.Render("  ✖  Command exited with error."))
		}
		m.AppendLog("")
		cmds = append(cmds, CheckStatusCmd(m.CliPath))

	case StatusDoneMsg:
		m.ContainerStatus = string(msg)
	}

	var vpCmd tea.Cmd
	m.LogViewport, vpCmd = m.LogViewport.Update(msg)
	cmds = append(cmds, vpCmd)

	return m, tea.Batch(cmds...)
}
