require "option_parser"

CONTAINER_NAME = "HackerOS-Steam"
DISTRO_IMAGE = "docker.io/archlinux:latest"

# ANSI color codes
RESET = "\e[0m"
BOLD = "\e[1m"
UNDERLINE = "\e[4m"
RED = "\e[31m"
GREEN = "\e[32m"
YELLOW = "\e[33m"
BLUE = "\e[34m"
MAGENTA = "\e[35m"
CYAN = "\e[36m"
WHITE = "\e[37m"
BG_RED = "\e[41m"
BG_GREEN = "\e[42m"
BG_YELLOW = "\e[43m"
BG_BLUE = "\e[44m"

def print_banner
  puts "#{BOLD}#{GREEN}=============================================#{RESET}"
  puts "#{BOLD}#{CYAN} HackerOS-Steam: Steam Container Manager #{RESET}"
  puts "#{BOLD}#{GREEN}=============================================#{RESET}"
  puts ""
end

def print_success(msg)
  puts "#{GREEN}✔ #{msg}#{RESET}"
end

def print_info(msg)
  puts "#{BLUE}ℹ #{msg}#{RESET}"
end

def print_warning(msg)
  puts "#{YELLOW}⚠ #{msg}#{RESET}"
end

def print_error(msg)
  puts "#{RED}✖ #{msg}#{RESET}"
end

def print_header(title)
  puts "#{BOLD}#{MAGENTA}--- #{title} ---#{RESET}"
end

def run_command(cmd : Array(String), args : Array(String) = [] of String, silent : Bool = false)
  full_cmd = cmd + args
  unless silent
    print_info("Executing: #{full_cmd.join(" ")}")
  end
  process = Process.new(full_cmd[0], full_cmd[1..], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
  status = process.wait
  if !status.success?
    print_error("Command failed: #{full_cmd.join(" ")}")
    exit(1)
  end
end

def container_exists? : Bool
  output_io = IO::Memory.new
  status = Process.run("distrobox", ["list", "--no-color"], output: output_io, error: Process::Redirect::Inherit)
  if !status.success?
    print_error("Failed to list containers.")
    exit(1)
  end
  output = output_io.to_s
  output.includes?(CONTAINER_NAME)
end

def container_running? : Bool
  output_io = IO::Memory.new
  status = Process.run("distrobox", ["list", "--no-color"], output: output_io, error: Process::Redirect::Inherit)
  if !status.success?
    print_error("Failed to list containers.")
    exit(1)
  end
  output = output_io.to_s
  lines = output.lines
  lines.any? { |line| line.includes?(CONTAINER_NAME) && line.includes?("Up") }
end

def create_container(force : Bool = false)
  if container_exists? && !force
    print_warning("Container #{CONTAINER_NAME} already exists. Use --force to recreate.")
    return
  end
  print_header("Creating Container")
  print_info("Creating container #{CONTAINER_NAME} with image #{DISTRO_IMAGE}...")
  run_command(["distrobox", "create", "--name", CONTAINER_NAME, "--image", DISTRO_IMAGE, "--yes"])
  print_info("Enabling multilib in the container...")
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "sed", "-i", "s/^#\\[multilib\\]/\\[multilib\\]/", "/etc/pacman.conf"])
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "sed", "-i", "/^\\[multilib\\]/ {n; s/^#//}", "/etc/pacman.conf"])
  print_info("Refreshing package databases in the container...")
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-Syy", "--noconfirm"])
  print_info("Updating packages in the container...")
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-Syu", "--noconfirm"])
  print_info("Installing Steam, 32-bit libraries, fonts, and additional Vulkan drivers in the container...")
  packages = [
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
    "lib32-vulkan-intel", # For Intel
    "lib32-vulkan-radeon", # For AMD
    "lib32-nvidia-utils", # For NVIDIA
    "lib32-libxss", # Additional for better compatibility
    "lib32-libgpg-error", # Additional
    "lib32-dbus", # Additional
    # Additional fonts
    "noto-fonts",
    "ttf-bitstream-vera",
    "ttf-croscore",
    "ttf-dejavu",
    "ttf-droid",
    "ttf-ibm-plex",
    "ttf-liberation",
    "ttf-roboto",
    # Additional lib32 Vulkan packages
    "lib32-vulkan-freedreno",
    "lib32-vulkan-nouveau",
    "lib32-vulkan-swrast",
    "lib32-vulkan-virtio",
  ]
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-S", "--noconfirm"] + packages)
  print_success("Container created, multilib enabled, Steam with extended 32-bit libraries, fonts, and additional Vulkan drivers installed.")
end

def kill_container
  if !container_exists?
    print_warning("Container #{CONTAINER_NAME} does not exist.")
    return
  end
  print_header("Killing Container")
  print_info("Stopping container #{CONTAINER_NAME}...")
  run_command(["distrobox", "stop", "--name", CONTAINER_NAME, "--yes"])
  print_success("Container stopped.")
