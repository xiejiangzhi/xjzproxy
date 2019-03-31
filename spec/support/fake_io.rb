require 'forwardable'
require 'socket'

class FakeIO
  extend Forwardable

  attr_accessor :reply_data
  attr_reader :name, :io, :rdata, :wdata

  def_delegators(:@io,
    :close, :closed?, :close_write, :close_read, :closed_write?, :closed_read?,
    :flush
  )

  @socks = {}
  @instances = {}
  @pairs = {}

  def self.clear
    @socks.each { |k, s| s.close unless s.closed? }
    [@socks, @pairs, @instances].each(&:clear)
  end

  def self.pair(sname, tname)
    sname = sname.to_sym
    tname = tname.to_sym
    @pairs[sname] = tname
    @pairs[tname] = sname
    @socks[sname], @socks[tname] = UNIXSocket.pair unless @socks[sname]

    [
      @instances[sname] ||= new(sname, @socks[sname]),
      @instances[tname] ||= new(tname, @socks[tname])
    ]
  end

  def self.fetch(name)
    @instances[name.to_sym]
  end

  def self.fetch_target(name)
    @instances[@pairs[name.to_sym]]
  end

  def initialize(name, io)
    raise "io cannot be nil" unless io
    @name = name.to_sym
    @io = io
    @rdata, @wdata = [], []
    @reply_data = []
  end

  def target
    self.class.fetch_target(name)
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
      target.on_msg
    end
  end

  def write(*args)
    io.method(__method__).call(*args).tap do |r|
      wdata << args.join
      target.on_msg
    end
  end

  def write_nonblock(*args)
    io.method(__method__).call(*args).tap do |r|
      wdata << args.join
      target.on_msg
    end
  end

  def on_msg
    reply, read_len = case reply_data
    when Proc
      [reply_data, 2048]
    else
      reply_data.shift
    end

    msg = read_nonblock(read_len) if read_len
    case reply
    when Proc
      reply.call(msg, self)
    when String
      self << reply
    when nil
      # ignore
    else
      raise "Invalid reply #{reply.inspect}"
    end
  end

  def remote_address
    OpenStruct.new(ip_address: '1.2.3.4', ip_port: 12345)
  end

  def local_address
    OpenStruct.new(ip_address: '127.0.0.1', ip_port: 12345)
  end

  def to_io
    io
  end
end
