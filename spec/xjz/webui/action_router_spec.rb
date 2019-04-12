RSpec.describe Xjz::WebUI::ActionRouter do
  describe '.register' do
    it 'should update default router' do
      allow(described_class).to receive(:default).and_return(described_class.new)

      p = proc { 1 }
      expect {
        described_class.register { event('a', &p)  }
      }.to change { described_class.default.events }.to('a' => p)
    end
  end

  describe '#call' do
    def new_msg(type, data)
      OpenStruct.new(r: [], type: type, data: type)
    end

    before :each do
      subject.namespace('proxy') do
        namespace 'click' do
          event('wait') { r << :p0 }
        end
        event('click.start') { r << :p1 }
        event(/^click.stop$/) { r << :p2 }
      end
      subject.namespace(/report/) do
        event('invalid') { r << :r1 }
        event('report.valid') { r << :r2 }
      end
      subject.event('click.start') { r << :c1 }
      subject.event('t.return') { return 123 }
    end

    it 'should return true if has a matched action' do
      msg = new_msg('proxy.click.start', 'hello')
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:p1])

      msg = new_msg('proxy.click.stop', nil)
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:p2])

      msg = new_msg('report.valid', 123)
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:r2])

      msg = new_msg('click.start', 123)
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:c1])
    end

    it 'should return false if has a invalid action' do
      msg = new_msg('proxy.click.invalid', 123)
      expect {
        expect(subject.call(msg)).to eql(false)
      }.to_not change { msg.r }

      msg = new_msg('report.invalid', 123)
      expect {
        expect(subject.call(msg)).to eql(false)
      }.to_not change { msg.r }

      msg = new_msg('asdf.proxy.click.invalid', 'hello')
      expect {
        expect(subject.call(msg)).to eql(false)
      }.to_not change { msg.r }
    end

    it 'should raise error when return in action' do
      msg = new_msg('t.return', nil)
      expect {
        subject.call(msg)
      }.to raise_error(LocalJumpError)
    end
  end
end
