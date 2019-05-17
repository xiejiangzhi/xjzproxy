RSpec.describe Xjz::Tracker do
  let(:tracker) { Xjz::Tracker.new }
  let(:req) { OpenStruct.new(api_project: nil) }

  before :each do
    allow($config.shared_data.app.webui).to receive(:emit_message)
  end

  describe 'track_req' do
    it 'should save request tracker' do
      t1 = nil
      expect {
        t1 = tracker.track_req(req, api_project: 'ap123')
      }.to change(req, :api_project).to('ap123')
      t2 = tracker.track_req('req2')
      expect(tracker.history).to eql([t1, t2])
    end
  end

  describe 'RequestTracker' do
    let(:time) { Time.now }
    let(:req_tracker) { tracker.track_req('req') }

    it 'should save data and time' do
      travel_to(time - 1)
      req_tracker

      travel_to(time)
      req_tracker.track 'a'

      travel_to(time + 1)
      req_tracker.track('b') { travel_to(time + 2) }

      travel_to(time + 3)
      req_tracker.track 'c'

      travel_to(time + 4.5123)
      req_tracker.instance_eval { @diff = 123 }
      # reset diff
      expect {
        req_tracker.finish('res')
      }.to change { req_tracker.instance_variable_get(:@diff) }.to(nil)

      expect(req_tracker.action_list).to eql([
        ['start', [time - 1]],
        ['a', [time]], ['b', [time + 1, time + 2]], ['c', [time + 3]],
        ['finish', [time + 4.5123]]
      ])
      expect(req_tracker.action_hash).to eql(
        'start' => [time - 1],
        'a' => [time], 'b' => [time + 1, time + 2], 'c' => [time + 3],
        'finish' => [time + 4.5123]
      )
      expect(req_tracker.request).to eql('req')
      expect(req_tracker.response).to eql('res')
      expect(req_tracker.cost).to eql(5.5123)
      expect(req_tracker.start_at).to eql(time - 1)
      expect(req_tracker.end_at).to eql(time + 4.5123)
    end

    it '#finish should set api_project if exists api_project' do
      allow(req_tracker).to receive(:api_project).and_return('ap-xxx')
      res = OpenStruct.new(api_project: nil)
      expect {
        req_tracker.finish(res)
      }.to change { res.api_project }.to('ap-xxx')
    end

    it 'should not track start if auto_start is false' do
      travel_to(time)
      rt = tracker.track_req('req', auto_start: false)
      rt.track('a')
      expect(rt.action_list).to eql([['a', [time]]])
      expect(rt.action_hash).to eql('a' => [time])
      expect(rt.request).to eql('req')
      expect(rt.response).to eql(nil)
    end

    it '#api_desc should return api data for HTTP request' do
      req = double('req', http_method: 'hm', scheme: 'https', host: 'xjz.pw', path: 'ppp')
      ap = double('ap', find_api: nil, grpc: nil)
      allow(req_tracker).to receive(:request).and_return(req)
      allow(req_tracker).to receive(:api_project).and_return(ap)
      expect(ap).to receive(:find_api).with('hm', 'ppp').and_return(v: 'desc')
      expect(req_tracker.api_desc).to eql([:http, { v: 'desc' }])
    end

    it '#api_desc should return api data of GRPC request ' do
      req = double('req', path: '/Hw/Xxx')
      grpc = double('grpc', res_desc: nil)
      ap = double('ap', find_api: nil, grpc: grpc)
      allow(req_tracker).to receive(:request).and_return(req)
      allow(req_tracker).to receive(:api_project).and_return(ap)
      expect(grpc).to receive(:res_desc).with(req.path).and_return(v: 'desc1')
      expect(req_tracker.api_desc).to eql([:grpc, { v: 'desc1' }])
    end

    it '#diff should return diff data' do
      req = double(
        'req',
        http_method: 'hm', scheme: 'https', host: 'xjz.pw',
        path: 'ppp', proxy_headers: [['x-token', 'ttt']],
        query_hash: { 'a' => 1 }, body_hash: { 'b' => 2 },
        params: { 'a' => 1, 'b' => 2 }
      )
      res = double(
        'res',
        code: 200, h2_headers: [['content-type', 'application/json']],
        body_hash: { 'c' => 3 }
      )
      api_desc = {
        method: 'get',
        query: { 'q' => 1 },
        body: { 'b' => 2 },
        params: { 'p' => 'zz' },
        headers: { 'x-token' => 'zzz' },
        response: {
          success: {
            http_code: 201,
            headers: { 'h' => '123' },
            data: { 'rd' => 123 }
          }
        }
      }.deep_stringify_keys
      succ_desc = api_desc['response']['success']

      ap = double('ap', find_api: nil, grpc: nil)
      allow(req_tracker).to receive(:request).and_return(req)
      allow(req_tracker).to receive(:response).and_return(res)
      allow(req_tracker).to receive(:api_project).and_return(ap)
      expect(ap).to receive(:find_api).with('hm', 'ppp').and_return(api_desc)

      pd = double("params diff", diff: "err")
      expect(Xjz::ParamsDiff).to receive(:new).with({}).and_return(pd).exactly(5).times
      expect(Xjz::ParamsDiff).to receive(:new).with(allow_extend: true).and_return(pd).twice

      [
        [api_desc['query'], req.query_hash, 1],
        [api_desc['body'], req.body_hash, '2'],
        [api_desc['params'], req.params, 'a'],
        [api_desc['headers'], Hash[req.proxy_headers], 'c'],
        [succ_desc['http_code'], res.code, 'aa'],
        [succ_desc['headers'], Hash[res.h2_headers], 'bb'],
        [succ_desc['data'], res.body_hash, 'e']
      ].each do |e, a, r|
        expect(pd).to receive(:diff).with(e, a, 'Data').and_return(r)
      end

      expect(req_tracker.diff).to eql(
        query: 1,
        req_body: '2',
        params: 'a',
        req_headers: 'c',
        code: 'aa',
        res_headers: 'bb',
        res_body: 'e'
      )
    end
  end

  it '.instance should return one instance' do
    expect(Xjz::Tracker.instance).to be_a(Xjz::Tracker)
    expect(Xjz::Tracker.instance).to eql(Xjz::Tracker.instance)
  end

  it '.track_req should forward to instance' do
    expect(Xjz::Tracker.instance).to receive(:track_req).with('req', auto_start: false)
    Xjz::Tracker.track_req('req', auto_start: false)
  end

  it '.clean_all should clean all history' do
    tracker.track_req('req')
    expect {
      tracker.clean_all
    }.to change(tracker, :history).to([])
  end
end
