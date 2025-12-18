require "file_utils"
require "path"
require "process"
require "option_parser"
require "log"

lib LibC
  fun getuid : UInt32
  fun getgid : UInt32
end

CONTAINER_NAME = "hackerosteam"
RELEASE = "43"

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

def get_data_dir : Path
  xdg = ENV["XDG_DATA_HOME"]?
  base = if xdg
           Path.new(xdg)
         else
           Path.new(ENV["HOME"]? || raise "Brak HOME").join(".local/share")
         end.join("hackerosteam")
end

def get_host_data_dirs : {Path, Path, Path, Path}
  base = get_data_dir
  FileUtils.mkdir_p(base.to_s)
  empty = base.join("empty")
  FileUtils.mkdir_p(empty.to_s)
  upper = base.join("upper")
  FileUtils.mkdir_p(upper.to_s)
  work = base.join("work")
  FileUtils.mkdir_p(work.to_s)
  {base, upper, work, empty}
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

def check_gpu_drivers : Bool
  unless File.exists?("/dev/dri")
    raise ContainerError.new(ContainerError::Kind::NoGpu)
  end
  is_nvidia = File.exists?("/dev/nvidia0")
  if is_nvidia
    unless system("which nvidia-container-toolkit > /dev/null 2>&1")
      raise ContainerError.new(ContainerError::Kind::NvidiaMissing)
    end
    Log.info { "NVIDIA wykryte – używamy nvidia-container-runtime" }
  else
    Log.info { "GPU: Intel/AMD (Mesa) – pełna akceleracja" }
  end
  is_nvidia
end

def ensure_overlay
  _base, upper, work, _empty = get_host_data_dirs
  is_empty = true
  if File.directory?(upper.to_s)
    Dir.each_child(upper.to_s) do |child|
      is_empty = false
      break
    end
  end
  if !File.directory?(upper.to_s) || is_empty
    Log.info { "Inicjalizacja overlayfs dla Steam..." }
    FileUtils.mkdir_p(upper.to_s)
    FileUtils.mkdir_p(work.to_s)
  end
end

