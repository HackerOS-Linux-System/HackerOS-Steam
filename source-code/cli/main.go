package main

import (
	"fmt"
	"hackeros-steam/src"
	"os"
	"strconv"
)

func printHelp() {
	src.PrintBanner()
	fmt.Printf("  %s%sUSAGE%s\n", src.Bold, src.White, src.Reset)
	fmt.Printf("  %sHackerOS-Steam %s<command> %s[options] [flags]%s\n", src.BrightBlack, src.Cyan, src.BrightBlack, src.Reset)
	fmt.Println()
	fmt.Printf("  %s%sCOMMANDS%s\n", src.Bold, src.White, src.Reset)
	src.PrintDivider()
	src.PrintHelpRow("create [--force]", "Create the Steam container (Arch + multilib + Steam)")
	src.PrintHelpRow("setup", "Install Steam into an existing container (repair)")
	src.PrintHelpRow("run [flags...]", "Launch Steam (e.g. -gamepadui -steamos3 -steamdeck)")
	src.PrintHelpRow("kill", "Stop the running container")
	src.PrintHelpRow("remove", "Remove the container (asks for confirmation)")
	src.PrintHelpRow("update", "Update container OS + all packages")
	src.PrintHelpRow("restart [flags...]", "Stop then relaunch Steam")
	src.PrintHelpRow("status", "Show container state and details")
	src.PrintHelpRow("list", "List all distrobox containers")
	src.PrintHelpRow("install PKG...", "Install additional Arch packages inside container")
	src.PrintHelpRow("export", "Export Steam app entry to host desktop")
	src.PrintHelpRow("logs [N]", "Show last N lines of Steam logs (default: 50)")
	src.PrintHelpRow("shell", "Open an interactive shell inside the container")
	src.PrintHelpRow("gui", "Launch GTK4 GUI  (/usr/share/HackerOS/Scripts/Steam/bin/gui)")
	src.PrintHelpRow("tui", "Launch terminal TUI  (/usr/share/HackerOS/Scripts/Steam/bin/tui)")
	src.PrintDivider()
	fmt.Println()
	fmt.Printf("  %s%sEXAMPLES%s\n", src.Bold, src.White, src.Reset)
	fmt.Printf("  %sHackerOS-Steam create%s\n", src.BrightBlack, src.Reset)
	fmt.Printf("  %sHackerOS-Steam create --force%s\n", src.BrightBlack, src.Reset)
	fmt.Printf("  %sHackerOS-Steam run -gamepadui%s\n", src.BrightBlack, src.Reset)
	fmt.Printf("  %sHackerOS-Steam install mangohud lib32-mangohud%s\n", src.BrightBlack, src.Reset)
	fmt.Printf("  %sHackerOS-Steam logs 100%s\n", src.BrightBlack, src.Reset)
	fmt.Printf("  %sHackerOS-Steam shell%s\n", src.BrightBlack, src.Reset)
	fmt.Println()
}

func launchExternal(path, name string) {
	src.PrintInfo("Launching " + name + ": " + path)
	info, err := os.Stat(path)
	if err != nil || info.Mode()&0111 == 0 {
		src.PrintError(name + " binary not found or not executable: " + path)
		os.Exit(1)
	}
	if !src.RunCmd([]string{path}, false) {
		src.PrintError(name + " exited with error.")
		os.Exit(1)
	}
}

func main() {
	args := os.Args[1:]

	// Extract flags
	force := false
	help := false
	filtered := args[:0]
	for _, a := range args {
		switch a {
		case "--force":
			force = true
		case "--help", "-h":
			help = true
		default:
			filtered = append(filtered, a)
		}
	}
	args = filtered

	if help || len(args) == 0 {
		printHelp()
		if len(args) == 0 && !help {
			os.Exit(1)
		}
		os.Exit(0)
	}

	command := args[0]
	rest := args[1:]

	src.PrintBanner()

	switch command {
	case "create":
		src.Create(force)
	case "run":
		src.RunSteam(rest)
	case "setup":
		src.Setup()
	case "kill", "stop":
		src.Kill()
	case "remove", "rm", "delete":
		src.Remove(!force)
	case "update", "upgrade":
		src.Update()
	case "restart":
		src.Restart(rest)
	case "status":
		src.Status()
	case "list", "ls":
		src.List()
	case "install":
		if len(rest) == 0 {
			src.PrintError("No packages specified. Usage:  HackerOS-Steam install PKG [PKG...]")
			os.Exit(1)
		}
		src.InstallPackages(rest)
	case "export":
		src.ExportApp()
	case "logs":
		lines := 50
		if len(rest) > 0 {
			if n, err := strconv.Atoi(rest[0]); err == nil {
				lines = n
			}
		}
		src.Logs(lines)
	case "shell", "sh":
		src.Shell()
	case "gui":
		launchExternal("/usr/share/HackerOS/Scripts/Steam/bin/gui", "GUI")
	case "tui":
		launchExternal("/usr/share/HackerOS/Scripts/Steam/bin/tui", "TUI")
	default:
		src.PrintError("Unknown command: '" + command + "'")
		fmt.Println()
		printHelp()
		os.Exit(1)
	}
}
