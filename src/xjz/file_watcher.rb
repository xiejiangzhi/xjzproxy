require 'filewatcher'

module Xjz
  class FileWatcher
    INTERVAL = 3 #seconds

    def filewatcher
      @filewatcher ||= Filewatcher.new(
        project_file_matcher,
        interval: INTERVAL,
        every: true
      )
    end

    def start
      Logger[:auto].info { "Watch files #{project_file_matcher.join(', ')}" }
      @thread ||= Thread.new { filewatcher.watch(&method(:on_project_file_change)) }
    end

    def stop
      @thread.kill if @thread
      @filewatcher.stop if @filewatcher
      @thread = nil
      @filewatcher = nil
    end

    def restart
      stop
      start
    end

    private

    def project_file_matcher
      [
        File.join($config.data['projects_dir'], '**/*.{yml,yaml}'),
      ]
    end

    def on_project_file_change(path, event)
      sub_path = path.delete_prefix($config.data['projects_dir'] + '/')
      pname, _pfile = sub_path.split('/', 2)
      repo_path = File.join($config.data['projects_dir'], pname)

      ap = $config.data['.api_projects'].find { |ap| ap.repo_path == repo_path }

      if ap
        if event == :deleted && ap.files.empty?
          $config.shared_data.app.webui.emit_message('project.del', ap: ap)
          Logger[:auto].info { "Delete project #{ap.repo_path}" }
        else
          $config.shared_data.app.webui.emit_message('project.reload', ap: ap)
        end
      elsif $config['.api_projects'].empty? || Xjz.APP_EDITION == Xjz::PRO_ED
        $config.shared_data.app.webui.emit_message('project.add', path: repo_path)
        Logger[:auto].info { "Add project #{repo_path}" }
      end
    end
  end
end
