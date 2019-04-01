require 'forwardable'
require 'socket'

class FakeIO
  extend Forwardable

  attr_accessor :reply_data
  attr_reader :name, :io, :rdata, :wdata

  def_delegators(:@io,
    :close, :closed?, :close_write, :close_read, :closed_write?, :closed_read?,
    :flush, :eof?, :sync, :sync=, :remote_address, :local_address, :readpartial
  )

  @socks = {}
  @instances = {}
  @pairs = {}

  def self.clear
    @socks.each { |k, s| s.close unless s.closed? }
    [@socks, @pairs, @instances].each(&:clear)
  end

  def self.pair(sname, tname)
    server_pair(:server, sname, tname)[1..2]
  end

  # rname: remote sock name
  # lname: local sock name
  def self.server_pair(sname, rname, lname)
    sname = "__srv_#{sname}"
    rname, lname = [rname, lname].map { |v| "_s_#{v}".to_sym }
    @pairs[rname], @pairs[lname] = rname, lname
    server = @socks[sname] ||= TCPServer.new('127.0.0.1', 0)
    t = Thread.new { @socks[rname] = server.accept }
    @socks[lname] = TCPSocket.new('127.0.0.1', server.local_address.ip_port)
    t.join

    [
      server,
      @instances[rname] ||= new(rname, @socks[rname]),
      @instances[lname] ||= new(lname, @socks[lname])
    ]
  end

  def self.fetch(name)
    @instances[name.to_sym]
  end

  def self.fetch_target(name)
    @instances[@pairs[name.to_sym]]
  end

  def accept
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

  def to_io
    io.respond_to?(:to_io) ? io.to_io : io
  end

  def copy_to(dst)
    Xjz::IOHelper.forward_streams(self => dst)
  end
end
