RSpec.describe 'webui.server', webpage: true do
  let(:req) { Xjz::Request.new(new_req_env) }
  let(:res) { Xjz::Response.new(new_http1_res_headers, []) }
  let(:tracker) { Xjz::Tracker.new }
  let(:rt) { tracker.track_req(req) }

  it 'new_request should update status bar' do
    msg = new_webmsg("server.new_request")
    allow(Xjz::Tracker.instance.history).to receive(:count).and_return(321)
    expect(msg).to receive(:send_msg).with('el.html', selector: '#navbar_total_requests', html: 321)
    web_router.call(msg)
  end
end
