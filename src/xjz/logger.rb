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

    def initialize(logdev = $stdout)
      @logger = ::Logger.new(logdev, level: :debug)
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
