require "option_parser"

CONTAINER_NAME = "HackerOS-Steam"
DISTRO_IMAGE = "archlinux:latest"

def run_command(cmd : Array(String), args : Array(String) = [] of String)
  full_cmd = cmd + args
  process = Process.new(full_cmd[0], full_cmd[1..], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
  status = process.wait
  if !status.success?
    puts "Command failed: #{full_cmd.join(" ")}"
    exit(1)
  end
end

def create_container
  puts "Creating container #{CONTAINER_NAME}..."
  run_command(["distrobox", "create", "--name", CONTAINER_NAME, "--image", DISTRO_IMAGE, "--yes"])
  puts "Enabling multilib in the container..."
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "sed", "-i", "/\\[multilib\\]/,/Include/s/^#//", "/etc/pacman.conf"])
  puts "Updating packages in the container..."
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-Syu", "--noconfirm"])
  puts "Installing Steam and 32-bit libraries in the container..."
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
    "lib32-vulkan-radeon" # For AMD
  ]
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-S", "--noconfirm"] + packages)
  puts "Container created, multilib enabled, and Steam with 32-bit libraries installed."
end

def kill_container
  puts "Killing container #{CONTAINER_NAME}..."
  run_command(["distrobox", "stop", "--name", CONTAINER_NAME, "--yes"])
end

def update_container
  puts "Updating container #{CONTAINER_NAME}..."
  run_command(["distrobox-upgrade", CONTAINER_NAME])
  puts "Updating packages and Steam inside the container..."
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "sudo", "pacman", "-Syu", "--noconfirm"])
  # Steam updates itself on launch
end

def restart_container
  kill_container
  run_steam([] of String) # This will start the container if stopped
end

def run_steam(flags : Array(String))
  puts "Running Steam in container #{CONTAINER_NAME}..."
  steam_args = flags.empty? ? [] of String : flags
  run_command(["distrobox", "enter", CONTAINER_NAME, "--", "steam"] + steam_args)
end

def main
  command = ARGV.shift? || ""
  flags = ARGV
  case command
  when "run"
    run_steam(flags)
  when "create"
    create_container
  when "kill"
    kill_container
  when "update"
    update_container
  when "restart"
    restart_container
  when "gui"
    gui_path = "#{ENV["HOME"]}/.hackeros/HackerOS-Steam/gui"
    puts "Launching GUI from #{gui_path}..."
    process = Process.new(gui_path, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    status = process.wait
    if !status.success?
      puts "Failed to launch GUI."
      exit(1)
    end
  else
    puts "Usage: HackerOS-Steam [command] [flags]"
    puts "Commands:"
    puts " run [flags] - Run Steam (supports -gamepadui, -steamos3, -steampal, -steamdeck)"
    puts " create - Create the container"
    puts " kill - Kill the container"
    puts " update - Update the container and Steam"
    puts " restart - Restart the container and Steam"
    puts " gui - Open GUI menu"
    exit(1)
  end
end

main if __FILE__ == Process.executable_path
