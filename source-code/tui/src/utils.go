package tui

import "strings"

// ─────────────────────────────────────────────────────────────────
//  ANSI strip
// ─────────────────────────────────────────────────────────────────

func StripANSI(s string) string {
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

// ─────────────────────────────────────────────────────────────────
//  ColorLine — apply lipgloss colour based on line content
// ─────────────────────────────────────────────────────────────────

func ColorLine(line string) string {
	l := line
	switch {
	case strings.Contains(l, "✔") || strings.Contains(l, "Done") || strings.Contains(l, "complete"):
		return StyleLogSuccess.Render(l)
	case strings.Contains(l, "✖") || strings.Contains(l, "error") ||
		strings.Contains(l, "failed") || strings.Contains(l, "Error"):
		return StyleLogError.Render(l)
	case strings.Contains(l, "⚠") || strings.Contains(l, "warning") ||
		strings.Contains(l, "skipped") || strings.Contains(l, "Warning"):
		return StyleLogWarning.Render(l)
	case strings.Contains(l, "─ ") || strings.Contains(l, "LAUNCH") ||
		strings.Contains(l, "CREAT") || strings.Contains(l, "SETUP") ||
		strings.Contains(l, "UPDAT") || strings.Contains(l, "REMOV") ||
		strings.Contains(l, "STATUS") || strings.Contains(l, "STOP"):
		return StyleLogHeader.Render(l)
	case strings.Contains(l, "→") || strings.Contains(l, "$"):
		return StyleLogInfo.Render(l)
	default:
		return StyleLogDim.Render(l)
	}
}
