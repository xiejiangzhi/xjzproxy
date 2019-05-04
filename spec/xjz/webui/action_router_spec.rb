RSpec.describe Xjz::WebUI::ActionRouter do
  describe '.register' do
    it 'should update default router' do
      allow(described_class).to receive(:default).and_return(described_class.new)

      p = proc { 1 }
      expect {
        described_class.register('a') { event('a', &p)  }
      }.to change { described_class.default.events }.to('a' => p)
    end
  end

  describe '#call' do
    def new_msg(type, data = {})
      OpenStruct.new(
        r: [],
        type: type,
        data: data.with_indifferent_access,
        runner: nil
      )
    end

    before :each do
      subject.register('a') do
        namespace('proxy') do
          namespace 'click' do
            event('wait') { msg.r << :p0 }
          end
          event('click.start') { msg.r << :p1 }
          event(/^click.(stop)$/) { msg.r << :p2; msg.runner = self }
        end

        namespace(/report/) do
          event('invalid') { msg.r << :r1 }
          event('report.valid') { msg.r << :r2 }
        end

        event('click.start') { msg.r << :c1 }
        event('t.return') { return 123 }
        event('t.help') { asdf(self) }

        helpers do
          def asdf(obj)
            obj.data[:a] = 'asdf'
          end
        end
      end
    end

    it 'should return true if has a matched action' do
      msg = new_msg('proxy.click.start', v: 'hello')
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:p1])

      msg = new_msg('proxy.click.stop')
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:p2])
      md = msg.runner.match_data
      expect(md).to be_a(MatchData)
      expect(md[0]).to eql('click.stop')
      expect(md[1]).to eql('stop')

      msg = new_msg('report.valid', v: 123)
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:r2])

      msg = new_msg('click.start', v: 123)
      expect {
        expect(subject.call(msg)).to eql(true)
      }.to change { msg.r }.to([:c1])
    end

    it 'should return false if has a invalid action' do
      msg = new_msg('proxy.click.invalid', v: 123)
      expect {
        expect(subject.call(msg)).to eql(false)
      }.to_not change { msg.r }

      msg = new_msg('report.invalid', v: 123)
      expect {
        expect(subject.call(msg)).to eql(false)
      }.to_not change { msg.r }

      msg = new_msg('asdf.proxy.click.invalid', v: 'hello')
      expect {
        expect(subject.call(msg)).to eql(false)
      }.to_not change { msg.r }
    end

    it 'should raise error when return in action' do
      msg = new_msg('t.return')
      expect {
        subject.call(msg)
      }.to raise_error(LocalJumpError)
    end

    it 'should allow define helper methods' do
      msg = new_msg('t.help', a: 1)
      expect {
        subject.call(msg)
      }.to change { msg.data[:a] }.to('asdf')
    end

    it 'should not call other register helper method' do
      subject.register('b') do
        event('aaa') { asdf(self) }
      end
      msg = new_msg('aaa', a: 1)
      expect {
        subject.call(msg)
      }.to raise_error(/undefined method `asdf'/)
    end
  end
end
