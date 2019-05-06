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

  describe 'detail.xxx.click for different data' do
    it 'should working for invalid utf-8 bytes' do
      allow(res).to receive(:body).and_return("\u001F\x8B\b\u0000\u0003Œ")
      rt.finish(res)
      expect_runner_render(["webui/history/detail.html", request_tracker: rt], :original)
      expect_runner_send_msg(['el.html', selector: '#history_detail', html: kind_of(String)])
      emit_msg("history.detail.#{rt.object_id}.click")
      expect(session[:current_rt]).to eql(rt)
    end
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

  it 'group_by.change should rerender rt_list' do
    rt.finish(res)
    expect_runner_render(["webui/history/rt_list.html"], :original)
    expect_runner_send_msg(['el.html', selector: '#history_rt_list_group', html: kind_of(String)])
    expect {
      emit_msg("history.group_by.change", value: 'host')
    }.to change { session[:history_group_by] }.to('host')
  end

  it 'filter.change should rerender rt_list' do
    rt.finish(res)
    expect_runner_render(["webui/history/rt_list.html"], :original)
    expect_runner_send_msg(['el.html', selector: '#history_rt_list_group', html: kind_of(String)])
    expect {
      emit_msg("history.filter.change", value: 'xxx')
    }.to change { session[:history_filter]&.filters_str }.to('xxx')
  end

  describe 'server.tracker' do
    before :each do
      rt
    end

    it 'new_request should update status bar' do
      allow(Xjz::Tracker.instance.history).to receive(:count).and_return(321)
      expect_runner_send_msg(['el.html', selector: '#navbar_total_requests', html: '321'])
      expect_runner_render(
        ['webui/history/request_tab.html', request_tracker: rt, group_id: nil], 'htmlxzz'
      )
      selector = "#history_rt_list_group"
      expect_runner_send_msg(['el.append', selector: selector, html: 'htmlxzz'])
      emit_msg("server.tracker.new_request", rt: rt)
    end

    it 'new_request should render group tab if count <= 1' do
      session[:history_group_by] = 'conn'
      group_id = "rt_conn_#{rt.request.user_socket.object_id}"
      expect_runner_send_msg(['el.html', selector: '#navbar_total_requests', html: '1'])
      expect_runner_render(
        ['webui/history/request_group_tab.html', request: req, group_id: group_id], 'htmlxxx'
      )
      expect_runner_send_msg(['el.append', selector: '#history_rt_list_group', html: 'htmlxxx'])
      emit_msg("server.tracker.new_request", rt: rt)
    end

    it 'update_request should update tab' do
      expect_runner_render(
        ['webui/history/request_tab.html', request_tracker: rt, group_id: nil], 'htmlxxx'
      )
      expect_runner_send_msg([
        'el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: 'htmlxxx'
      ])
      emit_msg("server.tracker.update_request", rt: rt)
    end

    it 'update_request should update tab and detail if rt is current rt' do
      session[:history_group_by] = 'host'
      session[:current_rt] = rt
      expect_runner_render(
        [
          'webui/history/request_tab.html',
          request_tracker: rt, group_id: "rt_host_#{Base64.strict_encode64(req.host).tr('=', '')}"
        ], 'htmlxxx'
      )
      expect_runner_send_msg(['el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: 'htmlxxx'])
      expect_runner_render(['webui/history/detail.html', request_tracker: rt], 'htmlyyy')
      expect_runner_send_msg(['el.html', selector: "#history_detail", html: 'htmlyyy'])
      emit_msg("server.tracker.update_request", rt: rt)
    end
  end
end
