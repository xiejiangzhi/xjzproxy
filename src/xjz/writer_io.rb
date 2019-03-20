module Xjz
  class WriterIO
    attr_reader :writer

    # writer reuqire '<<' method
    def initialize(writer)
      @writer = writer
    end

    def write(data)
      @writer << data
    end

    def close_write
      @writer.close_write if @writer.respond_to?(:close_write)
    end

    def flush; end

    def remote_address
      nil
    end
  end
end
