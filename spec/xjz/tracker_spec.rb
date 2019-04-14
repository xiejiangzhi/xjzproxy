RSpec.describe Xjz::Tracker do
  let(:tracker) { Xjz::Tracker.new }
  describe 'track_req' do
    it 'should save request tracker' do
      t1 = tracker.track_req('req1')
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
      req_tracker.finish('res')

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

    it 'should not track start if auto_start is false' do
      travel_to(time)
      rt = tracker.track_req('req', auto_start: false)
      rt.track('a')
      expect(rt.action_list).to eql([['a', [time]]])
      expect(rt.action_hash).to eql('a' => [time])
      expect(rt.request).to eql('req')
      expect(rt.response).to eql(nil)
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
