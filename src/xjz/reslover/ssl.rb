require 'socket'
require 'openssl'

module Xjz
  class Resolver::SSL
    attr_reader :req

    def initialize(req)
      @req = req
    end

    def perform
      Logger[:auto].info { "Perform by SSL" }
      sock = req.user_socket
      HTTPHelper.write_res_to_conn(Response.new({ 'Content-Length' => '0' }, [], 200), sock)

      ssl_sock = OpenSSL::SSL::SSLSocket.new(sock, self.class.ssl_ctx)
      ssl_sock.sync_close
      ssl_sock.accept
      IOHelper.set_proxy_host_port(ssl_sock, req.host, req.port)
      Logger[:auto].debug { "SSLSocket Accepted" }

      HTTPParser.parse_request(ssl_sock) do |env|
        RequestDispatcher.new.call(env)
      end
    end

    def self.reset_certs
      @ssl_ctx = nil
      @ssl_ctxes.clear if @ssl_ctxes
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
      @ssl_ctxes ||= {}
      @ssl_ctxes[server_name] ||= begin
        Logger[:auto].info { "Generate cert for #{server_name}" }
        ctx = OpenSSL::SSL::SSLContext.new
        ctx.add_certificate(cert_manager.issue_cert(server_name), cert_manager.pkey)
        server_protocols = $config['alpn_protocols'] || %w{h2 http/1.1}
        ctx.alpn_select_cb = lambda do |protocols|
          Logger[:auto].info { "Client protocols #{protocols} & Server protocols #{server_protocols}" }
          (server_protocols & protocols).first || 'http/1.1'
        end
        block.call(ctx) if block
        ctx
      end
    end
  end
end
