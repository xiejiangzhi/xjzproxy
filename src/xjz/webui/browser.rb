require 'open3'
require 'shellwords'

module Xjz
  class WebUI::Browser
    BROWSERS = {
      osx: {
        chrome: [
          Shellwords.escape("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
        ],
        firefox: [
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
      @app_in, @app_out, @app_status, @app_thread = nil
    end

    def open(url)
      return if try_open_by_chrome(url)
      return if try_open_by_firefox(url)
      return if try_open_by_browser(url)

      raise "You must have either electron or google-chrome installed"\
        " and accesible via your path."
    end

    private

    def try_open_by_chrome(url)
      @browser = browsers_each(:chrome) do |cmd|
        begin
          cmd = "#{cmd} --app=#{url}"
          return true if popen3(cmd)
        rescue Exception => e
          Logger[:auto].error { e.log_inspect }
        end
      end

      false
    end

    def try_open_by_firefox(url)
    end

    def try_open_by_browser(url)
      Launchy.open(url) do |error|
        Logger[:auto].error(error.log_inspect)
        return false
      end

      true
    end

    def popen3
      @app_in, @app_out, @app_status, @app_thread = Open3.popen3(cmd)
      @app_in ? true : false
    end

    def browsers_each(name, &block)
      name = name.to_sym
      bws = (BROWSERS[system_name] || {})[name]
      if bws
        bws.each(&block)
      elsif system_name == :linux
        cmd = case name
        when :chrome then find_chrome
        when :firefox then nil
        end
        block.call(cmd) if cmd
      end
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
