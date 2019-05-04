RSpec.describe 'project', webpage: true do
  let(:ap) { $config['.api_projects'][0] }

  it 'detail_tab.xxx.click should render detail' do
    dr = double('doc_renderer', render: true)
    expect(Xjz::ApiProject::DocRenderer).to receive(:new).with(ap).and_return(dr)
    expect(dr).to receive(:render).and_return('## doc')
    expect_runner_render(
      [ "webui/project/detail.html", doc_html: "<h2>doc</h2>\n", errors: nil ],
      :original
    )
    expect_runner_send_msg(['el.html', kind_of(Hash)])
    emit_msg("project.detail_tab.#{ap.object_id}.click")
  end

  it 'server.project.del should remove a project', stub_config: true do
    expect_runner_send_msg(['el.remove', selector: "#project_tab_#{ap.object_id}"])
    # expect_runner_send_msg(["el.html", selector: "#project_detail", html: ''])
    expect_runner_send_msg(['alert', message: "Removed project #{File.basename(ap.repo_path)}"])
    expect {
      emit_msg("server.project.del", ap: ap)
    }.to change($config.data['.api_projects'], :size).to(0)
  end

  it 'server.project.del should clean detail if it is current project', stub_config: true do
    session[:current_project] = ap
    expect_runner_send_msg(['el.remove', selector: "#project_tab_#{ap.object_id}"])
    expect_runner_send_msg(["el.html", selector: "#project_detail", html: ''])
    expect_runner_send_msg(['alert', message: "Removed project #{File.basename(ap.repo_path)}"])
    expect {
      emit_msg("server.project.del", ap: ap)
    }.to change($config.data['.api_projects'], :size).to(0)
  end

  it 'server.project.add should add a project', stub_config: true do
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

  it 'server.project.add should not add project if not files', stub_config: true do
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

  it 'server.project.reload should reload project' do
    expect(ap).to receive(:reload)
    expect_runner_send_msg([
      'el.replace', selector: "#project_tab_#{ap.object_id}", html: kind_of(String)
    ])
    expect_runner_send_msg(['alert', message: "Updated project #{File.basename(ap.repo_path)}"])
    emit_msg("server.project.reload", ap: ap)
  end

  it 'server.project.reload should update detail if it is current project' do
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
