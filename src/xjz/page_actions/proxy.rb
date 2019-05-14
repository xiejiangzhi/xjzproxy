module Xjz
  WebUI::ActionRouter.register :proxy do
    event 'f_proxy_tab.click' do
      session[:current_tab] = :proxy
    end

    namespace 'proxy' do
      event 'status.change' do
        server = $config.shared_data.app.server
        if data['value']
          server.start_proxy
          unless server.proxy_socket
            send_msg('el.set_attr', selector: '#proxy_status_switch', attr: 'checked', value: nil)
            send_msg(
              'alert',
              type: :error,
              message: 'Failed to start proxy. Please try to change the port.'
            )
            next
          end
        else
          server.stop_proxy
        end

        send_msg('el.html', selector: '#f_proxy', html: render('webui/proxy/index.html'))
        proxy_status = render('webui/proxy/_status_text.html',)
        send_msg('el.replace', selector: '#navbar_proxy_status_text', html: proxy_status)
      end

      event 'port.change' do
        $config['proxy_port'] = data['value']
        $config.save
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
        $config.save
      end

      event 'host_whitelist.change' do
        $config['host_whitelist'] = data['value'].to_s.strip.lines.map(&:strip)
        $config.save
      end

      event 'alpn_protocol.change' do
        if data['value']
          $config['alpn_protocols'] << data['name']
        else
          $config['alpn_protocols'].delete data['name']
        end
        $config['alpn_protocols'].uniq!
        $config.save
        Resolver::SSL.reset_certs
      end

      event 'projects_dir.change' do
        $config['projects_dir'] = data['value'].strip
        $config.save
        paths = $config.projects_paths
        send_msg('el.html', selector: '#proxy_projects_dir', html: $config['projects_dir'])
        daps = []
        $config['.api_projects'].each do |ap|
          path = ap.repo_path
          if paths.include?(path)
            paths.delete(path)
            false
          else
            daps << ap
            true
          end
        end
        daps.each { |ap| del_project(ap) }

        paths.sort.each { |path| add_project(path) }
        msg = "Successfully change projects folder."
        send_msg('alert', message: msg)
        $config.shared_data.app.file_watcher.restart
      end
    end

    helpers do
      include PageActions::ProjectHelper
    end
  end
end
