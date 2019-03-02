RSpec.describe Xjz::Logger do
  let(:logdev) { StringIO.new }
  let(:subject) { Xjz::Logger.new(logdev) }

  describe '#prog_logger & #[]' do
    it 'should return a logger of progname' do
      l = subject.prog_logger(:misc)
      l2 = subject[:misc]
      l3 = subject[:app]
      expect(l.object_id).to eql(l2.object_id)
      expect(l.object_id).to_not eql(l3.object_id)
      expect(l).to be_a(Xjz::Logger::ProgLogger)
      expect(l3).to be_a(Xjz::Logger::ProgLogger)

      expect(l.logger).to eql(subject.logger)
      expect(l.progname).to eql('misc')
      expect(l.level).to eql('info')
    end
  end

  describe 'write log' do
    let(:time) { Time.parse('2019-1-1 10:10:10') }
    it 'should write log to logdev' do
      travel_to(time)

      $config['logger']['app'] = 'debug'
      $config['logger']['misc'] = 'info'
      $config['logger']['server'] = 'warn'

      subject[:app].debug { '1' }
      subject[:misc].debug { '2' }
      subject[:misc].info { '3' }
      subject[:server].info { '4' }
      subject[:server].warn { '5' }
      subject[:server].error { '6' }
      subject[:app].fatal { '7' }

      logdev.rewind
      pid = Process.pid
      expect(logdev.read).to eql([
        "D, [2019-01-01T10:10:10.000000 ##{pid}] DEBUG -- app: 1",
        "I, [2019-01-01T10:10:10.000000 ##{pid}]  INFO -- misc: 3",
        "W, [2019-01-01T10:10:10.000000 ##{pid}]  WARN -- server: 5",
        "E, [2019-01-01T10:10:10.000000 ##{pid}] ERROR -- server: 6",
        "F, [2019-01-01T10:10:10.000000 ##{pid}] FATAL -- app: 7",
      ].join("\n") + "\n")
    end
  end

  it '.instance should return a instance' do
    expect(Xjz::Logger.instance).to be_a(Xjz::Logger)
    expect(Xjz::Logger.instance).to eql(Xjz::Logger.instance)
  end

  it '[] should return a prog logger of instance' do
    expect(Xjz::Logger[:app]).to eql(Xjz::Logger.instance[:app])
  end
end
