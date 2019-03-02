require 'logger'

module Xjz
  class Logger
    class << self
      def instance
        @instance ||= self.new
      end

      def [](name)
        instance.get_logger(name)
      end
    end

    def initialize
      @loggers = {}
    end

    def get_logger(name)
      name = name.to_s
      @loggers[name] ||= begin
        level = $config['logger'][name]
        raise "Undefined logger '#{name}'" unless level
        ::Logger.new($stdout, level: level, progname: name)
      end
    end
  end
end
