package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

var (
	styleTitle    = lipgloss.NewStyle().Bold(true).Foreground(lipgloss.Color("#00FF00")).Margin(1, 0, 1, 0)
	styleSelected = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFFF00")).Bold(true)
	styleNormal   = lipgloss.NewStyle().Foreground(lipgloss.Color("#FFFFFF"))
	styleStatus   = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF00FF")).Italic(true)
	styleProgress = lipgloss.NewStyle().Width(50).Background(lipgloss.Color("#00FF00")).Foreground(lipgloss.Color("#000000"))
	styleError    = lipgloss.NewStyle().Foreground(lipgloss.Color("#FF0000"))
)

type model struct {
	choices     []string
	cursor      int
	status      string
	updating    bool
	progress    float64
	quit        bool
	containerBin string
}

func initialModel() model {
	home, _ := os.UserHomeDir()
	binPath := filepath.Join(home, ".hackeros", "HackerOS-Steam", "container", "hackerosteam-container")

	return model{
		choices: []string{
			"Uruchom zwykły Steam",
			"Uruchom Gamescope Session Steam",
			"Aktualizuj kontener",
			"Kill (wyłącz na siłę)",
			"Restart (zresetuj kontener)",
			"Remove (usuń kontener)",
			"Create (utwórz kontener)",
			"Wyjdź",
		},
		cursor:       0,
		status:       "Wybierz opcję...",
		containerBin: binPath,
	}
}

func (m model) Init() tea.Cmd {
	return nil
}

func (m model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "ctrl+c", "q":
			m.quit = true
			return m, tea.Quit
		case "up":
			if m.cursor > 0 {
				m.cursor--
			}
		case "down":
			if m.cursor < len(m.choices)-1 {
				m.cursor++
			}
		case "enter":
			return m, m.executeChoice()
		}
	case progressMsg:
		m.progress = msg.progress
		if m.progress >= 1.0 {
			m.updating = false
			m.status = "Aktualizacja ukończona!"
		}
		return m, nil
	case errorMsg:
		m.updating = false
		m.status = fmt.Sprintf("Błąd: %s", msg.err)
		return m, nil
	case statusMsg:
		m.status = msg.status
		return m, nil
	}
	return m, nil
}

func (m model) View() string {
	if m.quit {
		return "Do widzenia!\n"
	}

	s := styleTitle.Render("HackerOS Steam TUI") + "\n\n"

	for i, choice := range m.choices {
		cursor := " "
		if m.cursor == i {
			cursor = ">"
			s += styleSelected.Render(cursor + " " + choice) + "\n"
		} else {
			s += styleNormal.Render(cursor + " " + choice) + "\n"
		}
	}

	s += "\n" + styleStatus.Render(m.status) + "\n"

	if m.updating {
		bar := strings.Repeat("█", int(m.progress*50)) + strings.Repeat(" ", 50-int(m.progress*50))
		s += styleProgress.Render(bar) + fmt.Sprintf(" %.0f%%", m.progress*100) + "\n"
	}

	return s
}

func (m model) executeChoice() tea.Cmd {
	switch m.cursor {
	case 0: // Uruchom zwykły Steam
		m.status = "Uruchamianie Steama..."
		return m.runCommand([]string{"run"})
	case 1: // Uruchom Gamescope Session Steam
		m.status = "Uruchamianie Gamescope Session..."
		return m.runCommand([]string{"run", "gamescope-session-steam"})
	case 2: // Aktualizuj kontener
		m.updating = true
		m.progress = 0.0
		m.status = "Aktualizacja w toku..."
		return m.updateWithProgress()
	case 3: // Kill
		m.status = "Zabijanie Steama..."
		return m.runCommand([]string{"kill"})
	case 4: // Restart
		m.status = "Restartowanie kontenera..."
		return m.runCommand([]string{"restart"})
	case 5: // Remove
		m.status = "Usuwanie kontenera..."
		return m.runCommand([]string{"remove"})
	case 6: // Create
		m.status = "Tworzenie kontenera..."
		return m.runCommand([]string{"create"})
	case 7: // Wyjdź
		m.quit = true
		return tea.Quit
	}
	return nil
}

type progressMsg struct {
	progress float64
}

type errorMsg struct {
	err string
}

type statusMsg struct {
	status string
}

func (m model) runCommand(args []string) tea.Cmd {
	return func() tea.Msg {
		cmd := exec.Command(m.containerBin, args...)
		output, err := cmd.CombinedOutput()
		if err != nil {
			return errorMsg{err: err.Error()}
		}
		return statusMsg{status: string(output)}
	}
}

func (m model) updateWithProgress() tea.Cmd {
	return func() tea.Msg {
		cmd := exec.Command(m.containerBin, "update")
		stdout, err := cmd.StdoutPipe()
		if err != nil {
			return errorMsg{err: err.Error()}
		}
		if err := cmd.Start(); err != nil {
			return errorMsg{err: err.Error()}
		}

		scanner := bufio.NewScanner(stdout)
		for scanner.Scan() {
			line := scanner.Text()
			if strings.Contains(line, "Progress:") {
				parts := strings.Split(line, ":")
				if len(parts) > 1 {
					pctStr := strings.TrimSpace(parts[1])
					pctStr = strings.Replace(pctStr, "%", "", -1)
					pct, err := strconv.ParseFloat(pctStr, 64)
					if err == nil {
						tea.Send(progressMsg{progress: pct / 100.0})
					}
				}
			}
		}

		if err := cmd.Wait(); err != nil {
			return errorMsg{err: err.Error()}
		}
		return progressMsg{progress: 1.0}
	}
}

func main() {
	p := tea.NewProgram(initialModel())
	if _, err := p.Run(); err != nil {
		fmt.Println("Błąd:", err)
		os.Exit(1)
	}
}
