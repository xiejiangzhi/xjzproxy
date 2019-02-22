require 'socket'
require 'openssl'

class SSLProxy
  attr_reader :cert_gen

  CRLF = "\r\n"

  def initialize(app, cb_ssl_port: nil)
    @app = app
    @cb_ssl_port = cb_ssl_port
    @ssl_port = nil
  end

  def call(env)
    if env['REQUEST_METHOD'] == 'CONNECT'
      @ssl_port ||= @cb_ssl_port.call
      [
        200, { 'connection' => 'close', 'content-length' => 0 },
        SSLProxyBody.new(env, '127.0.0.1', @ssl_port)
      ]
    else
      @app.call(env)
    end
  end

  private

  def process_connect(env, local_ssl_port)
  end

  class SSLProxyBody
    attr_reader :server_socket, :env, :client_socket

    BUFFER_SIZE = 4096

    def initialize(env, host, port)
      @env = env
      @server_socket = TCPSocket.new(host, port)
      @client_socket = env['puma.socket']
    end

    def each
      socks_mapping = { server_socket => client_socket, client_socket => server_socket }
      socks = socks_mapping.keys

      loop do
        break if socks.empty?
        rs, _ = IO.select(socks, [], [], 60)
        break unless rs
        rs.each do |sock|
          to = socks_mapping[sock]
          unless copy_stream(sock, to)
            socks.delete(sock)
            AppLogger[:ssl_proxy].debug "SSLProxy copy finished #{sock.inspect} to #{to.inspect}"
          end
        end
      end
    ensure
      client_socket.close_write
      server_socket.close
    end

    # Return false if eof
    def copy_stream(from, to)
      loop do
        data = from.read_nonblock(BUFFER_SIZE)
        AppLogger[:ssl_proxy].debug "SSLProxy copy #{data.length} bytes to #{to.inspect}"
        if data && data != ''
          to.write(data)
        else
          AppLogger[:ssl_proxy].debug "SSLProxy #{from.inspect} eof"
          to.close_write
          break false
        end
      end
    rescue IO::EAGAINWaitReadable, Errno::EINTR
      true
    ensure
      to.flush
    end
  end
end
