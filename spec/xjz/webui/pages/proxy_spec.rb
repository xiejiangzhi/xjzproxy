RSpec.describe 'webui.proxy', webpage: true do
  before :each do
    cdata = $config.data.deep_dup
    allow($config).to receive(:data).and_return(cdata)
  end

  it 'status.change should start proxy if value true' do
    msg = new_webmsg('proxy.status.change', 'value' => true)
    expect($config.shared_data.app.server).to receive(:start_proxy)
    expect(msg).to receive(:render).with("webui/proxy/index.html").and_call_original
    expect(msg).to receive(:render).with("webui/proxy/_status_text.html").and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: '#f_proxy', html: kind_of(String)
    )
    expect(msg).to receive(:send_msg).with(
      'el.replace', selector: '#navbar_proxy_status_text', html: kind_of(String)
    )
    web_router.call(msg)
  end

  it 'status.change should stop proxy if value = false' do
    msg = new_webmsg('proxy.status.change', 'value' => false)
    expect($config.shared_data.app.server).to receive(:stop_proxy)
    expect(msg).to receive(:render).with("webui/proxy/index.html").and_call_original
    expect(msg).to receive(:render).with("webui/proxy/_status_text.html").and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: '#f_proxy', html: kind_of(String)
    )
    expect(msg).to receive(:send_msg).with(
      'el.replace', selector: '#navbar_proxy_status_text', html: kind_of(String)
    )
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

  it 'host_whitelist change should update data' do
    msg = new_webmsg('proxy.host_whitelist.change', 'value' => "xjz.com\nasdffdsa.com")
    expect {
      web_router.call(msg)
    }.to change { $config['host_whitelist'] }.to(%w{xjz.com asdffdsa.com})
  end

  it 'project.xxx.del_btn.click should remove a project' do
    pid = $config['projects'][0].object_id
    msg = new_webmsg("proxy.project.#{pid}.del_btn.click")
    ap = $config['.api_projects'].first
    expect(msg).to receive(:send_msg).with('el.remove', selector: "#proxy_project_#{pid}")
    expect(msg).to receive(:send_msg).with('el.remove', selector: "#document_tab_#{ap.object_id}")
    expect {
      expect {
        web_router.call(msg)
      }.to change { $config['projects'] }.to([])
    }.to change { $config['.api_projects'] }.to([])
  end

  it 'new_project.change should add a project' do
    msg = new_webmsg("proxy.new_project.change", 'value' => '/path/to/poj')
    expect(msg).to receive(:render).with(
      "webui/proxy/_project_item.html", path: '/path/to/poj'
    ).and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.append', selector: "#proxy_project_list", html: kind_of(String)
    )
    expect(msg).to receive(:render).with(
      "webui/document/doc_tab.html", ap: kind_of(Xjz::ApiProject)
    ).and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.append', selector: "#document_list_tabs", html: kind_of(String)
    )
    pojs = ["./spec/files/project.yml", "/path/to/poj"]
    expect {
      expect {
        web_router.call(msg)
      }.to change { $config['projects'] }.to(pojs)
    }.to change { $config['.api_projects'].map(&:repo_path) }.to(pojs)
  end

  it 'alpn_protocol.change update alpn protocols' do
    msg = new_webmsg("proxy.alpn_protocol.change", 'value' => false, 'name' => 'h2')
    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      web_router.call(msg)
    }.to change { $config['alpn_protocols'] }.to(['http/1.1'])

    msg = new_webmsg("proxy.alpn_protocol.change", 'value' => false, 'name' => 'http/1.1')
    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      web_router.call(msg)
    }.to change { $config['alpn_protocols'] }.to([])

    msg = new_webmsg("proxy.alpn_protocol.change", 'value' => true, 'name' => 'http/1.1')
    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      web_router.call(msg)
    }.to change { $config['alpn_protocols'] }.to(['http/1.1'])

    msg = new_webmsg("proxy.alpn_protocol.change", 'value' => true, 'name' => 'http/1.1')
    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      web_router.call(msg)
    }.to_not change { $config['alpn_protocols'] }
  end
end
