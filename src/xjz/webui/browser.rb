require 'open3'
require 'shellwords'

module Xjz
  class WebUI::Browser
    attr_reader :app_out, :app_err, :app_process
    BROWSERS = {
      osx: {
        chrome: [
          Shellwords.escape("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        ]
      },
      windows: {
        chrome: [
          'C:\Program Files (x86)\Google\Chrome\Application\chrome.exe'
        ]
      },
      linux: {
      }
    }

    def initialize
      @app_out, @app_err, @app_process = nil
    end

    def open(url)
      return true if try_open_by_chrome(url)
      return true if try_open_by_browser(url)

      Logger[:auto].error { "You must have google-chrome installed and accesible via your path." }
      false
    end

    def system_name
      @system_name ||= case RbConfig::CONFIG['host_os']
      when /darwin|mac os/ then :osx
      when /cygwin|mswin|mingw/ then :windows
      when /linux|unix|ubuntu|fedora/ then :linux
      else
        nil
      end
    end

    private

    def try_open_by_chrome(url)
      @browser = browsers_each(:chrome) do |cmd|
        begin
          cmd = "#{cmd} --app=#{url} --window-size=1290,800"
          return true if exec_cmd(cmd)
        rescue Exception => e
          Logger[:auto].error { e.log_inspect }
        end
      end

      false
    end

    def try_open_by_browser(url)
      Launchy.open(url) do |error|
        Logger[:auto].error(error.log_inspect)
        return false
      end

      true
    end

    def exec_cmd(cmd)
      app_in, @app_out, @app_err, @app_process = Open3.popen3(cmd)
      if app_in
        true
      else
        false
      end
    end

    def browsers_each(name, &block)
      name = name.to_sym
      bws = (BROWSERS[system_name] || {})[name]
      if bws.present?
        bws.each(&block)
      elsif system_name == :linux
        cmd = case name
        when :chrome then find_chrome
        end
        block.call(cmd) if cmd
      end
    end


    def find_chrome
      %w{
        google-chrome google-chrome-stable chromium chromium-browser chrome
      }.find { |cmd| which(cmd) }
    end

    def which(cmd)
      exts = ENV['PATHEXT'] ? ENV['PATHEXT'].split(';') : ['']
      ENV['PATH'].split(File::PATH_SEPARATOR).each do |path|
        exts.each do |ext|
          exe = File.join(path, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && !File.directory?(exe)
        end
      end
      return nil
    end
  end
end
