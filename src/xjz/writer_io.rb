module Xjz
  # only require << method
  class WriterIO
    attr_reader :writer

    # writer reuqire '<<' method
    def initialize(writer)
      @writer = writer
      @closed = false
    end

    def <<(data)
      raise IOError.new('closed stream') if @closed
      @writer << data
      @writer
    end

    def write(data)
      self << data
      data.length
    end

    def write_nonblock(data)
      self << data
      data.length
    end

    def close_write
      @closed = true
      @writer.close_write if @writer.respond_to?(:close_write)
    end

    def close
      @closed = true
      to_io.close
    end

    def closed?
      @closed
    end

    def closed_write?
      @closed
    end

    def flush; end
    def remote_address; nil; end

    def to_io
      @io ||= File.open(File::NULL, 'w')
    end
  end
end
