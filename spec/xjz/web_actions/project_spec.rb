RSpec.describe 'web_actions.project', webpage: true do
  let(:ap) { $config['.api_projects'][0] }

  it 'detail_tab.xxx.click should render detail' do
    msg = new_webmsg("project.detail_tab.#{ap.object_id}.click")
    dr = double('doc_renderer', render: true)
    expect(Xjz::ApiProject::DocRenderer).to receive(:new).with(ap).and_return(dr)
    expect(dr).to receive(:render).and_return('## doc')
    expect(msg).to receive(:render).with(
      "webui/project/detail.html", doc_html: "<h2>doc</h2>\n", errors: nil
    ).and_call_original
    expect(msg).to receive(:send_msg).with('el.html', kind_of(Hash))
    web_router.call(msg)
  end

  it 'server.project.del should remove a project', stub_config: true do
    msg = new_webmsg("server.project.del", ap: ap)
    expect(msg).to receive(:send_msg) \
      .with('el.remove', selector: "#project_tab_#{ap.object_id}")
    expect(msg).to receive(:send_msg).with(
      'alert', message: "Removed project #{File.basename(ap.repo_path)}"
    )
    expect {
      web_router.call(msg)
    }.to change($config.data['.api_projects'], :size).to(0)
  end

  it 'server.project.add should add a project', stub_config: true do
    path = File.join($root, 'spec/files/project')
    msg = new_webmsg("server.project.add", path: path)
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

    expect(msg).to receive(:render).with(
      "webui/project/doc_tab.html", ap: ap
    ).and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.append', selector: "#project_list_tabs", html: kind_of(String)
    )
    expect(msg).to receive(:send_msg).with('alert', message: "Added project project")

    expect {
      web_router.call(msg)
    }.to change($config.data['.api_projects'], :size).by(1)
  end

  it 'server.project.add should not add project if not files', stub_config: true do
    path = File.join($root, 'spec/files/project')
    msg = new_webmsg("server.project.add", path: path)
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

    expect(msg).to_not receive(:render)
    expect(msg).to_not receive(:send_msg)

    expect {
      web_router.call(msg)
    }.to_not change($config.data['.api_projects'], :size)
  end

  it 'server.project.reload should reload project' do
    msg = new_webmsg("server.project.reload", ap: ap)
    # expect(msg).to receive(:send_msg) \
    #   .with('el.remove', selector: "#project_tab_#{ap.object_id}")
    expect(ap).to receive(:reload)
    expect(msg).to receive(:send_msg).with(
      'alert', message: "Updated project #{File.basename(ap.repo_path)}"
    )
    web_router.call(msg)
  end
end
