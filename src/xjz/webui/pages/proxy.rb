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

      event 'reset_cert.click' do
        cm = $config.shared_data.app.cert_manager
        cm.reset!
        Xjz::Resolver::SSL.reset_certs
        send_msg(
          'el.html',
          selector: '#root_ca_fingerprint',
          html: cm.root_ca_fingerprint
        )
        send_msg(
          'alert',
          message: 'Successfully generate certificate, please download and setup the new one after run proxy.'
        )
      end

      event 'mode.change' do
        $config['proxy_mode'] = data['value']
      end

      event 'host_whitelist.change' do
        $config['host_whitelist'] = data['value'].to_s.strip.lines.map(&:strip)
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

      event 'projects_dir.change' do
        $config['projects_dir'] = data['value'].strip
        paths = $config.projects_paths
        send_msg('el.html', selector: '#proxy_projects_dir', html: $config['projects_dir'])
        added_counter, removed_counter = 0, 0
        $config['.api_projects'].delete_if do |ap|
          path = ap.repo_path
          if paths.include?(path)
            paths.delete(path)
            false
          else
            removed_counter += 1
            send_msg('el.remove', selector: "#project_tab_#{ap.object_id}")
            true
          end
        end

        paths.sort.each do |path|
          ap = ApiProject.new(path)
          $config['.api_projects'] << ap
          added_counter += 1
          send_msg(
            'el.append',
            selector: "#project_list_tabs",
            html: render('webui/project/doc_tab.html', ap: ap)
          )
        end
        msg = "Successfully change projects folder."
        msg << " Added #{added_counter} projects." if added_counter > 0
        msg << " Removed #{removed_counter} projects." if removed_counter > 0
        send_msg('alert', message: msg)
      end
    end
  end
end
