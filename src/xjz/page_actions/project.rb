module Xjz
  WebUI::ActionRouter.register :project do
    event 'f_project_tab.click' do
      session[:current_tab] = :project
      $config.projects_check
    end

    namespace 'project' do
      event(/^detail_tab\.(?<ap_id>\d+)\.click$/) do
        session[:project_focus_toc] = true
        ap = find_by_ap_id(match_data['ap_id'])

        send_msg(
          'el.html',
          selector: '#project_left',
          html: render('webui/project/detail_toc.html', ap: ap)
        )

        if session[:current_project] != ap
          session[:current_project] = ap
          show_project(ap, toc: false)
        end
      end

      event 'show_list.click' do
        session[:project_focus_toc] = false
        send_msg(
          'el.html',
          selector: '#project_left',
          html: render('webui/project/tab_list.html')
        )
      end

      event(/^status_switch\.(?<ap_id>\d+)\.change$/) do
        ap = find_by_ap_id(match_data['ap_id'])
        ap.data['.enabled'] = !!data['value']
        if session[:project_focus_toc] == false
          send_msg(
            'el.replace',
            selector: "#project_tab_#{ap.object_id}",
            html: render('webui/project/doc_tab.html', ap: ap)
          )
        end
      end

      event(/^(?<ap_id>\d+)\.choose_api_res\.(?<api_index>\d+)\.change$/) do
        ap = find_by_ap_id(match_data['ap_id'])
        api_index = match_data['api_index'].to_i
        api = ap.data['apis'][api_index]
        api['response']['.default'] = data[:value]
      end

      event(/^opendir\.(?<ap_id>\d+)\.click$/) do
        ap = find_by_ap_id(match_data['ap_id'])
        dir = ap.repo_dir
        opened = false

        case Gem::Platform.local.os
        when 'darwin'
          Kernel.system("open #{dir}")
          opened = true
        else
          %w{xdg-open}.each do |cmd|
            next unless Kernel.system("which #{cmd}")
            Kernel.system("#{cmd} #{dir}")
            opened = true
            break
          end
        end

        unless opened
          Logger[:auto].error { "Failed to open dir #{dir}" }
          send_msg('alert', type: :error, message: "Failed to open dir #{dir}")
        end
      end

      namespace 'export' do
        event(/^html\.(?<ap_id>\d+)\.click$/) do
          ap = find_by_ap_id(match_data['ap_id'])
          filename = 'xjzproxy-doc.html'
          path = File.join(ap.repo_dir, filename)
          html = render(
            'webui/project/export.html',
            title: ap.data['project']['title'] || File.basename(ap.repo_path),
            body: ap.cache[:doc_html]
          )

          File.write(path, html)
          send_msg(
            'alert',
            message: "Successfully export document " +
              "<strong>#{filename}</strong> to the current project directory."
          )
        rescue => e
          Logger[:auto].error { e.log_inspect }
          send_msg('alert', type: :error, message: "Failed to export document")
        end
      end
    end

    namespace 'server.project' do
      # Params:
      #   path:
      event 'add' do
        add_project(data[:path])
      end

      # Params:
      #   ap: or path
      #   path: ap path
      event 'del' do
        ap = data[:ap] || $config['.api_projects'].find { |v| v.repo_path == data[:path] }
        del_project(ap)
      end

      # Params:
      #   ap: or path
      event 'reload' do
        ap = data[:ap]
        reload_project(ap)
      end
    end

    helpers do
      include PageActions::ProjectHelper
    end
  end
end
