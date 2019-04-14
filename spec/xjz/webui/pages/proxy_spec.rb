RSpec.describe 'webui.proxy', webpage: true do
  it 'start.click should start proxy' do
    msg = new_webmsg('proxy.start.click')
    expect($config.shared_data.app.server).to receive(:start_proxy)
    expect(msg).to receive(:render).with("webui/proxy/index.html").and_call_original
    expect(msg).to receive(:send_msg).with('el.html', kind_of(Hash))
    web_router.call(msg)
  end

  it 'stop.click should stop proxy' do
    msg = new_webmsg('proxy.stop.click')
    expect($config.shared_data.app.server).to receive(:stop_proxy)
    expect(msg).to receive(:render).with("webui/proxy/index.html").and_call_original
    expect(msg).to receive(:send_msg).with('el.html', kind_of(Hash))
    web_router.call(msg)
  end

  it 'port.change should update port' do
    msg = new_webmsg('proxy.port.change', 'value' => 12342)
    expect {
      web_router.call(msg)
    }.to change { $config['proxy_port'] }.to(12342)
  end

  it 'mode.change should update port' do
    msg = new_webmsg('proxy.mode.change', 'value' => 'all')
    expect {
      web_router.call(msg)
    }.to change { $config['proxy_mode'] }.to('all')
  end
end
