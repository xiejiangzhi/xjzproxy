Xjz::WebUI::ActionRouter.register do
  namespace 'proxy' do
    event 'start.click' do
      $config.shared_data.app.server.start_proxy
      send_msg('el.html', selector: '#t_proxy_config', html: render('webui/_proxy_page.html'))
    end

    event 'stop.click' do
      $config.shared_data.app.server.stop_proxy
      send_msg('el.html', selector: '#t_proxy_config', html: render('webui/_proxy_page.html'))
    end
  end
end
