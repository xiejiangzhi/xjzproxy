module Xjz
  class Resolver::Forward
    attr_reader :req, :api_project

    def initialize(req, ap = nil)
      @api_project = ap
      @req = req
    end

    def perform
      Logger[:auto].info { "Perform #{req.scheme} #{req.host} by Forward" }
      server_socket = new_remote_socket
      user_socket = req.user_socket
      if req.http_method == 'connect'
        HTTPHelper.write_res_to_conn(
          Response.new({ 'Content-Length' => '0' }, [], 200), user_socket
        )
      else
        req.forward_conn_attrs = true
        server_socket << req.to_s
        server_socket.flush
      end
      IOHelper.forward_streams(
        user_socket => server_socket,
        server_socket => user_socket
      )
    ensure
      user_socket.close rescue nil
      server_socket.close rescue nil
    end

    private

    def new_remote_socket
      socket = Socket.tcp(req.host, req.port, connect_timeout: $config['proxy_timeout'])
      return socket if req.scheme == 'http'

      ctx = OpenSSL::SSL::SSLContext.new
      ctx.alpn_protocols = ['http/1.1']
      ssl_socket = OpenSSL::SSL::SSLSocket.new(socket, ctx)
      ssl_socket.sync_close = true
      ssl_socket.hostname = req.host
      IOHelper.ssl_connect(ssl_socket)
      ssl_socket
    end
  end
end