end

def remove_container
  if !container_exists?
    print_warning("Container #{CONTAINER_NAME} does not exist.")
    return
  end
  print_header("Removing Container")
  print_info("Removing container #{CONTAINER_NAME}...")
  run_command(["distrobox", "rm", "--name", CONTAINER_NAME, "--force", "--yes"])
  print_success("Container removed.")
end

def update_container
  if !container_exists?
    print_error("Container #{CONTAINER_NAME} does not exist. Create it first.")
    exit(1)
  end
  print_header("Updating Container")
  print_info("Upgrading distrobox container #{CONTAINER_NAME}...")
  run_command(["distrobox-upgrade", CONTAINER_NAME])
  print_info("Updating packages and Steam inside the container...")
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-Syu", "--noconfirm"])
  print_success("Container and packages updated. Steam will update on launch.")
end

def restart_container
  print_header("Restarting Container")
  kill_container
  run_steam([] of String) # This will start the container if stopped
  print_success("Container restarted.")
end

def run_steam(flags : Array(String))
  if !container_exists?
    print_error("Container #{CONTAINER_NAME} does not exist. Create it first.")
    exit(1)
  end
  print_header("Running Steam")
  print_info("Launching Steam in container #{CONTAINER_NAME} with flags: #{flags.join(" ")}")
  steam_args = flags.empty? ? [] of String : flags
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "steam"] + steam_args)
end

def status_container
  print_header("Container Status")
  if !container_exists?
    print_warning("Container #{CONTAINER_NAME} does not exist.")
    return
  end
  running = container_running?
  status_str = running ? "#{GREEN}Running#{RESET}" : "#{YELLOW}Stopped#{RESET}"
  print_info("Container: #{CONTAINER_NAME}")
  print_info("Image: #{DISTRO_IMAGE}")
  print_info("Status: #{status_str}")
  # Get more details
  output_io = IO::Memory.new
  status = Process.run("distrobox", ["list", "--no-color"], output: output_io, error: Process::Redirect::Inherit)
  if !status.success?
    print_error("Failed to list containers.")
    exit(1)
  end
  output = output_io.to_s
  lines = output.lines
  detail_line = lines.find { |line| line.includes?(CONTAINER_NAME) }
  if detail_line
    print_info("Details: #{detail_line.strip}")
  end
end

def list_containers
  print_header("Listing All Containers")
  run_command(["distrobox", "list"])
end

def install_additional_packages(packages : Array(String))
  if !container_exists?
    print_error("Container #{CONTAINER_NAME} does not exist. Create it first.")
    exit(1)
  end
  print_header("Installing Additional Packages")
  print_info("Installing packages: #{packages.join(" ")}")
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-S", "--noconfirm"] + packages)
  print_success("Packages installed.")
end

def print_help(parser : OptionParser)
  puts parser
  puts "Commands:"
  puts " run [flags] Run Steam (supports -gamepadui, -steamos3, -steampal, -steamdeck, etc.)"
  puts " create Create the container"
  puts " kill Kill the container"
  puts " remove Remove the container"
  puts " update Update the container and Steam"
  puts " restart Restart the container and Steam"
  puts " status Check container status"
  puts " list List all containers"
  puts " install PKGS Install additional packages (e.g., install package1 package2)"
  puts " gui Open GUI menu"
end

def main
  print_banner
  command = ""
  flags = [] of String
  force = false
  parser = OptionParser.new do |parser|
    parser.banner = "Usage: HackerOS-Steam [command] [options] [flags]"
    parser.on("--force", "Force operation (e.g., for create)") { force = true }
    parser.on("-h", "--help", "Show this help") do
      print_help(parser)
      exit
    end
    parser.unknown_args do |before, _|
      if !before.empty?
        command = before.shift
        flags = before
      end
    end
  end
  parser.parse
  if command.empty?
    print_help(parser)
    exit(1)
  end
  case command
  when "run"
    run_steam(flags)
  when "create"
    create_container(force)
  when "kill"
    kill_container
  when "remove"
    remove_container
  when "update"
    update_container
  when "restart"
    restart_container
  when "status"
    status_container
  when "list"
    list_containers
  when "install"
    if flags.empty?
      print_error("No packages specified for install.")
      exit(1)
    end
    install_additional_packages(flags)
  when "gui"
    gui_path = "#{ENV["HOME"]? || "~"}/.hackeros/HackerOS-Steam/gui"
    print_info("Launching GUI from #{gui_path}...")
    process = Process.new(gui_path, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    status = process.wait
    if !status.success?
      print_error("Failed to launch GUI.")
      exit(1)
    end
  else
    print_help(parser)
    exit(1)
  end
end

main
