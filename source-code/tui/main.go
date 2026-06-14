package main

import (
	"fmt"
	"os"
	"strings"

	tui "github.com/hackeros/steam-tui/src"

	tea "github.com/charmbracelet/bubbletea"
)

// ─────────────────────────────────────────────────────────────────
//  Constants
// ─────────────────────────────────────────────────────────────────

const cliPath = "/usr/bin/hackeros-steam"

// ─────────────────────────────────────────────────────────────────
//  appModel — outer wrapper that handles BatchOutputMsg
// ─────────────────────────────────────────────────────────────────

type appModel struct {
	inner tui.Model
}

func (a appModel) Init() tea.Cmd {
	return a.inner.Init()
}

func (a appModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tui.BatchOutputMsg:
		for _, line := range msg.Lines {
			if strings.TrimSpace(line) == "" {
				a.inner.AppendLog("")
				continue
			}
			a.inner.AppendLog(tui.ColorLine(line))
		}
		a.inner.Busy = false
		a.inner.State = tui.StateMenu
		if msg.Success {
			a.inner.AppendLog(tui.StyleLogSuccess.Render("  ✔  Done."))
		} else {
			a.inner.AppendLog(tui.StyleLogError.Render("  ✖  Command exited with error."))
		}
		a.inner.AppendLog("")
		return a, tui.CheckStatusCmd(cliPath)
	}

	updated, cmd := a.inner.Update(msg)
	a.inner = updated.(tui.Model)
	return a, cmd
}

func (a appModel) View() string {
	return a.inner.View()
}

// ─────────────────────────────────────────────────────────────────
//  main
// ─────────────────────────────────────────────────────────────────

func main() {
	app := appModel{inner: tui.NewModel(cliPath)}
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
