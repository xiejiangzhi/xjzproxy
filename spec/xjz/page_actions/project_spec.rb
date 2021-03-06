RSpec.describe 'project', webpage: true do
  let(:ap) { $config['.api_projects'][0] }

  before :each do
    ap.cache.clear
    allow(ap).to receive(:data).and_return(ap.data.deep_dup)
  end

  it 'detail_tab.xxx.click should render detail' do
    dr = double('doc_renderer', render: true)
    expect(Xjz::ApiProject::DocRenderer).to receive(:new).with(ap).and_return(dr)
    expect(dr).to receive(:render).and_return('## doc')
    expect_runner_render([ "webui/project/detail_toc.html", ap: ap], :original)
    expect_runner_send_msg(['el.html', selector: '#project_left', html: kind_of(String)])
    expect_runner_render([ "webui/project/detail.html", ap: ap], :original)
    expect_runner_send_msg(['el.html', selector: '#project_detail', html: kind_of(String)])
    emit_msg("project.detail_tab.#{ap.object_id}.click")
  end

  it 'show_list.click should render project list' do
    expect_runner_render([ "webui/project/tab_list.html"], :original)
    expect_runner_send_msg(['el.html', selector: '#project_left', html: kind_of(String)])
    emit_msg("project.show_list.click")
  end

  it 'mode.xxx.change should update project mode' do
    expect_runner.to_not receive(:render)
    expect {
      expect {
        emit_msg("project.mode.#{ap.object_id}.change", value: 'disable')
      }.to change { ap.data['.enabled'] }.to(false)
    }.to change { ap.data['.mode'] }.to('disable')

    expect {
      expect {
        emit_msg("project.mode.#{ap.object_id}.change", value: 'watch')
      }.to change { ap.data['.enabled'] }.to(true)
    }.to change { ap.data['.mode'] }.to('watch')

    expect {
      expect {
        emit_msg("project.mode.#{ap.object_id}.change", value: 'mock')
      }.to_not change { ap.data['.enabled'] }
    }.to change { ap.data['.mode'] }.to('mock')
  end

  it 'mode.xxx.change should update doc tab when focus tab' do
    session[:project_focus_toc] = false
    expect_runner_render(['webui/project/doc_tab.html', ap: ap], :original)
    expect_runner_send_msg([
      'el.replace', selector: "#project_tab_#{ap.object_id}", html: kind_of(String)
    ])
    expect {
      emit_msg("project.mode.#{ap.object_id}.change", value: 'disable')
    }.to change { ap.data['.enabled'] }.to(false)
  end

  it 'choose_api_res.change should set default response' do
    api = ap.data['apis'][0]
    expect {
      emit_msg("project.#{ap.object_id}.choose_api_res.0.change", value: 'xxx')
    }.to change { api['response']['.default'] }.to('xxx')
  end

  it 'export.html.xxx.click should export html document' do
    export_path = File.join(ap.repo_dir, 'xjzproxy-doc.html')
    `rm -rf #{export_path}`

    expect_runner_send_msg([
      'alert',
      message: "Successfully export document " +
        "<strong>xjzproxy-doc.html</strong> to the current project directory."
    ])

    expect {
      emit_msg("project.export.html.#{ap.object_id}.click")
    }.to change { File.exist?(export_path) }.to(true)
  end

  describe 'opendir.xxx.click' do
    it 'should call open folder cmd' do
      allow(Gem::Platform.local).to receive(:os).and_return('darwin')
      expect(Kernel).to receive(:system).with("open #{ap.repo_dir}")
      emit_msg("project.opendir.#{ap.object_id}.click")
    end

    it 'should call open folder with xdg-open cmd on linux' do
      allow(Gem::Platform.local).to receive(:os).and_return('linux')
      expect(Kernel).to receive(:system).with("which xdg-open").and_return(true)
      expect(Kernel).to receive(:system).with("xdg-open #{ap.repo_dir}")
      emit_msg("project.opendir.#{ap.object_id}.click")
    end

    it 'should send error msg when failed to open dir' do
      allow(Gem::Platform.local).to receive(:os).and_return('linux')
      expect(Kernel).to receive(:system).with("which xdg-open").and_return(false)
      expect_runner_send_msg(['alert', type: :error, message: "Failed to open dir #{ap.repo_dir}"])
      emit_msg("project.opendir.#{ap.object_id}.click")
    end
  end

  describe 'server.' do
    it 'project.del should remove a project', stub_config: true do
      expect_runner_send_msg(['el.remove', selector: "#project_tab_#{ap.object_id}"])
      # expect_runner_send_msg(["el.html", selector: "#project_detail", html: ''])
      expect_runner_send_msg(['alert', message: "Removed project #{File.basename(ap.repo_path)}"])
      expect {
        emit_msg("server.project.del", ap: ap)
      }.to change($config.data['.api_projects'], :size).to(0)
    end

    it 'project.del should clean detail if it is current project', stub_config: true do
      session[:current_project] = ap
      expect_runner_send_msg(['el.remove', selector: "#project_tab_#{ap.object_id}"])
      expect_runner_send_msg(["el.html", selector: "#project_detail", html: ''])
      expect_runner_send_msg(['alert', message: "Removed project #{File.basename(ap.repo_path)}"])
      expect {
        emit_msg("server.project.del", ap: ap)
      }.to change($config.data['.api_projects'], :size).to(0)
    end

    it 'project.del should clean detail if it is current project', stub_config: true do
      session[:current_project] = ap
      expect_runner_send_msg(['el.remove', selector: "#project_tab_#{ap.object_id}"])
      expect_runner_send_msg(["el.html", selector: "#project_detail", html: ''])
      expect_runner_send_msg(['alert', message: "Removed project #{File.basename(ap.repo_path)}"])
      expect {
        emit_msg("server.project.del", ap: ap)
      }.to change($config.data['.api_projects'], :size).to(0)
    end

    it 'project.add should add a project', stub_config: true do
      path = File.join($root, 'spec/files/project')
      ap = double(
        'api project',
        errors: nil,
        repo_path: path,
        data: { 'apis' => {}, 'project' => { 'url' => 'http://xxx.com' } },
        raw_data: { 'apis' => [], 'project' => { 'url' => 'http://xxx.com' } },
        grpc: nil,
        files: ['a']
      )
      allow(Xjz::ApiProject).to receive(:new).with(path).and_return(ap)

      expect_runner_render(["webui/project/doc_tab.html", ap: ap], :original)
      expect_runner_send_msg(['el.append', selector: "#project_list_tabs", html: kind_of(String)])
      expect_runner_send_msg(['alert', message: "Added project project"])

      expect {
        emit_msg("server.project.add", path: path)
      }.to change($config.data['.api_projects'], :size).by(1)
    end

    it 'project.add should not add project if not files', stub_config: true do
      path = File.join($root, 'spec/files/project')
      ap = double(
        'api project',
        errors: nil,
        repo_path: path,
        data: { 'apis' => {}, 'project' => { 'url' => 'http://xxx.com' } },
        raw_data: { 'apis' => [], 'project' => { 'url' => 'http://xxx.com' } },
        grpc: nil,
        files: []
      )
      allow(Xjz::ApiProject).to receive(:new).with(path).and_return(ap)

      expect_runner.to_not receive(:render)
      expect_runner.to_not receive(:send_msg)

      expect {
        emit_msg("server.project.add", path: path)
      }.to_not change($config.data['.api_projects'], :size)
    end

    it 'project.reload should reload project' do
      expect(ap).to receive(:reload)
      expect_runner_send_msg([
        'el.replace', selector: "#project_tab_#{ap.object_id}", html: kind_of(String)
      ])
      expect_runner_send_msg(['alert', message: "Updated project #{File.basename(ap.repo_path)}"])
      emit_msg("server.project.reload", ap: ap)
    end

    it 'project.reload should update detail if it is current project' do
      session[:current_project] = ap
      expect_runner_send_msg([
        'el.replace', selector: "#project_tab_#{ap.object_id}", html: kind_of(String)
      ])
      expect_runner_send_msg([
        'el.html', selector: "#project_detail", html: kind_of(String)
      ])
      expect(ap).to receive(:reload)
      expect_runner_send_msg(['alert', message: "Updated project #{File.basename(ap.repo_path)}"])
      emit_msg("server.project.reload", ap: ap)
    end
  end
end
