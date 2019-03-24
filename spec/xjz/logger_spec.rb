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
      expect(l.level).to eql('debug')
    end
  end

  describe 'write log' do
    let(:time) { Time.parse('2019-1-1 10:10:10') }
    it 'should write log to logdev' do
      travel_to(time)

      allow($config['logger_level']).to receive('[]') do |name|
        {
          'app' => 'debug', 'misc' => 'info', 'server' => 'warn'
        }[name]
      end
      Thread.current[:first_log_time] = nil
      Thread.current[:last_log_time] = nil

      subject[:app].debug { '1' }
      subject[:misc].debug { '2' }
      subject[:misc].info { '3' }
      subject[:server].info { '4' }
      subject[:server].warn { '5' }
      subject[:server].error { '6' }
      subject[:app].fatal { '7' }

      logdev.rewind
      tid = subject.decode_int(Thread.current.object_id)
      expect(logdev.read).to eql(<<~LOG
        DEBUG [2019-01-01T10:10:10 ##{tid}] 1 -- 0.000 0.000 app
        INFO  [2019-01-01T10:10:10 ##{tid}] 3 -- 0.000 0.000 misc
        WARN  [2019-01-01T10:10:10 ##{tid}] 5 -- 0.000 0.000 server
        ERROR [2019-01-01T10:10:10 ##{tid}] 6 -- 0.000 0.000 server
        FATAL [2019-01-01T10:10:10 ##{tid}] 7 -- 0.000 0.000 app
      LOG
      )
    end
  end

  it '.instance should return a instance' do
    expect(Xjz::Logger.instance).to be_a(Xjz::Logger)
    expect(Xjz::Logger.instance).to eql(Xjz::Logger.instance)
  end

  it '[] should return a prog logger of instance' do
    expect(Xjz::Logger[:app]).to eql(Xjz::Logger.instance[:app])
    expect(Xjz::Logger[:auto].progname).to eql("spec/xjz/logger_spec.rb")
  end
end
