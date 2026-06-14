package tui

import (
	"strings"

	"github.com/charmbracelet/lipgloss"
)

// ─────────────────────────────────────────────────────────────────
//  Panel sizing helpers
// ─────────────────────────────────────────────────────────────────

func LogPanelWidth(w int) int {
	if w < 32 {
		return 10
	}
	return w - 30
}

func LogPanelHeight(h int) int {
	if h < 6 {
		return 1
	}
	return h - 5
}

// ─────────────────────────────────────────────────────────────────
//  Root view
// ─────────────────────────────────────────────────────────────────

func (m Model) View() string {
	if m.Width == 0 {
		return "Loading..."
	}

	left := m.renderSidebar()
	right := m.renderLogPanel()
	content := lipgloss.JoinHorizontal(lipgloss.Top, left, right)
	header := m.renderHeader()
	statusBar := m.renderStatusBar()

	if m.State == StateConfirm {
		overlay := m.renderConfirmDialog()
		return lipgloss.JoinVertical(lipgloss.Left, header, overlay, statusBar)
	}

	return lipgloss.JoinVertical(lipgloss.Left, header, content, statusBar)
}

// ─────────────────────────────────────────────────────────────────
//  Header
// ─────────────────────────────────────────────────────────────────

func (m Model) renderHeader() string {
	title := StyleTitle.Render("HackerOS") +
		lipgloss.NewStyle().Foreground(ColText).Bold(true).Render(" Steam")
	sub := StyleSubtitle.Render(" TUI  ·  Distrobox · Arch Linux")

	spin := ""
	if m.Busy {
		spin = "  " + m.Spinner.View()
	}

	left := title + sub + spin
	right := lipgloss.NewStyle().Foreground(ColDim).
		Render("q quit · r refresh · ↑↓ navigate · enter select")

	gap := m.Width - lipgloss.Width(left) - lipgloss.Width(right) - 2
	if gap < 1 {
		gap = 1
	}

	bar := lipgloss.NewStyle().
		Background(ColBg).
		Foreground(ColText).
		Padding(0, 1).
		Width(m.Width).
		Render(left + strings.Repeat(" ", gap) + right)

	divider := StyleDivider.Render(strings.Repeat("─", m.Width))
	return lipgloss.JoinVertical(lipgloss.Left, bar, divider)
}

// ─────────────────────────────────────────────────────────────────
//  Sidebar
// ─────────────────────────────────────────────────────────────────

func (m Model) renderSidebar() string {
	sideWidth := 28
	var rows []string

	currentSection := ""
	for i, item := range MenuItems {
		if item.Section != "" && item.Section != currentSection {
			currentSection = item.Section
			if len(rows) > 0 {
				rows = append(rows, "")
			}
			rows = append(rows, StyleSectionLabel.Width(sideWidth).Render(" "+item.Section))
		}

		icon := StyleMenuIcon.Render(item.Icon)
		label := item.Label

		if i == m.Cursor {
			row := StyleMenuSelected.Render("") + icon + " " +
				lipgloss.NewStyle().Foreground(ColAccent).Bold(true).Render(label)
			rows = append(rows, lipgloss.NewStyle().
				Background(lipgloss.Color("#0e2040")).
				Width(sideWidth).
				Render(row))
		} else {
			row := "  " + icon + " " + StyleMenuItem.Render(label)
			rows = append(rows, lipgloss.NewStyle().Width(sideWidth).Render(row))
		}
	}

	used := len(rows) + 4
	fill := m.Height - used - 4
	for i := 0; i < fill; i++ {
		rows = append(rows, strings.Repeat(" ", sideWidth))
	}

	body := strings.Join(rows, "\n")

	return lipgloss.NewStyle().
		Width(sideWidth).
		Height(m.Height - 4).
		Background(ColBg).
		BorderRight(true).
		BorderStyle(lipgloss.NormalBorder()).
		BorderForeground(ColBorder).
		Render(body)
}

// ─────────────────────────────────────────────────────────────────
//  Log panel
// ─────────────────────────────────────────────────────────────────

func (m Model) renderLogPanel() string {
	w := LogPanelWidth(m.Width)
	h := LogPanelHeight(m.Height)

	m.LogViewport.Width = w - 2
	m.LogViewport.Height = h

	title := lipgloss.NewStyle().
		Foreground(ColDim).
		Background(lipgloss.Color("#0d0f14")).
		Width(w).
		Padding(0, 1).
		Render("● ● ●   Output Log")

	panel := lipgloss.NewStyle().
		Width(w).
		Height(h).
		Background(ColBgDeep).
		Render(m.LogViewport.View())

	return lipgloss.JoinVertical(lipgloss.Left, title, panel)
}

// ─────────────────────────────────────────────────────────────────
//  Status bar
// ─────────────────────────────────────────────────────────────────

func (m Model) renderStatusBar() string {
	status := m.statusString()

	left := lipgloss.NewStyle().Foreground(ColAccent).Bold(true).Render("HackerOS-Steam")
	sep := lipgloss.NewStyle().Foreground(ColDim).Render("  ·  ")
	right := lipgloss.NewStyle().Foreground(ColDim).Render("docker.io/archlinux:latest")

	gap := m.Width - lipgloss.Width(left) - lipgloss.Width(sep) -
		lipgloss.Width(status) - lipgloss.Width(right) - 4
	if gap < 1 {
		gap = 1
	}

	divider := StyleDivider.Render(strings.Repeat("─", m.Width))
	bar := lipgloss.NewStyle().
		Background(ColBg).
		Width(m.Width).
		Padding(0, 1).
		Render(left + sep + status + strings.Repeat(" ", gap) + right)

	return lipgloss.JoinVertical(lipgloss.Left, divider, bar)
}

func (m Model) statusString() string {
	switch m.ContainerStatus {
	case "running":
		return StyleStatusRunning.Render("● Running")
	case "stopped":
		return StyleStatusStopped.Render("○ Stopped")
	case "missing":
		return StyleStatusMissing.Render("✖ Not Created")
	default:
		return StyleStatusCheck.Render("… Checking")
	}
}

// ─────────────────────────────────────────────────────────────────
//  Confirm dialog
// ─────────────────────────────────────────────────────────────────

func (m Model) renderConfirmDialog() string {
	item := ""
	for _, mi := range MenuItems {
		if mi.Confirm {
			item = mi.Label
			break
		}
	}

	content := lipgloss.JoinVertical(lipgloss.Center,
		lipgloss.NewStyle().Foreground(ColRed).Bold(true).Render("⚠  Confirm Action"),
		"",
		lipgloss.NewStyle().Foreground(ColText).Render("Action: "+item),
		lipgloss.NewStyle().Foreground(ColSub).Render("This cannot be undone."),
		"",
		lipgloss.NewStyle().Foreground(ColGreen).Bold(true).Render("[Y]")+" "+
			lipgloss.NewStyle().Foreground(ColText).Render("confirm")+"   "+
			lipgloss.NewStyle().Foreground(ColRed).Bold(true).Render("[N]")+" "+
			lipgloss.NewStyle().Foreground(ColText).Render("cancel"),
	)

	return lipgloss.NewStyle().
		Width(m.Width).
		Align(lipgloss.Center).
		Padding(2, 0).
		Render(StyleConfirmBox.Render(content))
}
