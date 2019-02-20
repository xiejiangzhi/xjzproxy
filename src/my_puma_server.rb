require 'puma/server'
require 'puma/minissl'

Puma::MiniSSL::Context.class_eval do
  def check; end
  def key=(val); end
  def cert=(val); end
end

Puma::MiniSSL::Server.class_eval do
  def self.new(socket, ctx)
    $logger.info("SSL Port: #{socket.local_address.ip_port}")
    OpenSSL::SSL::SSLServer.new(socket, ssl_ctx)
  end

  def self.ssl_ctx
    @ssl_ctx ||= begin
      fetch_ssl_ctx_by_domain('localhost') do |ctx|
        ctx.servername_cb = method(:ssl_cert_cb)
      end
    end
  end

  def self.cert_gen
    @cert_gen ||= CertGen.new
  end

  def self.ssl_cert_cb(args)
    _ssl_socket, server_name = args
    $logger.info "Generate cert for #{server_name}"
    fetch_ssl_ctx_by_domain(server_name)
  end

  def self.fetch_ssl_ctx_by_domain(server_name, &block)
    ctx = OpenSSL::SSL::SSLContext.new
    ctx.add_certificate(cert_gen.issue_cert(server_name), cert_gen.pkey)
    block.call(ctx) if block
    ctx
  end
end

class MyPumaServer < Puma::Server
  def normalize_env(env, client)
    env[REQUEST_PATH] ||= '' if env[REQUEST_METHOD] == 'CONNECT'
    super
  end
end

