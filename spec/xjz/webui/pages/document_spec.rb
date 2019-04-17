RSpec.describe 'webui.document', webpage: true do
  let(:ap) { $config['.api_projects'][0] }

  it 'detail_tab.xxx.click should render detail' do
    msg = new_webmsg("document.detail_tab.#{ap.object_id}.click")
    dr = double('doc_renderer', render: true)
    expect(Xjz::ApiProject::DocRenderer).to receive(:new).with(ap).and_return(dr)
    expect(dr).to receive(:render).and_return('## doc')
    expect(msg).to receive(:render) \
      .with("webui/document/detail.html", doc_html: "<h2>doc</h2>\n").and_call_original
    expect(msg).to receive(:send_msg).with('el.html', kind_of(Hash))
    web_router.call(msg)
  end
end
