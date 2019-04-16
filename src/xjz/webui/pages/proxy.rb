module Xjz
  WebUI::ActionRouter.register do
    namespace 'proxy' do
      event 'status.change' do
        if data['value']
          $config.shared_data.app.server.start_proxy
        else
          $config.shared_data.app.server.stop_proxy
        end

        send_msg('el.html', selector: '#f_proxy', html: render('webui/proxy/index.html'))
        proxy_status = render('webui/proxy/_status_text.html',)
        send_msg('el.replace', selector: '#navbar_proxy_status_text', html: proxy_status)
      end

      event 'port.change' do
        $config['proxy_port'] = data['value']
      end

      event 'mode.change' do
        $config['proxy_mode'] = data['value']
      end

      event 'host_whitelist.change' do
        $config['host_whitelist'] = data['value'].to_s.strip.lines.map(&:strip)
      end

      event(/^project\.(?<path_id>\d+)\.del_btn\.click$/) do
        path_id = match_data[:path_id].to_i
        path = $config['projects'].find { |path| path.object_id == path_id }
        $config['projects'].delete path
        $config['.api_projects'].delete_if { |ap| ap.repo_path == path }
        send_msg('el.remove', selector: "#proxy_project_#{path_id}")
      end

      event 'new_project.change' do
        path = data['value']
        $config['projects'] << path
        $config['.api_projects'] << ApiProject.new(path)
        send_msg(
          'el.append',
          selector: "#proxy_project_list",
          html: render('webui/proxy/_project_item.html', path: path)
        )
      end

      event 'alpn_protocol.change' do
        if data['value']
          $config['alpn_protocols'] << data['name']
        else
          $config['alpn_protocols'].delete data['name']
        end
        $config['alpn_protocols'].uniq!
        Resolver::SSL.reset_certs
      end
    end
  end
end
