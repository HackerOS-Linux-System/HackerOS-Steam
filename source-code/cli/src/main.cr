require "file_utils"
require "path"
require "process"
require "option_parser"
require "log"

CONTAINER_NAME = "HackerOS-Steam"

class ContainerError < Exception
  enum Kind
    NoGpu
    NoDisplay
    NvidiaMissing
  end

  getter kind : Kind

  def initialize(@kind)
  end

  def message
    case @kind
    when .no_gpu?
      "Brak sterowników GPU (brak /dev/dri)"
    when .no_display?
      "Nie znaleziono sesji graficznej (X11/Wayland)"
    when .nvidia_missing?
      "NVIDIA wykryte, ale brak sterowników (nvidia-container-toolkit)"
    else
      "Unknown error"
    end
  end
end

enum Command
  Create
  Run
  Update
  Kill
  Restart
  Remove
  Status
end

struct Cli
  property command : Command
  property session : String?

  def initialize(@command, @session = nil)
  end
end

def get_container_root : Path
  home = ENV["HOME"]? || raise "Brak zmiennej HOME"
  Path.new(home).join(".hackeros").join("HackerOS-Steam")
end

def detect_display_server : String
  if ENV["WAYLAND_DISPLAY"]?
    "wayland"
  elsif ENV["DISPLAY"]?
    "x11"
  else
    "none"
  end
end

def check_nvidia : Bool
  if File.exists?("/dev/nvidia0")
    if system("which nvidia-container-toolkit > /dev/null 2>&1")
      Log.info { "NVIDIA wykryte – używamy --nvidia" }
      true
    else
      Log.warn { "NVIDIA wykryte, ale brak nvidia-container-toolkit – wyłączanie wsparcia NVIDIA" }
      false
    end
  else
    false
  end
end

def check_gpu : Bool
  has_gpu = File.exists?("/dev/dri")
  if has_gpu && !File.exists?("/dev/nvidia0")
    Log.info { "GPU: Intel/AMD (Mesa) – pełna akceleracja" }
  end
  has_gpu
end

