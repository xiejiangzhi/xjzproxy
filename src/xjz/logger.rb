require 'logger'

module Xjz
  class Logger
    class << self
      def instance
        @instance ||= self.new
      end

      def [](progname = nil)
        if progname == :auto
          name = caller[0].to_s
          name = name.delete_prefix($root + '/') if name[$root]
          name = name.delete_prefix('src/xjz/') if name[/^src\/xjz/]
          progname, line, _ = name.split(':', 3)
        end
        instance["#{progname}:#{line}"]
      end
    end

    attr_reader :logger
    LOG_FORMAT = "%-5s [%s #%s] %s -- %.3f %.3f %s\n"
    KEYS = ('0'..'9').to_a + ('a'..'z').to_a + ('A'..'Z').to_a
    KLEN = KEYS.length
    COLOR_LOG_FORMAT = {
      'DEBUG' => "\e[90m%-5s [%s #%s] %s -- %.3fms %.3fs %s\e[39m\n",
      'INFO' => "\e[39m%-5s [%s #%s] %s -- \e[90m%.3fms %.3fs %s\e[39m\n",
      'WARN' => "\e[93m%-5s \e[39m[%s #%s] %s -- \e[90m%.3fms %.3fs %s\e[39m\n",
      'ERROR' => "\e[31m%-5s \e[39m[%s #%s] \e[31m%s -- \e[90m%.3fms %.3fs %s\e[39m\n",
      'FATAL' => "\e[31m%-5s \e[39m[%s #%s] \e[31m%s -- \e[90m%.3fms %.3fs %s\e[39m\n"
    }

    def initialize(logdev = $logdev)
      @logger = ::Logger.new(logdev, level: :debug)
      @logger.formatter = proc do |severity, datetime, progname, msg|
        date = datetime.strftime("%Y-%m-%dT%H:%M:%S")
        ts_diff, ts_cost = time_info
        format = get_formatter(logdev || $stdout, severity)
        format % [
          severity, date, decode_int(Thread.current.object_id), msg,
          ts_diff, ts_cost, progname
        ]
      end
      @prog_loggers = {}
    end

    def prog_logger(progname)
      name = progname.to_s
      @prog_loggers[name] ||= begin
        level = if $config
          $config['logger_level'][name] || $config['logger_level']['default']
        end
        ProgLogger.new(@logger, name, level || 'debug')
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

    def time_info
      ct = Time.now
      ft = (Thread.current[:first_log_time] ||= ct)
      lt = (Thread.current[:last_log_time] || ct)
      Thread.current[:last_log_time] = ct
      [(ct - lt) * 1000, ct - ft]
    end

    def get_formatter(logdev, severity)
      return LOG_FORMAT if logdev != $stdout
      COLOR_LOG_FORMAT[severity] || COLOR_LOG_FORMAT['INFO']
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

      def reset_ts
        Thread.current[:first_log_time] = nil
        Thread.current[:last_log_time] = nil
      end

      LEVELS.each do |name, index|
        eval <<-RUBY, binding, __FILE__, __LINE__ + 1
          def #{name}(msg = nil, &block)
            return if LEVELS['#{name}'] < @level_index
            block ||= proc { msg }
            logger.#{name}(@progname, &block)
          end
        RUBY
      end
    end
  end
end
