package tui

import "github.com/charmbracelet/lipgloss"

// ─────────────────────────────────────────────────────────────────
//  Colour palette
// ─────────────────────────────────────────────────────────────────

var (
	ColBg      = lipgloss.Color("#0e1117")
	ColBgDeep  = lipgloss.Color("#080a0f")
	ColBgRaise = lipgloss.Color("#141920")
	ColBorder  = lipgloss.Color("#1e2535")
	ColAccent  = lipgloss.Color("#4a9eff")
	ColGreen   = lipgloss.Color("#3ddc84")
	ColRed     = lipgloss.Color("#ff4a6b")
	ColYellow  = lipgloss.Color("#ffb347")
	ColPurple  = lipgloss.Color("#c792ea")
	ColText    = lipgloss.Color("#d6e0f0")
	ColDim     = lipgloss.Color("#3a4255")
	ColSub     = lipgloss.Color("#6b7a99")
)

// ─────────────────────────────────────────────────────────────────
//  Shared styles
// ─────────────────────────────────────────────────────────────────

var (
	StyleTitle = lipgloss.NewStyle().
			Foreground(ColAccent).
			Bold(true)

	StyleSubtitle = lipgloss.NewStyle().
			Foreground(ColSub)

	StyleSectionLabel = lipgloss.NewStyle().
				Foreground(ColDim).
				Bold(true).
				MarginTop(1)

	StyleMenuItem = lipgloss.NewStyle().
			Foreground(ColText).
			PaddingLeft(2)

	StyleMenuSelected = lipgloss.NewStyle().
				Foreground(ColAccent).
				Background(lipgloss.Color("#0e2040")).
				Bold(true).
				PaddingLeft(1).
				SetString("▶ ")

	StyleMenuIcon = lipgloss.NewStyle().
			Foreground(ColSub)

	StyleStatusRunning = lipgloss.NewStyle().Foreground(ColGreen).Bold(true)
	StyleStatusStopped = lipgloss.NewStyle().Foreground(ColYellow).Bold(true)
	StyleStatusMissing = lipgloss.NewStyle().Foreground(ColRed).Bold(true)
	StyleStatusCheck   = lipgloss.NewStyle().Foreground(ColDim)

	StyleLogInfo    = lipgloss.NewStyle().Foreground(ColAccent)
	StyleLogSuccess = lipgloss.NewStyle().Foreground(ColGreen)
	StyleLogError   = lipgloss.NewStyle().Foreground(ColRed)
	StyleLogWarning = lipgloss.NewStyle().Foreground(ColYellow)
	StyleLogHeader  = lipgloss.NewStyle().Foreground(ColPurple).Bold(true)
	StyleLogDim     = lipgloss.NewStyle().Foreground(ColDim)

	StyleConfirmBox = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColRed).
			Padding(1, 4).
			Foreground(ColText)

	StyleDivider = lipgloss.NewStyle().Foreground(ColBorder)
)
