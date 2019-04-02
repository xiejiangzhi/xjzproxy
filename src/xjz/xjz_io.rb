require 'forwardable'

module Xjz
  class XjzIO
    extend Forwardable

    # attr_accessor :reply_data
    # attr_reader :name, :io, :rdata, :wdata

    def_delegators(:@io,
      :close, :closed?, :close_write, :close_read, :closed_write?, :closed_read?,
      :flush, :eof?, :sync, :sync=, :remote_address, :local_address, :readpartial,
      :accept, :connect, :accept_nonblock, :connect_nonblock
    )

    def initialize(io)
      raise "io cannot be nil" unless io
      @io = io
    end

    def read(*args)
      io.method(__method__).call(*args).tap { |r| rdata << r }
    end

    def read_nonblock(*args)
      io.method(__method__).call(*args).tap { |r| rdata << r }
    end

    def recv_nonblock(*args)
      io.method(__method__).call(*args).tap { |r| rdata << r }
    end

    def <<(*args)
      io.method(__method__).call(*args).tap do |r|
        wdata << args.join
        target&.on_msg
      end
    end

    def write(*args)
      io.method(__method__).call(*args).tap do |r|
        wdata << args.join
        target&.on_msg
      end
    end

    def write_nonblock(*args)
      io.method(__method__).call(*args).tap do |r|
        wdata << args.join
        target&.on_msg
      end
    end

    def to_io
      io.respond_to?(:to_io) ? io.to_io : File.open(File::NULL)
    end
  end
end
