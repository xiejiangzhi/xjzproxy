RSpec.describe 'web_actions.history', webpage: true do
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
    expect(msg.session[:current_rt]).to eql(rt)
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

  describe 'server.tracker' do
    it 'new_request should update status bar' do
      msg = new_webmsg("server.tracker.new_request", rt: rt)
      allow(Xjz::Tracker.instance.history).to receive(:count).and_return(321)
      expect(msg).to receive(:send_msg) \
        .with('el.html', selector: '#navbar_total_requests', html: 321)

      expect(msg).to receive(:render) \
        .with('webui/history/request_tab.html', request_tracker: rt).and_return('htmlxzz')
      selector = "[data-rt-group=request_group_tab_#{req.user_socket.object_id}]:last"
      expect(msg).to receive(:send_msg) \
        .with('el.after', selector: selector, html: 'htmlxzz')
      web_router.call(msg)
    end

    it 'new_request should render group tab if count <= 1' do
      msg = new_webmsg("server.tracker.new_request", rt: rt)
      expect(msg).to receive(:send_msg) \
        .with('el.html', selector: '#navbar_total_requests', html: 1)

      expect(msg).to receive(:render) \
        .with('webui/history/request_group_tab.html', request: req).and_return('htmlxxx')
      expect(msg).to receive(:send_msg) \
        .with('el.append', selector: '#history_rt_list_group', html: 'htmlxxx')

      expect(msg).to receive(:render) \
        .with('webui/history/request_tab.html', request_tracker: rt).and_return('htmlxzz')
      selector = "[data-rt-group=request_group_tab_#{req.user_socket.object_id}]:last"
      expect(msg).to receive(:send_msg) \
        .with('el.after', selector: selector, html: 'htmlxzz')
      web_router.call(msg)
    end

    it 'update_request should tab' do
      msg = new_webmsg("server.tracker.update_request", rt: rt)
      expect(msg).to receive(:render) \
        .with('webui/history/request_tab.html', request_tracker: rt).and_return('htmlxxx')
      expect(msg).to receive(:send_msg) \
        .with('el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: 'htmlxxx')
      web_router.call(msg)
    end

    it 'update_request should tab and detail if rt is current rt' do
      msg = new_webmsg("server.tracker.update_request", rt: rt)
      msg.session[:current_rt] = rt
      expect(msg).to receive(:render) \
        .with('webui/history/request_tab.html', request_tracker: rt).and_return('htmlxxx')
      expect(msg).to receive(:send_msg) \
        .with('el.replace', selector: "#history_rt_tab_#{rt.object_id}", html: 'htmlxxx')
      expect(msg).to receive(:render) \
        .with('webui/history/detail.html', request_tracker: rt).and_return('htmlyyy')
      expect(msg).to receive(:send_msg) \
        .with('el.html', selector: "#history_detail", html: 'htmlyyy')
      web_router.call(msg)
    end
  end
end
