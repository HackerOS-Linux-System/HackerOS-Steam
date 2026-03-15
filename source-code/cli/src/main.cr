require "./colors"
require "./ui"
require "./container"

include Colors

def print_help
  UI.print_banner
  puts "  #{BOLD}#{WHITE}USAGE#{RESET}"
  puts "  #{BRIGHT_BLACK}hackeros-steam #{CYAN}<command> #{BRIGHT_BLACK}[options] [flags]#{RESET}"
  puts ""
  puts "  #{BOLD}#{WHITE}COMMANDS#{RESET}"
  UI.print_divider
  UI.print_help_row("create [--force]",    "Create the Steam container (Arch + multilib + Steam)")
  UI.print_help_row("run [flags...]",      "Launch Steam (e.g. -gamepadui -steamos3 -steamdeck)")
  UI.print_help_row("kill",               "Stop the running container")
  UI.print_help_row("remove",             "Remove the container (asks for confirmation)")
  UI.print_help_row("update",             "Update container OS + all packages")
  UI.print_help_row("restart [flags...]", "Stop then relaunch Steam")
  UI.print_help_row("status",             "Show container state and details")
  UI.print_help_row("list",               "List all distrobox containers")
  UI.print_help_row("install PKG...",     "Install additional Arch packages inside container")
  UI.print_help_row("gui",               "Open the HackerOS-Steam GUI")
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

  when "kill", "stop"
    Container.kill

  when "remove", "rm", "delete"
    Container.remove

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
    gui_path = "#{ENV["HOME"]? || "~"}/.hackeros/HackerOS-Steam/gui"
    UI.print_info("Launching GUI: #{gui_path}")
    status = Process.run(gui_path, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    unless status.success?
      UI.print_error("Failed to launch GUI. Is it installed?")
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
