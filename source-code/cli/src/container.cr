require "./ui"
require "./colors"

module Container
  include Colors

  CONTAINER_NAME = "HackerOS-Steam"
  DISTRO_IMAGE   = "docker.io/archlinux:latest"

  STEAM_PACKAGES = [
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
  ]

  NVIDIA_PACKAGES = ["lib32-nvidia-utils"]

  # ──────────────────────────────────────────────
  #  HELPERS
  # ──────────────────────────────────────────────

  def self.run_cmd(args : Array(String), silent : Bool = false) : Bool
    unless silent
      UI.print_info("$ #{args.join(" ")}")
    end
    status = Process.run(
      args[0],
      args[1..],
      output: Process::Redirect::Inherit,
      error: Process::Redirect::Inherit
    )
    status.success?
  end

  def self.run_cmd!(args : Array(String), silent : Bool = false)
    unless run_cmd(args, silent)
      UI.print_error("Command failed: #{args.join(" ")}")
      exit(1)
    end
  end

  # Use plain `bash -c` (NOT -lc) — login shell in distrobox causes PATH issues
  def self.run_in_container(bash_cmd : String, silent : Bool = false)
    run_cmd!(["distrobox", "enter", CONTAINER_NAME, "--", "bash", "-c", bash_cmd], silent)
  end

  def self.run_in_container_ok?(bash_cmd : String) : Bool
    run_cmd(["distrobox", "enter", CONTAINER_NAME, "--", "bash", "-c", bash_cmd], silent: true)
  end

  def self.exists? : Bool
    output = IO::Memory.new
    status = Process.run("distrobox", ["list", "--no-color"], output: output, error: Process::Redirect::Inherit)
    return false unless status.success?
    output.to_s.includes?(CONTAINER_NAME)
  end

  def self.running? : Bool
    output = IO::Memory.new
    status = Process.run("distrobox", ["list", "--no-color"], output: output, error: Process::Redirect::Inherit)
    return false unless status.success?
    output.to_s.lines.any? { |l| l.includes?(CONTAINER_NAME) && l.includes?("Up") }
  end

  def self.detail_line : String?
    output = IO::Memory.new
    status = Process.run("distrobox", ["list", "--no-color"], output: output, error: Process::Redirect::Inherit)
    return nil unless status.success?
    output.to_s.lines.find { |l| l.includes?(CONTAINER_NAME) }
  end

  # ──────────────────────────────────────────────
  #  ENABLE MULTILIB
  #  Uses sed to uncomment the [multilib] section.
  #  Falls back to appending a fresh block if the
  #  section doesn't exist at all.
  # ──────────────────────────────────────────────
  def self.enable_multilib
    UI.print_info("Enabling [multilib] in /etc/pacman.conf...")

    # sed: uncomment #[multilib] and the #Include line immediately after it
    run_in_container(
      "sudo sed -i '/^#\\[multilib\\]/{s/^#//;n;s/^#//}' /etc/pacman.conf"
    )

    # Verify multilib is now active
    unless run_in_container_ok?("grep -q '^\\[multilib\\]' /etc/pacman.conf")
      UI.print_warning("[multilib] section not found after sed — appending it...")
      run_in_container(
        "printf '\\n[multilib]\\nInclude = /etc/pacman.d/mirrorlist\\n' | sudo tee -a /etc/pacman.conf > /dev/null"
      )
    end

    UI.print_success("[multilib] enabled.")
  end

  # ──────────────────────────────────────────────
  #  INSTALL STEAM  (shared by create & setup)
  # ──────────────────────────────────────────────
  def self.install_steam(step_start : Int32, total : Int32)
    s = step_start

    UI.print_step(s, total, "Enabling [multilib] repository...")
    enable_multilib
    s += 1

    UI.print_step(s, total, "Refreshing package databases (pacman -Syy)...")
    run_in_container("sudo pacman -Syy --noconfirm")
    s += 1

    UI.print_step(s, total, "Upgrading base system (pacman -Syu)...")
    run_in_container("sudo pacman -Syu --noconfirm")
    s += 1

    UI.print_step(s, total, "Installing Steam + 32-bit libs (#{STEAM_PACKAGES.size} packages)...")
    run_in_container("sudo pacman -S --noconfirm --needed #{STEAM_PACKAGES.join(" ")}")
    s += 1

    UI.print_step(s, total, "Optional: NVIDIA lib32 utils...")
    unless run_in_container_ok?("sudo pacman -S --noconfirm --needed #{NVIDIA_PACKAGES.join(" ")}")
      UI.print_warning("NVIDIA lib32 skipped (no NVIDIA driver — that's fine).")
    end
  end

  # ──────────────────────────────────────────────
  #  CREATE
  # ──────────────────────────────────────────────
  def self.create(force : Bool = false)
    UI.print_header("Creating Container")

    if exists?
      if force
        UI.print_warning("--force: removing existing container first...")
        remove(ask: false)
      else
        UI.print_warning("Container #{CONTAINER_NAME} already exists.")
        UI.print_info("Use --force to recreate, or 'setup' to install Steam into existing container.")
        return
      end
    end

    total = 6
    UI.print_step(1, total, "Creating distrobox container (#{DISTRO_IMAGE})...")
    run_cmd!([
      "distrobox", "create",
      "--name", CONTAINER_NAME,
      "--image", DISTRO_IMAGE,
      "--yes",
    ])

    install_steam(step_start: 2, total: total)

    puts ""
    UI.print_divider
    UI.print_success("Container ready!  →  HackerOS-Steam run")
    UI.print_divider
    puts ""
  end

  # ──────────────────────────────────────────────
  #  SETUP
  #  Install/repair Steam in an existing container.
  #  Useful when container was created manually or
  #  Steam is missing for any reason.
  # ──────────────────────────────────────────────
  def self.setup
    UI.print_header("Setting Up Steam in Container")
    unless exists?
      UI.print_error("Container does not exist. Run:  HackerOS-Steam create")
      exit(1)
    end

    total = 5
    install_steam(step_start: 1, total: total)

    puts ""
    UI.print_divider
    UI.print_success("Setup complete!  →  HackerOS-Steam run")
    UI.print_divider
    puts ""
  end

  # ──────────────────────────────────────────────
  #  KILL / STOP
  # ──────────────────────────────────────────────
  def self.kill
    UI.print_header("Stopping Container")
    unless exists?
      UI.print_warning("Container #{CONTAINER_NAME} does not exist.")
      return
    end
    unless running?
      UI.print_info("Container is already stopped.")
      return
    end
    UI.print_info("Stopping #{CONTAINER_NAME}...")
    run_cmd!(["distrobox", "stop", "--yes", CONTAINER_NAME])
    UI.print_success("Container stopped.")
  end

  # ──────────────────────────────────────────────
  #  REMOVE
  # ──────────────────────────────────────────────
  def self.remove(ask : Bool = true)
    UI.print_header("Removing Container")
    unless exists?
      UI.print_warning("Container #{CONTAINER_NAME} does not exist.")
      return
    end
    if ask && !UI.confirm?("Permanently remove #{CONTAINER_NAME}?")
      UI.print_info("Aborted.")
      return
    end
    UI.print_info("Removing #{CONTAINER_NAME}...")
    run_cmd!(["distrobox", "rm", "--yes", CONTAINER_NAME])
    UI.print_success("Container removed.")
  end

  # ──────────────────────────────────────────────
  #  UPDATE
  # ──────────────────────────────────────────────
  def self.update
    UI.print_header("Updating Container")
    unless exists?
      UI.print_error("Container does not exist — create it first.")
      exit(1)
    end
    UI.print_info("Running distrobox-upgrade...")
    run_cmd!(["distrobox-upgrade", CONTAINER_NAME])
    UI.print_info("Upgrading packages inside container...")
    run_in_container("sudo pacman -Syu --noconfirm")
    UI.print_success("All packages updated.")
  end

  # ──────────────────────────────────────────────
  #  RESTART
  # ──────────────────────────────────────────────
  def self.restart(steam_flags : Array(String) = [] of String)
    UI.print_header("Restarting Container")
    kill if running?
    run_steam(steam_flags)
  end

  # ──────────────────────────────────────────────
  #  RUN STEAM
  # ──────────────────────────────────────────────
  def self.run_steam(flags : Array(String) = [] of String)
    UI.print_header("Launching Steam")
    unless exists?
      UI.print_error("Container does not exist — run:  HackerOS-Steam create")
      exit(1)
    end

    # Check Steam is actually installed before trying to run it
    unless run_in_container_ok?("test -x /usr/bin/steam")
      UI.print_error("Steam is not installed in the container!")
      UI.print_info("Fix it with:  HackerOS-Steam setup")
      exit(1)
    end

    flag_str = flags.empty? ? "(none)" : flags.join(" ")
    UI.print_info("Container : #{CONTAINER_NAME}")
    UI.print_info("Flags     : #{flag_str}")
    puts ""

    # Call /usr/bin/steam directly — no bash wrapper (avoids PATH issues)
    run_cmd!(["distrobox", "enter", CONTAINER_NAME, "--", "/usr/bin/steam"] + flags)
  end

  # ──────────────────────────────────────────────
  #  STATUS
  # ──────────────────────────────────────────────
  def self.status
    UI.print_header("Container Status")
    if exists?
      is_running = running?
      state_color = is_running ? BRIGHT_GREEN : BRIGHT_YELLOW
      state_label = is_running ? "● Running" : "○ Stopped"

      steam_ok    = run_in_container_ok?("test -x /usr/bin/steam")
      steam_label = steam_ok ? "✔ Installed" : "✖ Not installed (run: setup)"
      steam_color = steam_ok ? BRIGHT_GREEN : RED

      multilib_ok    = run_in_container_ok?("grep -q '^\\[multilib\\]' /etc/pacman.conf")
      multilib_label = multilib_ok ? "✔ Enabled" : "✖ Disabled"
      multilib_color = multilib_ok ? BRIGHT_GREEN : YELLOW

      UI.print_status_row("Container:", CONTAINER_NAME, BRIGHT_WHITE)
      UI.print_status_row("Image:", DISTRO_IMAGE, BRIGHT_BLACK)
      UI.print_status_row("Status:", state_label, state_color)
      UI.print_status_row("Steam:", steam_label, steam_color)
      UI.print_status_row("multilib:", multilib_label, multilib_color)
      if (dl = detail_line)
        UI.print_divider
        UI.print_info(dl.strip)
      end
    else
      UI.print_status_row("Container:", CONTAINER_NAME, BRIGHT_BLACK)
      UI.print_status_row("Status:", "✖ Does not exist", RED)
      puts ""
      UI.print_info("Create with:  HackerOS-Steam create")
    end
    puts ""
  end

  # ──────────────────────────────────────────────
  #  LIST
  # ──────────────────────────────────────────────
  def self.list
    UI.print_header("All Distrobox Containers")
    run_cmd!(["distrobox", "list"])
  end

  # ──────────────────────────────────────────────
  #  INSTALL EXTRA PACKAGES
  # ──────────────────────────────────────────────
  def self.install_packages(packages : Array(String))
    UI.print_header("Installing Packages")
    unless exists?
      UI.print_error("Container does not exist — create it first.")
      exit(1)
    end
    UI.print_info("Packages: #{packages.join(", ")}")
    run_in_container("sudo pacman -S --noconfirm --needed #{packages.join(" ")}")
    UI.print_success("Done — #{packages.size} package(s) installed.")
  end
end
