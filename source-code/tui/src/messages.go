package tui

import (
	"os/exec"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
)

// ─────────────────────────────────────────────────────────────────
//  Tea messages
// ─────────────────────────────────────────────────────────────────

type (
	CmdDoneMsg    bool
	StatusDoneMsg string
)

// ─────────────────────────────────────────────────────────────────
//  Batch output (collected stdout of a finished subprocess)
// ─────────────────────────────────────────────────────────────────

type BatchOutputMsg struct {
	Lines   []string
	Success bool
}

// ─────────────────────────────────────────────────────────────────
//  Commands (tea.Cmd factories)
// ─────────────────────────────────────────────────────────────────

func RunCommandCmd(cliPath string, args []string) tea.Cmd {
	fullArgs := append([]string{cliPath}, args...)
	return func() tea.Msg {
		return streamLines(fullArgs)
	}
}

func streamLines(args []string) tea.Msg {
	cmd := exec.Command(args[0], args[1:]...)
	out, err := cmd.CombinedOutput()
	lines := strings.Split(StripANSI(string(out)), "\n")
	return BatchOutputMsg{Lines: lines, Success: err == nil}
}

func CheckStatusCmd(cliPath string) tea.Cmd {
	return func() tea.Msg {
		cmd := exec.Command(cliPath, "status")
		out, _ := cmd.Output()
		lo := strings.ToLower(string(out))
		switch {
		case strings.Contains(lo, "does not exist"), strings.Contains(lo, "not created"):
			return StatusDoneMsg("missing")
		case strings.Contains(lo, "● running"), strings.Contains(lo, "running"):
			return StatusDoneMsg("running")
		default:
			return StatusDoneMsg("stopped")
		}
	}
}
