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

  class SSLProxyBody
    attr_reader :server_socket, :env, :client_socket


    def initialize(env, host, port)
      @env = env
      @server_socket = TCPSocket.new(host, port)
      @client_socket = env['puma.socket']
    end

    def each
      socks_mapping = { server_socket => client_socket, client_socket => server_socket }
      RequestHelper.forward_streams(socks_mapping)
    ensure
      client_socket.close_write
      server_socket.close
    end
  end
end
