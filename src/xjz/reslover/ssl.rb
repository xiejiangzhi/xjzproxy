require 'socket'
require 'openssl'

module Xjz
  class Reslover::SSL
    attr_reader :req

    def initialize(req)
      @req = req
    end

    def perform
      sock = req.user_socket
      HTTPHelper.write_res_to_conn(Response.new({}, [], 200), sock)

      ssl_sock = OpenSSL::SSL::SSLSocket.new(sock, self.class.ssl_ctx)
      ssl_sock.sync_close
      ssl_sock.accept
      Logger[:auto].debug { "SSLSocket Accepted" }

      HTTPParser.parse_request(ssl_sock) do |env|
        RequestDispatcher.new.call(env)
      end
    end

    private

    def self.ssl_ctx
      @ssl_ctx ||= begin
        fetch_ssl_ctx_by_domain('localhost') do |ctx|
          ctx.servername_cb = method(:ssl_cert_cb)
        end
      end
    end

    def self.cert_manager
      @cert_manager ||= CertManager.new
    end

    def self.ssl_cert_cb(args)
      _ssl_socket, server_name = args
      fetch_ssl_ctx_by_domain(server_name)
    end

    def self.fetch_ssl_ctx_by_domain(server_name, &block)
      @ssl_ctxs ||= {}
      @ssl_ctxs[server_name] ||= begin
        Logger[:auto].info { "Generate cert for #{server_name}" }
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.add_certificate(cert_manager.issue_cert(server_name), cert_manager.pkey)
        server_protocols = %w{h2 http/1.1}
        # ctx.alpn_protocols = ["http/1.1", "spdy/2", "h2"]
        ctx.alpn_select_cb = lambda do |protocols|
          (server_protocols & protocols).first
        end
        block.call(ctx) if block
        ctx
      end
    end
  end
end
