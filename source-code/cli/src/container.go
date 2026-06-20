package src

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
	"strings"
)

const (
	ContainerName = "HackerOS-Steam"
	DistroImage   = "docker.io/archlinux:latest"
)

var steamPackages = []string{
	"steam",
	"lib32-mesa",
	"lib32-vulkan-icd-loader",
	"lib32-alsa-lib",
	"lib32-gcc-libs",
	"lib32-gtk3",
	"lib32-libgcrypt",
	"lib32-libpulse",
	"lib32-libva",
	"lib32-libxml2",
	"lib32-nss",
	"lib32-openal",
	"lib32-sdl2",
	"lib32-vulkan-intel",
	"lib32-vulkan-radeon",
	"lib32-vulkan-freedreno",
	"lib32-vulkan-nouveau",
	"lib32-vulkan-swrast",
	"lib32-vulkan-virtio",
	"lib32-libxss",
	"lib32-libgpg-error",
	"lib32-dbus",
	"noto-fonts",
	"ttf-bitstream-vera",
	"ttf-croscore",
	"ttf-dejavu",
	"ttf-droid",
	"ttf-ibm-plex",
	"ttf-liberation",
	"ttf-roboto",
}

var nvidiaPackages = []string{"lib32-nvidia-utils"}

// ──────────────────────────────────────────────
//  HELPERS
// ──────────────────────────────────────────────

