require "libui"

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

def gui_mode
  o = UI::InitOptions.new
  err = UI.init(pointerof(o))
  if !err.null?
    puts "Error initializing UI: #{String.new(err.as(Pointer(UInt8)))}"
    exit(1)
  end
  window = UI.new_window("HackerOS-Steam GUI", 400, 300, 1)
  vbox = UI.new_vertical_box
  UI.window_set_child(window, vbox.as(Pointer(UI::Control)))
  btn_run = UI.new_button("Run Steam")
  UI.button_on_clicked(btn_run, ->(sender : Pointer(UI::Button), data : Pointer(Void)) {
    # For simplicity, no flags input in GUI; can add later
    run_steam([] of String)
  }, Pointer(Void).null)
  UI.box_append(vbox, btn_run.as(Pointer(UI::Control)), 1)
  btn_create = UI.new_button("Create Container")
  UI.button_on_clicked(btn_create, ->(sender : Pointer(UI::Button), data : Pointer(Void)) { create_container }, Pointer(Void).null)
  UI.box_append(vbox, btn_create.as(Pointer(UI::Control)), 1)
  btn_kill = UI.new_button("Kill Container")
  UI.button_on_clicked(btn_kill, ->(sender : Pointer(UI::Button), data : Pointer(Void)) { kill_container }, Pointer(Void).null)
  UI.box_append(vbox, btn_kill.as(Pointer(UI::Control)), 1)
  btn_update = UI.new_button("Update Container")
  UI.button_on_clicked(btn_update, ->(sender : Pointer(UI::Button), data : Pointer(Void)) { update_container }, Pointer(Void).null)
  UI.box_append(vbox, btn_update.as(Pointer(UI::Control)), 1)
  btn_restart = UI.new_button("Restart Container")
  UI.button_on_clicked(btn_restart, ->(sender : Pointer(UI::Button), data : Pointer(Void)) { restart_container }, Pointer(Void).null)
  UI.box_append(vbox, btn_restart.as(Pointer(UI::Control)), 1)
  btn_exit = UI.new_button("Exit")
  UI.button_on_clicked(btn_exit, ->(sender : Pointer(UI::Button), data : Pointer(Void)) { UI.control_destroy(data.as(Pointer(UI::Control))); UI.quit }, window.as(Pointer(Void)))
  UI.box_append(vbox, btn_exit.as(Pointer(UI::Control)), 1)
  UI.window_on_closing(window, ->(sender : Pointer(UI::Window), data : Pointer(Void)) { UI.control_destroy(sender.as(Pointer(UI::Control))); UI.quit; 1 }, Pointer(Void).null)
  UI.control_show(window.as(Pointer(UI::Control)))
  UI.main
  UI.uninit
end

gui_mode if __FILE__ == Process.executable_path
