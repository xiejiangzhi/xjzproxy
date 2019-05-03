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

  it 'reset_cert.click should reset cert' do
    msg = new_webmsg('proxy.reset_cert.click')
    cm = $config.shared_data.app.cert_manager
    expect(cm).to receive(:reset!)
    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: '#root_ca_fingerprint', html: cm.root_ca_fingerprint
    )
    expect(msg).to receive(:send_msg).with('alert', message: kind_of(String))
    web_router.call(msg)
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

  it 'projects_dir.change should add new project and remove missed projects' do
    $config.data['projects'] = []
    path = File.join($root, 'spec')
    msg = new_webmsg("proxy.projects_dir.change", 'value' => path)
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: "#proxy_projects_dir", html: path
    )
    expect(msg).to receive(:send_msg) \
      .with('el.remove', selector: "#project_tab_#{$config['.api_projects'].first.object_id}")

    ap_paths = []
    %w{misc support xjz files}.sort.each do |dir|
      ap_path = File.join(path, dir)
      ap_paths << ap_path
      ap = double('api project', errors: nil, repo_path: ap_path, data: { 'apis' => [] })
      allow(Xjz::ApiProject).to receive(:new).with(ap_path).and_return(ap)

      expect(msg).to receive(:render).with(
        "webui/project/doc_tab.html", ap: ap
      ).and_call_original
      expect(msg).to receive(:send_msg).with(
        'el.append', selector: "#project_list_tabs", html: kind_of(String)
      )
    end

    expect(msg).to receive(:send_msg).with(
      "alert", message: "Successfully change projects folder. " +
        "Added 4 projects. Removed 1 projects."
    )
    expect {
      web_router.call(msg)
    }.to change { $config['.api_projects'].map(&:repo_path) }.to(ap_paths)
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
