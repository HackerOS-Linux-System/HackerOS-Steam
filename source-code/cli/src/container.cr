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

  # NVIDIA utils are optional — skip if unavailable
  NVIDIA_PACKAGES = ["lib32-nvidia-utils"]

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

  def self.run_in_container(bash_cmd : String, silent : Bool = false)
    run_cmd!(["distrobox", "enter", CONTAINER_NAME, "--", "bash", "-lc", bash_cmd], silent)
  end

  def self.run_in_container_ok?(bash_cmd : String) : Bool
    run_cmd(["distrobox", "enter", CONTAINER_NAME, "--", "bash", "-lc", bash_cmd], silent: true)
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
  #  CREATE
  # ──────────────────────────────────────────────
  def self.create(force : Bool = false)
    UI.print_header("Creating Container")

    if exists?
      if force
        UI.print_warning("Force flag set — removing existing container first...")
        remove(ask: false)
      else
        UI.print_warning("Container #{CONTAINER_NAME} already exists.")
        UI.print_info("Use --force to recreate it from scratch.")
        return
      end
    end

    steps = 6
    UI.print_step(1, steps, "Creating distrobox container (#{DISTRO_IMAGE})...")
    run_cmd!([
      "distrobox", "create",
      "--name", CONTAINER_NAME,
      "--image", DISTRO_IMAGE,
      "--yes",
    ])

    UI.print_step(2, steps, "Enabling multilib repository...")
    run_in_container(
      "grep -q '^\\[multilib\\]' /etc/pacman.conf || " \
      "echo -e '\\n[multilib]\\nInclude = /etc/pacman.d/mirrorlist' | sudo tee -a /etc/pacman.conf > /dev/null"
    )

    UI.print_step(3, steps, "Refreshing package databases...")
    run_in_container("sudo pacman -Syy --noconfirm")

    UI.print_step(4, steps, "Upgrading base system...")
    run_in_container("sudo pacman -Syu --noconfirm")

    UI.print_step(5, steps, "Installing Steam and 32-bit libraries (#{STEAM_PACKAGES.size} packages)...")
    pkg_list = STEAM_PACKAGES.join(" ")
    run_in_container("sudo pacman -S --noconfirm --needed #{pkg_list}")

    UI.print_step(6, steps, "Attempting optional NVIDIA lib32 utilities...")
    nvidia_ok = run_in_container_ok?("sudo pacman -S --noconfirm --needed #{NVIDIA_PACKAGES.join(" ")}")
    unless nvidia_ok
      UI.print_warning("NVIDIA lib32 utils skipped (no NVIDIA driver detected — that's OK).")
    end

    puts ""
    UI.print_divider
    UI.print_success("Container ready! Run:  #{BOLD}HackerOS-Steam run#{RESET}")
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
    UI.print_info("Sending stop signal to #{CONTAINER_NAME}...")
    run_cmd!(["distrobox", "stop", "--name", CONTAINER_NAME, "--yes"])
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
    if ask && !UI.confirm?("This will permanently remove #{CONTAINER_NAME}. Continue?")
      UI.print_info("Aborted.")
      return
    end
    UI.print_info("Removing container #{CONTAINER_NAME}...")
    run_cmd!(["distrobox", "rm", "--name", CONTAINER_NAME, "--force", "--yes"])
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
    UI.print_success("All packages updated. Steam will self-update on next launch.")
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
    flag_str = flags.empty? ? "(none)" : flags.join(" ")
    UI.print_info("Container : #{CONTAINER_NAME}")
    UI.print_info("Flags     : #{flag_str}")
    puts ""
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
      UI.print_status_row("Container:", CONTAINER_NAME, BRIGHT_WHITE)
      UI.print_status_row("Image:", DISTRO_IMAGE, BRIGHT_BLACK)
      UI.print_status_row("Status:", state_label, state_color)
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