func RunCmd(args []string, silent bool) bool {
	if !silent {
		PrintInfo("$ " + strings.Join(args, " "))
	}
	cmd := exec.Command(args[0], args[1:]...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run() == nil
}

func RunCmdMust(args []string, silent bool) {
	if !RunCmd(args, silent) {
		PrintError("Command failed: " + strings.Join(args, " "))
		os.Exit(1)
	}
}

func RunInContainer(bashCmd string, silent bool) {
	RunCmdMust([]string{"distrobox", "enter", ContainerName, "--", "bash", "-c", bashCmd}, silent)
}

func RunInContainerOK(bashCmd string) bool {
	return RunCmd([]string{"distrobox", "enter", ContainerName, "--", "bash", "-c", bashCmd}, true)
}

func Exists() bool {
	var out bytes.Buffer
	cmd := exec.Command("distrobox", "list", "--no-color")
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr
	if cmd.Run() != nil {
		return false
	}
	return strings.Contains(out.String(), ContainerName)
}

func Running() bool {
	var out bytes.Buffer
	cmd := exec.Command("distrobox", "list", "--no-color")
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr
	if cmd.Run() != nil {
		return false
	}
	for _, line := range strings.Split(out.String(), "\n") {
		if strings.Contains(line, ContainerName) && strings.Contains(line, "Up") {
			return true
		}
	}
	return false
}

func DetailLine() string {
	var out bytes.Buffer
	cmd := exec.Command("distrobox", "list", "--no-color")
	cmd.Stdout = &out
	cmd.Stderr = os.Stderr
	if cmd.Run() != nil {
		return ""
	}
	for _, line := range strings.Split(out.String(), "\n") {
		if strings.Contains(line, ContainerName) {
			return line
		}
	}
	return ""
}

// ──────────────────────────────────────────────
//  ENABLE MULTILIB
// ──────────────────────────────────────────────

func EnableMultilib() {
	PrintInfo("Enabling [multilib] in /etc/pacman.conf...")
	RunInContainer(`sudo sed -i '/^#\[multilib\]/{s/^#//;n;s/^#//}' /etc/pacman.conf`, false)
	if !RunInContainerOK(`grep -q '^\[multilib\]' /etc/pacman.conf`) {
		PrintWarning("[multilib] section not found after sed — appending it...")
		RunInContainer(`printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' | sudo tee -a /etc/pacman.conf > /dev/null`, false)
	}
	PrintSuccess("[multilib] enabled.")
}

// ──────────────────────────────────────────────
//  INSTALL STEAM
// ──────────────────────────────────────────────

func InstallSteam(stepStart, total int) {
	s := stepStart

	PrintStep(s, total, "Enabling [multilib] repository...")
	EnableMultilib()
	s++

	PrintStep(s, total, "Refreshing package databases (pacman -Syy)...")
	RunInContainer("sudo pacman -Syy --noconfirm", false)
	s++

	PrintStep(s, total, "Upgrading base system (pacman -Syu)...")
	RunInContainer("sudo pacman -Syu --noconfirm", false)
	s++

	PrintStep(s, total, fmt.Sprintf("Installing Steam + 32-bit libs (%d packages)...", len(steamPackages)))
	RunInContainer("sudo pacman -S --noconfirm --needed "+strings.Join(steamPackages, " "), false)
	s++

	PrintStep(s, total, "Optional: NVIDIA lib32 utils...")
	if !RunInContainerOK("sudo pacman -S --noconfirm --needed " + strings.Join(nvidiaPackages, " ")) {
		PrintWarning("NVIDIA lib32 skipped (no NVIDIA driver — that's fine).")
	}
}

// ──────────────────────────────────────────────
//  CREATE
// ──────────────────────────────────────────────

func Create(force bool) {
	PrintHeader("Creating Container")

	if Exists() {
		if force {
			PrintWarning("--force: removing existing container first...")
			Remove(false)
		} else {
			PrintWarning("Container " + ContainerName + " already exists.")
			PrintInfo("Use --force to recreate, or 'setup' to install Steam into existing container.")
			return
		}
	}

	total := 6
	PrintStep(1, total, "Creating distrobox container ("+DistroImage+")...")
	RunCmdMust([]string{
		"distrobox", "create",
		"--name", ContainerName,
		"--image", DistroImage,
		"--yes",
	}, false)

	InstallSteam(2, total)

	fmt.Println()
	PrintDivider()
	PrintSuccess("Container ready!  →  HackerOS-Steam run")
	PrintDivider()
	fmt.Println()
}

// ──────────────────────────────────────────────
//  SETUP
// ──────────────────────────────────────────────

func Setup() {
	PrintHeader("Setting Up Steam in Container")
	if !Exists() {
		PrintError("Container does not exist. Run:  HackerOS-Steam create")
		os.Exit(1)
	}

	total := 5
	InstallSteam(1, total)

	fmt.Println()
	PrintDivider()
	PrintSuccess("Setup complete!  →  HackerOS-Steam run")
	PrintDivider()
	fmt.Println()
}

// ──────────────────────────────────────────────
//  KILL / STOP
// ──────────────────────────────────────────────

func Kill() {
	PrintHeader("Stopping Container")
	if !Exists() {
		PrintWarning("Container " + ContainerName + " does not exist.")
		return
	}
	if !Running() {
		PrintInfo("Container is already stopped.")
		return
	}
	PrintInfo("Stopping " + ContainerName + "...")
	RunCmdMust([]string{"distrobox", "stop", "--yes", ContainerName}, false)
	PrintSuccess("Container stopped.")
}

// ──────────────────────────────────────────────
//  REMOVE
// ──────────────────────────────────────────────

func Remove(ask bool) {
	PrintHeader("Removing Container")
	if !Exists() {
		PrintWarning("Container " + ContainerName + " does not exist.")
		return
	}
	if ask && !Confirm("Permanently remove "+ContainerName+"?") {
		PrintInfo("Aborted.")
		return
	}
	PrintInfo("Removing " + ContainerName + "...")
	RunCmdMust([]string{"distrobox", "rm", "--yes", ContainerName}, false)
	PrintSuccess("Container removed.")
}

// ──────────────────────────────────────────────
//  UPDATE
// ──────────────────────────────────────────────

func Update() {
	PrintHeader("Updating Container")
	if !Exists() {
		PrintError("Container does not exist — create it first.")
		os.Exit(1)
	}
	PrintInfo("Running distrobox-upgrade...")
	RunCmdMust([]string{"distrobox-upgrade", ContainerName}, false)
	PrintInfo("Upgrading packages inside container...")
	RunInContainer("sudo pacman -Syu --noconfirm", false)
	PrintSuccess("All packages updated.")
}

// ──────────────────────────────────────────────
//  RESTART
// ──────────────────────────────────────────────

func Restart(steamFlags []string) {
	PrintHeader("Restarting Container")
	if Running() {
		Kill()
	}
	RunSteam(steamFlags)
}

// ──────────────────────────────────────────────
//  RUN STEAM
// ──────────────────────────────────────────────

func RunSteam(flags []string) {
	PrintHeader("Launching Steam")
	if !Exists() {
		PrintError("Container does not exist — run:  HackerOS-Steam create")
		os.Exit(1)
	}
	if !RunInContainerOK("test -x /usr/bin/steam") {
		PrintError("Steam is not installed in the container!")
		PrintInfo("Fix it with:  HackerOS-Steam setup")
		os.Exit(1)
	}

	flagStr := "(none)"
	if len(flags) > 0 {
		flagStr = strings.Join(flags, " ")
	}
	PrintInfo("Container : " + ContainerName)
	PrintInfo("Flags     : " + flagStr)
	fmt.Println()

	args := append([]string{"distrobox", "enter", ContainerName, "--", "/usr/bin/steam"}, flags...)
	RunCmdMust(args, false)
}

// ──────────────────────────────────────────────
//  STATUS
// ──────────────────────────────────────────────

func Status() {
	PrintHeader("Container Status")
	if Exists() {
		isRunning := Running()
		stateColor := BrightYellow
		stateLabel := "○ Stopped"
		if isRunning {
			stateColor = BrightGreen
			stateLabel = "● Running"
		}

		steamOK := RunInContainerOK("test -x /usr/bin/steam")
		steamLabel := "✖ Not installed (run: setup)"
		steamColor := Red
		if steamOK {
			steamLabel = "✔ Installed"
			steamColor = BrightGreen
		}

		multilibOK := RunInContainerOK(`grep -q '^\[multilib\]' /etc/pacman.conf`)
		multilibLabel := "✖ Disabled"
		multilibColor := Yellow
		if multilibOK {
			multilibLabel = "✔ Enabled"
			multilibColor = BrightGreen
		}

		PrintStatusRow("Container:", ContainerName, BrightWhite)
		PrintStatusRow("Image:", DistroImage, BrightBlack)
		PrintStatusRow("Status:", stateLabel, stateColor)
		PrintStatusRow("Steam:", steamLabel, steamColor)
		PrintStatusRow("multilib:", multilibLabel, multilibColor)

		if dl := DetailLine(); dl != "" {
			PrintDivider()
			PrintInfo(strings.TrimSpace(dl))
		}
	} else {
		PrintStatusRow("Container:", ContainerName, BrightBlack)
		PrintStatusRow("Status:", "✖ Does not exist", Red)
		fmt.Println()
		PrintInfo("Create with:  HackerOS-Steam create")
	}
	fmt.Println()
}

// ──────────────────────────────────────────────
//  LIST
// ──────────────────────────────────────────────

func List() {
	PrintHeader("All Distrobox Containers")
	RunCmdMust([]string{"distrobox", "list"}, false)
}

// ──────────────────────────────────────────────
//  INSTALL EXTRA PACKAGES
// ──────────────────────────────────────────────

func InstallPackages(packages []string) {
	PrintHeader("Installing Packages")
	if !Exists() {
		PrintError("Container does not exist — create it first.")
		os.Exit(1)
	}
	PrintInfo("Packages: " + strings.Join(packages, ", "))
	RunInContainer("sudo pacman -S --noconfirm --needed "+strings.Join(packages, " "), false)
	PrintSuccess(fmt.Sprintf("Done — %d package(s) installed.", len(packages)))
}

// ──────────────────────────────────────────────
//  EXPORT APP
// ──────────────────────────────────────────────

func ExportApp() {
	PrintHeader("Exporting Steam to Host")
	if !Exists() {
		PrintError("Container does not exist — run:  HackerOS-Steam create")
		os.Exit(1)
	}
	PrintInfo("Exporting Steam desktop entry to host...")
	RunInContainer("distrobox-export --app steam --export-label ' (HackerOS)'", false)
	PrintSuccess("Steam exported. It should now appear in your app launcher.")
}

// ──────────────────────────────────────────────
//  LOGS
// ──────────────────────────────────────────────

func Logs(lines int) {
	PrintHeader("Steam Logs")
	if !Exists() {
		PrintError("Container does not exist.")
		os.Exit(1)
	}
	logPath := "~/.steam/steam/logs/bootstrap_log.txt"
	RunInContainer(fmt.Sprintf("tail -n %d %s 2>/dev/null || echo '(no log found at %s)'", lines, logPath, logPath), false)
}

// ──────────────────────────────────────────────
//  SHELL
// ──────────────────────────────────────────────

func Shell() {
	PrintHeader("Container Shell")
	if !Exists() {
		PrintError("Container does not exist — run:  HackerOS-Steam create")
		os.Exit(1)
	}
	PrintInfo("Opening shell in " + ContainerName + "... (type 'exit' to leave)")
	RunCmdMust([]string{"distrobox", "enter", ContainerName}, false)
}
