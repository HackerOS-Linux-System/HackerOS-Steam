require "./colors"
require "./ui"
require "./container"

include Colors

def print_help
  UI.print_banner
  puts "  #{BOLD}#{WHITE}USAGE#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam #{CYAN}<command> #{BRIGHT_BLACK}[options] [flags]#{RESET}"
  puts ""
  puts "  #{BOLD}#{WHITE}COMMANDS#{RESET}"
  UI.print_divider
  UI.print_help_row("create [--force]",    "Create the Steam container (Arch + multilib + Steam)")
  UI.print_help_row("setup",              "Install Steam into an existing container (repair)")
  UI.print_help_row("run [flags...]",      "Launch Steam (e.g. -gamepadui -steamos3 -steamdeck)")
  UI.print_help_row("kill",               "Stop the running container")
  UI.print_help_row("remove",             "Remove the container (asks for confirmation)")
  UI.print_help_row("update",             "Update container OS + all packages")
  UI.print_help_row("restart [flags...]", "Stop then relaunch Steam")
  UI.print_help_row("status",             "Show container state and details")
  UI.print_help_row("list",               "List all distrobox containers")
  UI.print_help_row("install PKG...",     "Install additional Arch packages inside container")
  UI.print_help_row("export",             "Export Steam app entry to host desktop")
  UI.print_help_row("logs [N]",           "Show last N lines of Steam logs (default: 50)")
  UI.print_help_row("shell",              "Open an interactive shell inside the container")
  UI.print_help_row("gui",               "Launch GTK4 GUI  (/usr/share/HackerOS/Scripts/Steam/bin/gui)")
  UI.print_help_row("tui",               "Launch terminal TUI  (/usr/share/HackerOS/Scripts/Steam/bin/tui)")
  UI.print_divider
  puts ""
  puts "  #{BOLD}#{WHITE}EXAMPLES#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam create#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam create --force#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam run -gamepadui#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam install mangohud lib32-mangohud#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam logs 100#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam shell#{RESET}"
  puts ""
end

def launch_external(path : String, name : String)
  UI.print_info("Launching #{name}: #{path}")
  unless File.executable?(path)
    UI.print_error("#{name} binary not found or not executable: #{path}")
    exit(1)
  end
  status = Process.run(path, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
  unless status.success?
    UI.print_error("#{name} exited with error.")
    exit(1)
  end
end

def main
  args = ARGV.dup
  force = args.delete("--force") != nil
  help  = args.delete("--help") != nil || args.delete("-h") != nil

  if help || args.empty?
    print_help
    exit(args.empty? && !help ? 1 : 0)
  end

  command = args.shift
  rest    = args

  UI.print_banner

  case command
  when "create"
    Container.create(force: force)
  when "run"
    Container.run_steam(rest)
  when "setup"
    Container.setup
  when "kill", "stop"
    Container.kill
  when "remove", "rm", "delete"
    Container.remove(ask: !force)
  when "update", "upgrade"
    Container.update
  when "restart"
    Container.restart(rest)
  when "status"
    Container.status
  when "list", "ls"
    Container.list
  when "install"
    if rest.empty?
      UI.print_error("No packages specified. Usage:  HackerOS-Steam install PKG [PKG...]")
      exit(1)
    end
    Container.install_packages(rest)
  when "export"
    Container.export_app
  when "logs"
    lines = rest.first?.try(&.to_i?) || 50
    Container.logs(lines)
  when "shell", "sh"
    Container.shell
  when "gui"
    launch_external("/usr/share/HackerOS/Scripts/Steam/bin/gui", "GUI")
  when "tui"
    launch_external("/usr/share/HackerOS/Scripts/Steam/bin/tui", "TUI")
  else
    UI.print_error("Unknown command: '#{command}'")
    puts ""
    print_help
    exit(1)
  end
end

main
