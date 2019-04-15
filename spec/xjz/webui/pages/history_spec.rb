RSpec.describe 'webui.history', webpage: true do
  let(:req) { Xjz::Request.new(new_req_env) }
  let(:res) { Xjz::Response.new(new_http1_res_headers, []) }
  let(:tracker) { Xjz::Tracker.new }
  let(:rt) { tracker.track_req(req) }

  before :each do
    allow(Xjz::Tracker).to receive(:instance).and_return(tracker)
  end

  it 'detail.xxx.click should render detail' do
    rt.finish(res)
    msg = new_webmsg("history.detail.#{rt.object_id}.click")
    expect(msg).to receive(:render) \
      .with("webui/history/detail.html", request_tracker: rt).and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: '#history_detail', html: kind_of(String)
    )
    web_router.call(msg)
  end

  it 'clean_all.click should reset history' do
    rt.finish(res)
    msg = new_webmsg("history.clean_all.click")
    expect(msg).to receive(:render).with("webui/history/index.html").and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: '#navbar_total_requests', html: 0
    )
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: '#f_history', html: kind_of(String)
    )
    expect {
      web_router.call(msg)
    }.to change { tracker.history }.to([])
  end
end