def create_container
  is_nvidia = check_gpu_drivers
  display = detect_display_server
  if display == "none"
    raise ContainerError.new(ContainerError::Kind::NoDisplay)
  end
  container_root = get_container_root
  _base, upper, work, empty = get_host_data_dirs
  ensure_overlay
  uid = LibC.getuid
  gid = LibC.getgid
  if File.exists?(container_root.join("etc").to_s)
    Log.info { "Kontener już istnieje – pomijamy tworzenie." }
    return
  end
  FileUtils.mkdir_p(container_root.to_s)
  Log.info { "Tworzenie bezpiecznego kontenera Steam..." }
  dnf_args = [
    "dnf",
    "--installroot", container_root.to_s,
    "--releasever", RELEASE,
    "--assumeyes",
    "--setopt", "install_weak_deps=False",
    "install",
    "fedora-release-container",
    "bash",
    "dnf",
    "glibc-minimal-langpack",
    "util-linux",
    "shadow-utils",
  ]
  status = Process.new("sudo", args: dnf_args, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
  unless status.success?
    raise "Błąd instalowania base system"
  end
  install_cmd = <<-CMD
  dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm &&
  dnf update -y &&
  packages="steam gamescope vulkan-tools pipewire-pulseaudio gamemode bzip2-libs bzip2-libs.i686 glibc-langpack-en util-linux" &&
  dnf install -y $packages &&
  ln -s $(readlink -f /usr/lib/libbz2.so.1) /usr/lib/libbz2.so.1.0 || true &&
  ln -s $(readlink -f /usr/lib64/libbz2.so.1) /usr/lib64/libbz2.so.1.0 || true &&
  [ -f /etc/gshadow ] || touch /etc/gshadow &&
  chmod 600 /etc/gshadow || true &&
  gid=#{gid} &&
  uid=#{uid} &&
  group_name="steamgroup" &&
  user_name="steam" &&
  if getent passwd $uid >/dev/null; then
      existing_user=$(getent passwd $uid | cut -d: -f1)
      userdel -r $existing_user || true
  fi &&
  if getent group $gid >/dev/null; then
      existing_group=$(getent group $gid | cut -d: -f1)
      groupdel $existing_group || true
  fi &&
  groupadd -g $gid $group_name || true &&
  useradd -m -u $uid -g $gid $user_name || true &&
  mkdir -p /home/steam/.steam || true &&
  chown -R $uid:$gid /home/steam || true &&
  echo "Kontener Steam gotowy!"
  CMD
  spawn_args = [
    "systemd-nspawn",
    "-D", container_root.to_s,
    "--quiet",
    "/bin/bash",
    "-c", install_cmd,
  ]
  status = Process.new("sudo", args: spawn_args, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
  unless status.success?
    raise "Błąd tworzenia kontenera"
  end
  Log.info { "Kontener #{CONTAINER_NAME} utworzony!" }
end

def run_container(session : String?)
  container_root = get_container_root
  is_nvidia = check_gpu_drivers
  display = detect_display_server
  if display == "none"
    raise ContainerError.new(ContainerError::Kind::NoDisplay)
  end
  uid = LibC.getuid
  gid = LibC.getgid
  run_user = "/run/user/#{uid}"
  _base, upper, work, empty = get_host_data_dirs
  mount_overlay = "mkdir -p /home/steam && mount -t overlay overlay -o lowerdir=#{empty},upperdir=#{upper},workdir=#{work} /home/steam && chown #{uid}:#{gid} /home/steam"
  session_cmd = if session == "gamescope-session-steam" || session == "deck"
                  "rm -f ~/.steam/steam.pid ~/.steam/.crash && gamescope -e -- steam -gamepadui"
                else
                  "rm -f ~/.steam/steam.pid ~/.steam/.crash && steam"
                end
  exec_cmd = "#{mount_overlay} && su - steam -c '#{session_cmd}'"
  Log.info { "Uruchamianie: #{session_cmd}" }
  nspawn_args = [
    "systemd-nspawn",
    "-D", container_root.to_s,
    "--quiet",
    "--private-users=no",
    "--network-namespace-path=/proc/1/ns/net",
    "--ipc-namespace-path=/proc/1/ns/ipc",
    "--pid-namespace-path=/proc/1/ns/pid",
    "--uts-namespace-path=/proc/1/ns/uts",
    "--no-new-privileges=yes",
    "--capability=SYS_NICE",
    "--capability=IPC_LOCK",
    "--property=CPUQuota=90%",
    "--property=MemoryMax=17179869184",
    "--property=TasksMax=4096",
    "--property=IOWeight=1000",
    "--property=DeviceAllow=char-226 rwm",
    "--property=DeviceAllow=char-116 rwm",
    "--property=DeviceAllow=char-13 rwm",
  ]
  binds = [
    "--bind=/tmp/.X11-unix:/tmp/.X11-unix",
    "--bind=#{run_user}:#{run_user}",
    "--bind=#{upper}:/mnt/upper",
    "--bind=#{work}:/mnt/work",
    "--bind=#{empty}:/mnt/empty",
    "--bind=/dev/dri:/dev/dri",
    "--bind=/dev/snd:/dev/snd",
    "--bind=/dev/input:/dev/input",
  ]
  if File.exists?("/usr/share/vulkan")
    binds << "--bind-ro=/usr/share/vulkan:/usr/share/vulkan"
  end
  if File.exists?("/usr/share/glvnd")
    binds << "--bind-ro=/usr/share/glvnd:/usr/share/glvnd"
  end
  if File.exists?("/usr/share/drirc.d")
    binds << "--bind-ro=/usr/share/drirc.d:/usr/share/drirc.d"
  end
  unless is_nvidia
    if File.exists?("/usr/lib64/dri")
      binds << "--bind-ro=/usr/lib64/dri:/usr/lib64/dri"
    end
    if File.exists?("/usr/lib/dri")
      binds << "--bind-ro=/usr/lib/dri:/usr/lib/dri"
    end
  else
    nspawn_args << "--property=DeviceAllow=char-195 rwm"
    nspawn_args << "--property=DeviceAllow=char-235 rwm"
    devs = ["/dev/nvidia0", "/dev/nvidiactl", "/dev/nvidia-modeset", "/dev/nvidia-uvm", "/dev/nvidia-uvm-tools"]
    devs.each do |dev|
      if File.exists?(dev)
        binds << "--bind=#{dev}:#{dev}"
      end
    end
    lib_dirs = ["/usr/lib64", "/usr/lib"]
    lib_dirs.each do |lib_dir|
      if File.directory?(lib_dir)
        Dir.each_child(lib_dir) do |entry|
          path = Path.new(lib_dir).join(entry)
          filename = entry
          if filename.starts_with?("libnvidia-") || filename.starts_with?("libcuda") || filename.starts_with?("libnvrtc") ||
             filename.starts_with?("libGLX_nvidia") || filename.starts_with?("libEGL_nvidia") ||
             filename.starts_with?("libGLESv1_CM_nvidia") || filename.starts_with?("libGLESv2_nvidia")
            binds << "--bind-ro=#{path}:#{path}"
          end
        end
      end
    end
    bin_dir = "/usr/bin"
    if File.directory?(bin_dir)
      Dir.each_child(bin_dir) do |entry|
        if entry.starts_with?("nvidia-")
          path = Path.new(bin_dir).join(entry)
          binds << "--bind-ro=#{path}:#{path}"
        end
      end
    end
    if File.exists?("/etc/OpenCL/vendors/nvidia.icd")
      binds << "--bind-ro=/etc/OpenCL/vendors/nvidia.icd:/etc/OpenCL/vendors/nvidia.icd"
    end
  end
  nspawn_args += binds
  envs = [
    "PULSE_SERVER=unix:#{run_user}/pulse/native",
    "STEAMOS=1",
    "STEAM_RUNTIME=1",
    "XDG_RUNTIME_DIR=#{run_user}",
    "DBUS_SESSION_BUS_ADDRESS=unix:path=#{run_user}/bus",
    "LANG=en_US.UTF-8",
    "IS_NVIDIA=#{is_nvidia ? "true" : "false"}",
  ]
  if display == "x11"
    envs << "DISPLAY=#{ENV["DISPLAY"]? || ":0"}"
  end
  if display == "wayland"
    envs << "WAYLAND_DISPLAY=#{ENV["WAYLAND_DISPLAY"]? || "wayland-0"}"
  end
  if is_nvidia
    envs << "NVIDIA_VISIBLE_DEVICES=all"
    envs << "NVIDIA_DRIVER_CAPABILITIES=all"
    envs << "__GLX_VENDOR_LIBRARY_NAME=nvidia"
  end
  envs.each do |e|
    nspawn_args += ["-E", e]
  end
  nspawn_args += ["--console=interactive"]
  nspawn_args += ["--"]
  nspawn_args += ["/bin/bash"]
  nspawn_args += ["-c"]
  nspawn_args += [exec_cmd]
  status = Process.new("sudo", args: nspawn_args, input: Process::Redirect::Inherit, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
  unless status.success?
    raise "Błąd uruchamiania kontenera"
  end
end

def main
  Log.setup("stdout", Log::Severity::Info)
  command = nil
  session = nil : String?
  parser = OptionParser.new do |parser|
    parser.banner = "Usage: hackerosteam [command]"
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
    container_root = get_container_root
    update_args = [
      "systemd-nspawn",
      "-D", container_root.to_s,
      "--quiet",
      "/bin/bash",
      "-c", "dnf update -y",
    ]
    Process.new("sudo", args: update_args, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit).wait
    Log.info { "Obraz zaktualizowany. Uruchom `hackerosteam remove && hackerosteam create` aby zainstalować nowe pakiety." }
  when Command::Kill
    container_root = get_container_root
    pattern = "systemd-nspawn -D #{container_root}"
    Process.new("sudo", args: ["pkill", "-f", pattern]).wait
    Log.info { "Steam zatrzymany." }
  when Command::Restart
    container_root = get_container_root
    pattern = "systemd-nspawn -D #{container_root}"
    Process.new("sudo", args: ["pkill", "-f", pattern]).wait
    Log.warn { "Kontener zrestartowany – dane w overlayfs zachowane!" }
    run_container(nil)
  when Command::Remove
    container_root = get_container_root
    Process.new("sudo", args: ["rm", "-rf", container_root.to_s]).wait
    Log.info { "Kontener usunięty." }
  when Command::Status
    container_root = get_container_root
    output = `ps -ef --forest`
    found = false
    output.lines.each do |line|
      if line.includes?(container_root.to_s)
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
