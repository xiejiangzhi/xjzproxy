require 'shellwords'
require 'timeout'

module Xjz
  class WebUI::Browser
    attr_reader :app_out, :app_err, :app_process

    def initialize
    end

    def open(url)
      return true if @app_process
      cmd = [
        File.expand_path('lib/webview/webview', $root),
        '-url', Shellwords.escape(url)
      ]
      cmd << '-debug' if $app_env != 'prod'
      exec_cmd(cmd.join(' '))
    end

    def close
      return true unless app_process
      app_out.close
      app_err.close

      pid = app_process.pid
      Process.kill('QUIT', pid)
      begin
        Timeout.timeout(3) { Process.wait(pid) }
      rescue Timeout::Error
        Process.kill('TERM', pid)
      end

      @app_process = nil
    end

    private

    def exec_cmd(cmd)
      Logger[:auto].debug { "Open Webview: #{cmd}" }
      app_in, @app_out, @app_err, @app_process = Open3.popen3(cmd)
      app_in.close
      if app_process && app_process.alive?
        true
      else
        false
      end
    end
  end
end
