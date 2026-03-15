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
  UI.print_help_row("gui",               "Launch GTK4 GUI  (/usr/share/HackerOS/Scripts/Steam/bin/gui)")
  UI.print_help_row("tui",               "Launch terminal TUI  (/usr/share/HackerOS/Scripts/Steam/bin/tui)")
  UI.print_divider
  puts ""
  puts "  #{BOLD}#{WHITE}EXAMPLES#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam create#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam create --force#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam run -gamepadui#{RESET}"
  puts "  #{BRIGHT_BLACK}HackerOS-Steam install mangohud lib32-mangohud#{RESET}"
  puts ""
end

def main
  args = ARGV.dup

  # Pull out global flags first
  force = args.delete("--force") != nil
  help  = args.delete("--help") != nil || args.delete("-h") != nil

  if help || args.empty?
    print_help
    exit(args.empty? && !help ? 1 : 0)
  end

  command = args.shift
  rest    = args   # remaining args are either sub-flags or package names

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

  when "gui"
    gui_path = "/usr/share/HackerOS/Scripts/Steam/bin/gui"
    UI.print_info("Launching GUI: #{gui_path}")
    unless File.executable?(gui_path)
      UI.print_error("GUI binary not found or not executable: #{gui_path}")
      exit(1)
    end
    status = Process.run(gui_path, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    unless status.success?
      UI.print_error("GUI exited with error.")
      exit(1)
    end

  when "tui"
    tui_path = "/usr/share/HackerOS/Scripts/Steam/bin/tui"
    UI.print_info("Launching TUI: #{tui_path}")
    unless File.executable?(tui_path)
      UI.print_error("TUI binary not found or not executable: #{tui_path}")
      exit(1)
    end
    status = Process.run(tui_path, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    unless status.success?
      UI.print_error("TUI exited with error.")
      exit(1)
    end

  else
    UI.print_error("Unknown command: '#{command}'")
    puts ""
    print_help
    exit(1)
  end
end

main
