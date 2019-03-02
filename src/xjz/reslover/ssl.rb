require 'socket'
require 'openssl'

module Xjz
  class Reslover::SSL
    CRLF = "\r\n"

    attr_reader :req

    def initialize(req)
      @req = req
    end

    def perform
      [
        200, { 'connection' => 'close', 'content-length' => 0 },
        SSLProxyBody.new(req, '127.0.0.1', $config['_ssl_proxy_port'])
      ]
    end

    private

    class SSLProxyBody
      attr_reader :server_socket, :req, :user_socket

      def initialize(req, host, port)
        @req = req
        @server_socket = TCPSocket.new(host, port)
        @user_socket = req.user_socket
      end

      def each
        socks_mapping = { server_socket => user_socket, user_socket => server_socket }
        IOHelper.forward_streams(socks_mapping)
      ensure
        user_socket.close_write
        server_socket.close
      end
    end
  end
end
