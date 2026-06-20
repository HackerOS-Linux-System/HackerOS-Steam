package src

import (
	"bufio"
	"fmt"
	"os"
	"strings"
)

const banner = `
` + Bold + BrightCyan + `
  ██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗██████╗  ██████╗ ███████╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗██╔═══██╗██╔════╝
  ███████║███████║██║     █████╔╝ █████╗  ██████╔╝██║   ██║███████╗
  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝` + Reset

func PrintBanner() {
	fmt.Println(banner)
	termWidth := 72
	subtitle := "  Steam Container Manager — powered by Distrobox + Arch Linux"
	padding := (termWidth - len(subtitle)) / 2
	if padding < 0 {
		padding = 0
	}
	fmt.Printf("%s%s%s\n", Bold+BrightBlack, strings.Repeat("─", 72), Reset)
	fmt.Printf("%s%s%s%s%s\n", strings.Repeat(" ", padding), BrightMagenta+Bold, subtitle, Reset, "")
	fmt.Printf("%s%s%s\n", Bold+BrightBlack, strings.Repeat("─", 72), Reset)
	fmt.Println()
}

func PrintSuccess(msg string) {
	fmt.Printf("  %s%s✔%s  %s%s%s\n", Bold, BrightGreen, Reset, White, msg, Reset)
}

func PrintInfo(msg string) {
	fmt.Printf("  %s%s→%s  %s%s%s\n", Bold, BrightBlue, Reset, BrightBlack, msg, Reset)
}

func PrintWarning(msg string) {
	fmt.Printf("  %s%s⚠%s  %s%s%s\n", Bold, BrightYellow, Reset, Yellow, msg, Reset)
}

func PrintError(msg string) {
	fmt.Printf("  %s%s✖%s  %s%s%s\n", Bold, BrightRed, Reset, Red, msg, Reset)
}

func PrintHeader(title string) {
	dashes := 50 - len(title)
	if dashes < 0 {
		dashes = 0
	}
	fmt.Println()
	fmt.Printf("  %s%s┌─ %s %s%s%s\n", Bold, BrightCyan, strings.ToUpper(title), BrightBlack, strings.Repeat("─", dashes), Reset)
	fmt.Println()
}

func PrintStep(step, total int, msg string) {
	pct := 0
	if total > 0 {
		pct = step * 100 / total
	}
	barFilled := pct * 20 / 100
	bar := BrightGreen + strings.Repeat("█", barFilled) + BrightBlack + strings.Repeat("░", 20-barFilled) + Reset
	fmt.Printf("  %s%s[%s%2d/%d%s]%s %s %s%d%%%s  %s%s%s\n",
		Bold, BrightBlack, BrightCyan, step, total, BrightBlack, Reset,
		bar,
		BrightBlack, pct, Reset,
		White, msg, Reset,
	)
}

func PrintStatusRow(label, value, color string) {
	fmt.Printf("  %s%-18s%s %s%s%s\n", BrightBlack, label, Reset, color, value, Reset)
}

func PrintDivider() {
	fmt.Printf("  %s%s%s\n", BrightBlack, strings.Repeat("─", 68), Reset)
}

func PrintHelpRow(cmd, desc string) {
	fmt.Printf("  %s%s%-22s%s %s%s%s\n", Bold, BrightCyan, cmd, Reset, BrightBlack, desc, Reset)
}

func Confirm(prompt string) bool {
	fmt.Printf("  %s%s?%s  %s%s %s[y/N]%s ", Bold, BrightYellow, Reset, White, prompt, BrightBlack, Reset)
	scanner := bufio.NewScanner(os.Stdin)
	if scanner.Scan() {
		response := strings.ToLower(strings.TrimSpace(scanner.Text()))
		return response == "y" || response == "yes"
	}
	return false
}
