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
    end
  end
end
