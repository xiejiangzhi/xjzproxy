require 'logger'

module Xjz
  class Logger
    class << self
      def instance
        @instance ||= self.new
      end

      def [](progname = nil)
        if progname == :auto
          name = caller[0]
          name = caller[0][($root.length + 1)..-1] if name[$root]
          name = name[('src/xjz'.length + 1)..-1] if name[/^src\/xjz/]
          progname = name.split(':', 3)[0..1].join(':')
        end
        instance[progname]
      end
    end

    attr_reader :logger
    LOG_FORMAT = "%-5s [%s #%s] %s -- %s\n"
    KEYS = ('0'..'9').to_a + ('a'..'z').to_a + ('A'..'Z').to_a
    KLEN = KEYS.length
    COLOR_LOG_FORMAT = {
      'DEBUG' => "\e[90m%-5s [%s #%s] %s -- %s\n\e[39m",
      'INFO' => "%-5s [%s #%s] %s -- \e[90m%s\n\e[39m",
      'WARN' => "\e[93m%-5s \e[39m[%s #%s] %s -- \e[90m%s\n\e[39m",
      'ERROR' => "\e[31m%-5s \e[39m[%s #%s] \e[31m%s -- \e[90m%s\n\e[39m",
    }

    def initialize(logdev = $stdout)
      @logger = ::Logger.new(logdev, level: :debug)
      @logger.formatter = proc do |severity, datetime, progname, msg|
        date = datetime.strftime("%Y-%m-%dT%H:%M:%S")
        format = (logdev == $stdout ? COLOR_LOG_FORMAT[severity] : nil) || LOG_FORMAT
        format % [severity, date, decode_int(Thread.current.object_id), msg, progname]
      end
      @prog_loggers = {}
    end

    def prog_logger(progname)
      name = progname.to_s
      @prog_loggers[name] ||= begin
        level = $config['logger_level'][name] || $config['logger_level']['default']
        ProgLogger.new(@logger, name, level || 'info')
      end
    end

    def [](progname)
      prog_logger(progname)
    end

    def decode_int(num)
      str = []
      while num > 0
        str << KEYS[num % KLEN]
        num = num / KLEN
      end
      str.reverse.join
    end

    class ProgLogger
      LEVELS = Hash[%w{debug info warn error fatal}.each_with_index.to_a]

      attr_reader :logger, :progname, :level

      def initialize(logger, progname, level)
        @logger = logger
        @progname = progname
        @level = level
        @level_index = LEVELS[level]
      end

      LEVELS.each do |name, index|
        eval <<-RUBY, binding, __FILE__, __LINE__ + 1
          def #{name}(msg = nil, &block)
            return if LEVELS['#{name}'] < @level_index
            logger.#{name}(@progname, &block)
          end
        RUBY
      end
    end
  end
end
