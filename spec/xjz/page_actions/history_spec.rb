RSpec.describe 'history', webpage: true do
  let(:req) { Xjz::Request.new(new_req_env) }
  let(:res) { Xjz::Response.new(new_http1_res_headers, []) }
  let(:tracker) { Xjz::Tracker.new }
  let(:rt) { tracker.track_req(req) }

  before :each do
    allow(Xjz::Tracker).to receive(:instance).and_return(tracker)
  end

  it 'detail.xxx.click should render detail' do
    rt.finish(res)
    expect_runner_render(["webui/history/detail.html", request_tracker: rt], :original)
    expect_runner_send_msg(['el.html', selector: '#history_detail', html: kind_of(String)])
    emit_msg("history.detail.#{rt.object_id}.click")
    expect(session[:current_rt]).to eql(rt)
  end

  it 'clean_all.click should reset history' do
    rt.finish(res)
    expect_runner_render(["webui/history/index.html"], :original)
    expect_runner_send_msg(['el.html', selector: '#navbar_total_requests', html: 0])
    expect_runner_send_msg(['el.html', selector: '#f_history', html: kind_of(String)])
    expect {
      emit_msg("history.clean_all.click")
    }.to change { tracker.history }.to([])
  end

  describe 'server.tracker' do
    before :each do
      rt
    end

    it 'new_request should update status bar' do
      allow(Xjz::Tracker.instance.history).to receive(:count).and_return(321)
      expect_runner_send_msg(['el.html', selector: '#navbar_total_requests', html: 321])
      expect_runner_render(['webui/history/request_tab.html', request_tracker: rt], 'htmlxzz')
      selector = "[data-rt-group=request_group_tab_#{req.user_socket.object_id}]:last"
      expect_runner_send_msg(['el.after', selector: selector, html: 'htmlxzz'])
      emit_msg("server.tracker.new_request", rt: rt)
    end

    it 'new_request should render group tab if count <= 1' do
      expect_runner_send_msg(['el.html', selector: '#navbar_total_requests', html: 1])
      expect_runner_render(['webui/history/request_group_tab.html', request: req], 'htmlxxx')
      expect_runner_send_msg(['el.append', selector: '#history_rt_list_group', html: 'htmlxxx'])
      expect_runner_render(['webui/history/request_tab.html', request_tracker: rt], 'htmlxzz')
      selector = "[data-rt-group=request_group_tab_#{req.user_socket.object_id}]:last"
      expect_runner_send_msg(['el.after', selector: selector, html: 'htmlxzz'])
      emit_msg("server.tracker.new_request", rt: rt)
    end

    it 'update_request should tab' do
      expect_runner_render(['webui/history/request_tab.html', request_tracker: rt], 'htmlxxx')
      expect_runner_send_msg([
        'el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: 'htmlxxx'
      ])
      emit_msg("server.tracker.update_request", rt: rt)
    end

    it 'update_request should tab and detail if rt is current rt' do
      session[:current_rt] = rt
      expect_runner_render(['webui/history/request_tab.html', request_tracker: rt], 'htmlxxx')
      expect_runner_send_msg(['el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: 'htmlxxx'])
      expect_runner_render(['webui/history/detail.html', request_tracker: rt], 'htmlyyy')
      expect_runner_send_msg(['el.html', selector: "#history_detail", html: 'htmlyyy'])
      emit_msg("server.tracker.update_request", rt: rt)
    end
  end
end
