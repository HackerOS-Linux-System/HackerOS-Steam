require "option_parser"

module HackerOSSteamCLI
  VERSION = "0.1.0"

  def self.main
    home = ENV["HOME"]? || "/home/#{`whoami`.strip}"
    container_bin = "#{home}/.hackeros/HackerOS-Steam/container"
    tui_bin = "#{home}/.hackeros/HackerOS-Steam/tui"
    gui_bin = "#{home}/.hackeros/HackerOS-Steam/gui"

    command = ""
    session = ""

    parser = OptionParser.new do |p|
      p.banner = "Użycie: HackerOS-Steam [komenda] [opcje]\n\nKomendy:"

      p.on "run [SESSION]", "Uruchamia Steam (opcjonalnie z sesją gamescope-session-steam)" do |s|
        command = "run"
        session = s || ""
      end

      p.on "update", "Aktualizuje kontener Fedory i pakiety" do
        command = "update"
      end

      p.on "kill", "Wyłącza Steam na siłę" do
        command = "kill"
      end

      p.on "create", "Tworzy kontener" do
        command = "create"
      end

      p.on "restart", "Restartuje kontener (użytkownik traci dane w kontenerze)" do
        command = "restart"
      end

      p.on "remove", "Usuwa kontener" do
        command = "remove"
      end

      p.on "tui", "Uruchamia interfejs TUI" do
        command = "tui"
      end

      p.on "gui", "Uruchamia interfejs GUI" do
        command = "gui"
      end

      p.on "-h", "--help", "Wyświetla pomoc" do
        puts p
        exit
      end

      p.on "-v", "--version", "Wyświetla wersję" do
        puts "HackerOS-Steam CLI v#{VERSION}"
        exit
      end
    end

    begin
      parser.parse
    rescue ex : OptionParser::InvalidOption
      puts "Błąd: #{ex.message}"
      puts parser
      exit 1
    end

    case command
    when "run"
      args = ["run"]
      args << session unless session.empty?
      spawn_process(container_bin, args)
    when "update"
      spawn_process(container_bin, ["update"])
    when "kill"
      spawn_process(container_bin, ["kill"])
    when "create"
      spawn_process(container_bin, ["create"])
    when "restart"
      spawn_process(container_bin, ["restart"])
    when "remove"
      spawn_process(container_bin, ["remove"])
    when "tui"
      spawn_process(tui_bin, [] of String)
    when "gui"
      spawn_process(gui_bin, [] of String)
    else
      puts "Nieznana komenda. Użyj --help po więcej informacji."
      exit 1
    end
  end

  private def self.spawn_process(bin : String, args : Array(String))
    unless File.exists?(bin)
      puts "Błąd: Binarka #{bin} nie istnieje!"
      exit 1
    end

    process = Process.new(bin, args, output: Process::Redirect::Inherit, error: Process::Redirect::Inherit)
    status = process.wait

    if !status.success?
      puts "Błąd wykonania: #{status.exit_status}"
      exit status.exit_status
    end
  end
end

HackerOSSteamCLI.main
