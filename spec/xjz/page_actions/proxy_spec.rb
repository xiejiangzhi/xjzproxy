RSpec.describe 'proxy', webpage: true, stub_config: true do
  let(:server) { $config.shared_data.app.server }

  it 'status.change should start proxy if value true' do
    expect(server).to receive(:start_proxy)
    expect_runner_render(["webui/proxy/index.html"], :original)
    expect_runner_render(["webui/proxy/_status_text.html"], :original)
    expect_runner_send_msg(['el.html', selector: '#f_proxy', html: kind_of(String)])
    expect_runner_send_msg([
      'el.replace', selector: '#navbar_proxy_status_text', html: kind_of(String)
    ])
    emit_msg('proxy.status.change', 'value' => true)
  end

  it 'status.change should back to off if failed to start' do
    allow(TCPSocket).to receive(:new).and_raise(Errno::EADDRINUSE.new('err'))
    allow(server).to receive(:proxy_socket)
    expect(server).to receive(:start_proxy).and_call_original
    expect_runner_send_msg([
      'el.set_attr', selector: '#proxy_status_switch', attr: 'checked', value: nil
    ])
    expect_runner_send_msg([
      'alert', type: :error, message: 'Failed to start proxy. Please try to change the port.'
    ])
    emit_msg('proxy.status.change', 'value' => true)
  end

  it 'status.change should stop proxy if value = false' do
    expect(server).to receive(:stop_proxy)
    expect_runner_render(["webui/proxy/index.html"], :original)
    expect_runner_render(["webui/proxy/_status_text.html"], :original)
    expect_runner_send_msg(['el.html', selector: '#f_proxy', html: kind_of(String)])
    expect_runner_send_msg([
      'el.replace', selector: '#navbar_proxy_status_text', html: kind_of(String)
    ])
    emit_msg('proxy.status.change', 'value' => false)
  end

  it 'port.change should update port' do
    expect($config).to receive(:save)
    expect {
      emit_msg('proxy.port.change', 'value' => 12342)
    }.to change { $config['proxy_port'] }.to(12342)
  end

  it 'reset_cert.click should reset cert' do
    cm = $config.shared_data.app.cert_manager
    expect(cm).to receive(:reset!)
    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect_runner_send_msg([
      'el.html', selector: '#root_ca_fingerprint', html: cm.root_ca_fingerprint
    ])
    expect_runner_send_msg(['alert', message: kind_of(String)])
    emit_msg('proxy.reset_cert.click')
  end

  it 'mode.change should update port' do
    expect($config).to receive(:save)
    expect {
      emit_msg('proxy.mode.change', 'value' => 'all')
    }.to change { $config['proxy_mode'] }.to('all')
  end

  it 'host_whitelist change should update data' do
    expect($config).to receive(:save).and_call_original
    expect {
      emit_msg('proxy.host_whitelist.change', 'value' => "xjz.com\nasdffdsa.com")
    }.to change { $config['host_whitelist'] }.to(%w{xjz.com asdffdsa.com})
  end

  it 'projects_dir.change should add new project and remove missed projects' do
    expect($config).to receive(:save).and_call_original
    $config.data['projects'] = []
    path = File.join($root, 'spec')
    expect_runner_send_msg(['el.html', selector: "#proxy_projects_dir", html: path])
    old_ap = $config['.api_projects'].first
    expect_runner.to receive(:del_project).with(old_ap).and_call_original
    expect_runner_send_msg(["el.remove", selector: "#project_tab_#{old_ap.object_id}"])
    expect_runner_send_msg(["alert", message: "Removed project #{File.basename(old_ap.repo_path)}"])
    expect($config.shared_data.app.file_watcher).to receive(:restart)

    ap_paths = []
    %w{misc support xjz files}.sort.each do |dir|
      ap_path = File.join(path, dir)
      ap_paths << ap_path
      expect_runner.to receive(:add_project).with(ap_path).and_call_original
    end
    expect_runner_send_msg(["el.append", selector: "#project_list_tabs", html: kind_of(String)])
    expect_runner_send_msg(["alert", message: "Added project files"])

    expect_runner_send_msg(["alert", message: "Successfully change projects folder."])
    expect {
      emit_msg("proxy.projects_dir.change", 'value' => path)
    }.to change { $config['.api_projects'].map(&:repo_path) }.to([File.join(path, 'files')])
  end

  it 'alpn_protocol.change update alpn protocols' do
    expect($config).to receive(:save).exactly(4).times
    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      emit_msg("proxy.alpn_protocol.change", 'value' => false, 'name' => 'h2')
    }.to change { $config['alpn_protocols'] }.to(['http/1.1'])

    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      emit_msg("proxy.alpn_protocol.change", 'value' => false, 'name' => 'http/1.1')
    }.to change { $config['alpn_protocols'] }.to([])

    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      emit_msg("proxy.alpn_protocol.change", 'value' => true, 'name' => 'http/1.1')
    }.to change { $config['alpn_protocols'] }.to(['http/1.1'])

    expect(Xjz::Resolver::SSL).to receive(:reset_certs)
    expect {
      emit_msg("proxy.alpn_protocol.change", 'value' => true, 'name' => 'http/1.1')
    }.to_not change { $config['alpn_protocols'] }
  end
end
