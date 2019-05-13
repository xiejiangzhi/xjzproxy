require 'timeout'
require 'shellwords'

module Xjz
  class WebUI::Browser
    attr_reader :app_out, :app_err, :app_process

    def initialize
    end

    def open(url)
      return true if @app_process
      cmd = [
        File.expand_path('ext/webview/webview', $root),
        '-url', Shellwords.escape(url),
        '-title',
        [
          $app_name, $config['.license'].present? ? 'Pro' : 'Free',
          $config['.user_id'].present? ? "- For #{$config['.user_id']}" : nil
        ].compact.join(' ')
      ]
      cmd << '-debug' if $config['webview_debug']
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
      rescue Errno::ECHILD
      end

      @app_process = nil
    end

    def join
      return unless app_process && app_process.alive?
      Process.wait(app_process.pid)
    rescue Errno::ECHILD
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