def create_container
  is_nvidia = check_nvidia
  container_root = get_container_root
  home_dir = container_root.join("home")
  FileUtils.mkdir_p(container_root.to_s)

  if system("distrobox list | grep -q #{CONTAINER_NAME}")
    Log.info { "Kontener już istnieje – pomijamy tworzenie." }
    return
  end

  Log.info { "Tworzenie bezpiecznego kontenera Steam z Distrobox + Arch Linux..." }
  create_args = [
    "distrobox-create",
    "--name", CONTAINER_NAME,
    "--image", "archlinux",
    "--home", home_dir.to_s,
    "--init",
  ]
  if is_nvidia
    create_args << "--nvidia"
  end
  status = Process.new(create_args[0], args: create_args[1..], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
  unless status.success?
    raise "Błąd tworzenia kontenera"
  end

  install_cmd = <<-CMD
  sudo sed -i "/\\[multilib\\]/,/Include/"'s/#//' /etc/pacman.conf &&
  sudo pacman -Syu --noconfirm &&
  sudo pacman -S --noconfirm steam gamescope vulkan-tools pipewire-pulse gamemode bzip2 lib32-bzip2 util-linux base-devel git &&
  sudo sed -i '/^#en_US.UTF-8 UTF-8/s/^#//' /etc/locale.gen &&
  sudo locale-gen &&
  echo "LANG=en_US.UTF-8" | sudo tee /etc/locale.conf &&
  cd /tmp &&
  git clone https://aur.archlinux.org/yay.git &&
  cd yay &&
  makepkg -si --noconfirm &&
  yay -S --noconfirm steam-tui &&
  echo "Kontener Steam gotowy!"
  CMD

  enter_args = [
    "distrobox-enter",
    CONTAINER_NAME,
    "--",
    "bash",
    "-c",
    install_cmd,
  ]
  status = Process.new(enter_args[0], args: enter_args[1..], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
  unless status.success?
    raise "Błąd instalowania pakietów w kontenerze"
  end

  # Tworzenie skryptów gui i tui
  gui_path = container_root.join("gui")
  File.write(gui_path.to_s, "#!/bin/sh\nHackerOS-Steam run\n")
  File.chmod(gui_path.to_s, 0o755)

  tui_path = container_root.join("tui")
  File.write(tui_path.to_s, "#!/bin/sh\nHackerOS-Steam run --session tui\n")
  File.chmod(tui_path.to_s, 0o755)

  Log.info { "Kontener #{CONTAINER_NAME} utworzony!" }
end

def run_container(session : String?)
  display = detect_display_server
  if session != "tui"
    unless check_gpu
      raise ContainerError.new(ContainerError::Kind::NoGpu)
    end
    if File.exists?("/dev/nvidia0") && !system("which nvidia-container-toolkit > /dev/null 2>&1")
      raise ContainerError.new(ContainerError::Kind::NvidiaMissing)
    end
    if display == "none"
      raise ContainerError.new(ContainerError::Kind::NoDisplay)
    end
  end

  exec_cmd = "rm -f ~/.steam/steam.pid ~/.steam/.crash"
  if session == "tui"
    exec_cmd += " && steam-tui"
  elsif session == "deck" || session == "gamescope-session-steam"
    exec_cmd += " && gamescope -e -- steam -gamepadui"
  else
    exec_cmd += " && steam"
  end

  Log.info { "Uruchamianie: #{exec_cmd}" }
  enter_args = [
    "distrobox-enter",
    CONTAINER_NAME,
    "--",
    "bash",
    "-c",
    exec_cmd,
  ]
  status = Process.new(enter_args[0], args: enter_args[1..], input: Process::Redirect::Inherit, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
  unless status.success?
    raise "Błąd uruchamiania kontenera"
  end
end

def main
  Log.setup("stdout", Log::Severity::Info)
  command = nil
  session = nil : String?
  parser = OptionParser.new do |parser|
    parser.banner = "Usage: HackerOS-Steam [command]"
    parser.on("create", "Create container") { command = Command::Create }
    parser.on("run", "Run container") do
      parser.on("--session SESSION", "Session type") { |s| session = s }
      command = Command::Run
    end
    parser.on("update", "Update container") { command = Command::Update }
    parser.on("kill", "Kill container") { command = Command::Kill }
    parser.on("restart", "Restart container") { command = Command::Restart }
    parser.on("remove", "Remove container") { command = Command::Remove }
    parser.on("status", "Status container") { command = Command::Status }
    parser.on("-h", "--help", "Show this help") do
      puts parser
      exit 0
    end
    parser.invalid_option do |flag|
      STDERR.puts "Invalid option: #{flag}."
      STDERR.puts parser
      exit 1
    end
  end
  parser.parse
  if command.nil?
    puts parser
    exit 1
  end
  case command
  when Command::Create
    create_container
  when Command::Run
    create_container
    run_container(session)
  when Command::Update
    update_args = [
      "distrobox-enter",
      CONTAINER_NAME,
      "--",
      "bash",
      "-c",
      "sudo pacman -Syu --noconfirm && yay -Syu --noconfirm",
    ]
    Process.new(update_args[0], args: update_args[1..], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
    Log.info { "Kontener zaktualizowany." }
  when Command::Kill
    Process.new("distrobox-stop", args: [CONTAINER_NAME, "--yes"], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
    Log.info { "Steam zatrzymany." }
  when Command::Restart
    Process.new("distrobox-stop", args: [CONTAINER_NAME, "--yes"], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
    Log.warn { "Kontener zrestartowany – dane zachowane!" }
    run_container(nil)
  when Command::Remove
    Process.new("distrobox-rm", args: ["--force", CONTAINER_NAME], output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
    Log.info { "Kontener usunięty (dane w home zachowane)." }
  when Command::Status
    output = `distrobox list`
    found = false
    output.lines.each do |line|
      if line.includes?(CONTAINER_NAME)
        puts line
        found = true
      end
    end
    puts "Kontener nie istnieje." unless found
  end
rescue ex
  Log.error { ex.message }
  exit 1
end

main
