RSpec.describe 'webui.report', webpage: true do
  let(:req) { Xjz::Request.new(new_req_env) }
  let(:res) { Xjz::Response.new(new_http1_res_headers, []) }
  let(:tracker) { Xjz::Tracker.new }
  let(:rt) { tracker.track_req(req) }

  before :each do
    rt.finish(res)
    allow(Xjz::Tracker).to receive(:instance).and_return(tracker)
  end

  it 'f_report_tab.click should render report page' do
    msg = new_webmsg("f_report_tab.click")
    expect(msg).to receive(:render).with("webui/report/index.html").and_call_original
    expect(msg).to receive(:send_msg).with(
      'el.html', selector: '#f_report', html: kind_of(String)
    )
    web_router.call(msg)
  end
end
