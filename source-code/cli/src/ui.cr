require "./colors"

module UI
  include Colors

  BANNER = <<-BANNER
  #{BOLD}#{BRIGHT_CYAN}
  ██╗  ██╗ █████╗  ██████╗██╗  ██╗███████╗██████╗  ██████╗ ███████╗
  ██║  ██║██╔══██╗██╔════╝██║ ██╔╝██╔════╝██╔══██╗██╔═══██╗██╔════╝
  ███████║███████║██║     █████╔╝ █████╗  ██████╔╝██║   ██║███████╗
  ██╔══██║██╔══██║██║     ██╔═██╗ ██╔══╝  ██╔══██╗██║   ██║╚════██║
  ██║  ██║██║  ██║╚██████╗██║  ██╗███████╗██║  ██║╚██████╔╝███████║
  ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝#{RESET}
  BANNER

  def self.print_banner
    puts BANNER
    term_width = 72
    subtitle = "  Steam Container Manager — powered by Distrobox + Arch Linux"
    padding = [0, (term_width - subtitle.size) // 2].max
    puts "#{BOLD}#{BRIGHT_BLACK}#{"─" * 72}#{RESET}"
    puts "#{" " * padding}#{BRIGHT_MAGENTA}#{BOLD}#{subtitle}#{RESET}"
    puts "#{BOLD}#{BRIGHT_BLACK}#{"─" * 72}#{RESET}"
    puts ""
  end

  def self.print_success(msg)
    puts "  #{BOLD}#{BRIGHT_GREEN}✔#{RESET}  #{WHITE}#{msg}#{RESET}"
  end

  def self.print_info(msg)
    puts "  #{BOLD}#{BRIGHT_BLUE}→#{RESET}  #{BRIGHT_BLACK}#{msg}#{RESET}"
  end

  def self.print_warning(msg)
    puts "  #{BOLD}#{BRIGHT_YELLOW}⚠#{RESET}  #{YELLOW}#{msg}#{RESET}"
  end

  def self.print_error(msg)
    puts "  #{BOLD}#{BRIGHT_RED}✖#{RESET}  #{RED}#{msg}#{RESET}"
  end

  def self.print_header(title)
    puts ""
    puts "  #{BOLD}#{BRIGHT_CYAN}┌─ #{title.upcase} #{BRIGHT_BLACK}#{"─" * [0, 50 - title.size].max}#{RESET}"
    puts ""
  end

  def self.print_step(step : Int32, total : Int32, msg : String)
    pct = total > 0 ? (step * 100 // total) : 0
    bar_filled = pct * 20 // 100
    bar = "#{BRIGHT_GREEN}#{"█" * bar_filled}#{BRIGHT_BLACK}#{"░" * (20 - bar_filled)}#{RESET}"
    puts "  #{BOLD}#{BRIGHT_BLACK}[#{BRIGHT_CYAN}#{step.to_s.rjust(2)}/#{total}#{BRIGHT_BLACK}]#{RESET} #{bar} #{BRIGHT_BLACK}#{pct}%#{RESET}  #{WHITE}#{msg}#{RESET}"
  end

  def self.print_status_row(label : String, value : String, color : String = WHITE)
    puts "  #{BRIGHT_BLACK}#{label.ljust(18)}#{RESET} #{color}#{value}#{RESET}"
  end

  def self.print_divider
    puts "  #{BRIGHT_BLACK}#{"─" * 68}#{RESET}"
  end

  def self.print_help_row(cmd : String, desc : String)
    puts "  #{BOLD}#{BRIGHT_CYAN}#{cmd.ljust(22)}#{RESET} #{BRIGHT_BLACK}#{desc}#{RESET}"
  end

  def self.confirm?(prompt : String) : Bool
    print "  #{BOLD}#{BRIGHT_YELLOW}?#{RESET}  #{WHITE}#{prompt} #{BRIGHT_BLACK}[y/N]#{RESET} "
    response = STDIN.gets.try(&.strip.downcase) || "n"
    response == "y" || response == "yes"
  end
end
