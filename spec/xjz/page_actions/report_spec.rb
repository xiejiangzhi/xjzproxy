RSpec.describe 'report', webpage: true do
  let(:req) { Xjz::Request.new(new_req_env) }
  let(:res) { Xjz::Response.new(new_http1_res_headers, []) }
  let(:tracker) { Xjz::Tracker.new }
  let(:rt) { tracker.track_req(req) }

  before :each do
    rt.finish(res)
    allow(Xjz::Tracker).to receive(:instance).and_return(tracker)
  end

  it 'f_report_tab.click should render report page' do
    expect_runner_render(["webui/report/index.html"], :original)
    expect_runner_send_msg(['el.html', selector: '#f_report', html: kind_of(String)])
    emit_msg("f_report_tab.click")
  end
end
