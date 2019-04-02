require 'forwardable'
require 'socket'

class FakeIO
  extend Forwardable

  attr_accessor :reply_data, :sslsock
  attr_reader :name, :io, :rdata, :wdata

  def_delegators(:@io,
    :close, :closed?, :close_write, :close_read, :closed_write?, :closed_read?,
    :flush, :eof?, :sync, :sync=, :remote_address, :local_address
  )

  @socks = {}
  @instances = {}
  @pairs = {}

  def self.clear
    @socks.each { |k, s| s.close unless s.closed? }
    [@socks, @pairs, @instances].each(&:clear)
  end

  def self.pair(pair_name = nil)
    server_pair(pair_name)[1..2]
  end

  # rname: remote sock name
  # lname: local sock name
  def self.server_pair(pair_name = nil, sname = nil)
    sname = "srv_#{sname || :default}".to_sym
    pair_name ||= "p_#{Time.now.to_f}_#{rand(100000)}"
    rname, lname = ["sr_#{pair_name}", "sl_#{pair_name}"].map(&:to_sym)
    @pairs[rname], @pairs[lname] = lname, rname

    server = @socks[sname] ||= TCPServer.new('127.0.0.1', 0)
    unless @socks[rname] || @socks[lname]
      t = Thread.new { @socks[rname] = server.accept }
      @socks[lname] = TCPSocket.new('127.0.0.1', server.local_address.ip_port)
      t.join
    end

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

  def self.fetch_by_io(io)
    @instances.values.find { |ist| ist.io == io }
  end

  def self.hijack_socket!(b)
    eval(<<~CODE, b)
      som = OpenSSL::SSL::SSLSocket.method(:new)
      allow(OpenSSL::SSL::SSLSocket).to receive(:new) do |*args|
        som.call(*args).tap { |sslsock| FakeIO.watch_sslsocket(sslsock) }
      end
    CODE
  end

  def self.watch_sslsocket(sslsock)
    fio = FakeIO.fetch_by_io(sslsock.io)
    return unless fio && fio.sslsock.nil?
    fio.sslsock = sslsock

    sslsock.instance_eval do
      %w{read read_nonblock readpartial}.each do |m|
        om = method(m)
        define_singleton_method(m) do |*args|
          om.call(*args).tap { |r| fio.rdata << r if fio }
        end
      end

      %w{<< write write_nonblock}.each do |m|
        om = method(m)
        define_singleton_method(m) do |*args|
          om.call(*args).tap do
            fio.wdata << args.first
            fio.target&.on_msg(ssl: true)
          end
        end
      end
    end
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

  %w{read read_nonblock readpartial}.each do |m|
    eval <<~CODE
      def #{m}(*args)
        io.method(__method__).call(*args).tap { |r| rdata << r }
      end
    CODE
  end

  %w{<< write write_nonblock}.each do |m|
    eval <<~CODE
      def #{m}(*args)
        io.method(__method__).call(*args).tap do |r|
          wdata << args.first
          target&.on_msg
        end
      end
    CODE
  end

  def on_msg(ssl: false)
    reply, read_len = case reply_data
    when Proc
      reply_data
    else
      reply_data.shift
    end

    if reply
      raise "Timeout to read data" unless IO.select([to_io], nil, nil, 1)
      sock = ssl ? self.sslsock : self
      msg = read_len ? sock.readpartial(read_len) : sock.readpartial(4096)

      case reply
      when Proc
        reply.call(msg, sock)
      when String
        sock << reply
      else
        raise "Invalid reply #{reply.inspect}"
      end
    end
  end

  def to_io
    io.respond_to?(:to_io) ? io.to_io : io
  end

  def copy_to(dst)
    Xjz::IOHelper.forward_streams(self => dst)
  end

  def ssl_accept
    raise "SSL Socket initied" if @sslsock
    self.class.watch_sslsocket(OpenSSL::SSL::SSLSocket.new(io, Xjz::Reslover::SSL.ssl_ctx))
    sslsock.accept
  end

  def ssl_connect
    raise "SSL Socket initied" if @sslsock
    self.class.watch_sslsocket(OpenSSL::SSL::SSLSocket.new(io))
    sslsock.connect
  end

  def tread(len = 1024)
    if IO.select([io], nil, nil, $config['proxy_timeout'])
      read_nonblock(len)
    else
      raise "Read data timeout"
    end
  end
end
