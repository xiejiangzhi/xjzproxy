require 'puma/server'
require 'puma/minissl'
require 'openssl'

Puma::MiniSSL::Context.class_eval do
  def check; end
  def key=(val); end
  def cert=(val); end
end

module Xjz::SSLSocketHack
  def read_nonblock(*args)
    super
  rescue OpenSSL::SSL::SSLErrorWaitReadable => e
    Xjz::Logger[:auto].debug { 'Raise IO::EAGAINWaitReadable' }
    raise IO::EAGAINWaitReadable.new(e.message)
  end
end

OpenSSL::SSL::SSLSocket.class_eval do
  prepend Xjz::SSLSocketHack
  alias peercert peer_cert
end

Puma::MiniSSL::Server.class_eval do
  @ssl_ctxs = {}

  def self.new(socket, ctx)
    Xjz::Logger[:auto].info { "SSL Port: #{socket.local_address.ip_port}" }
    OpenSSL::SSL::SSLServer.new(socket, ssl_ctx)
  end

  def self.ssl_ctx
    @ssl_ctx ||= begin
      fetch_ssl_ctx_by_domain('localhost') do |ctx|
        ctx.servername_cb = method(:ssl_cert_cb)
      end
    end
  end

  def self.cert_manager
    @cert_manager ||= Xjz::CertManager.new
  end

  def self.ssl_cert_cb(args)
    _ssl_socket, server_name = args
    fetch_ssl_ctx_by_domain(server_name)
  end

  def self.fetch_ssl_ctx_by_domain(server_name, &block)
    @ssl_ctxs[server_name] ||= begin
      Xjz::Logger[:auto].info { "Generate cert for #{server_name}" }
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

class Xjz::MyPumaServer < Puma::Server
  def normalize_env(env, client)
    env[REQUEST_PATH] ||= '' if env[REQUEST_METHOD] == 'CONNECT'
    super
  end
end
