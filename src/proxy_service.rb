# frozen_string_literal: true

class ProxyService
  attr_reader :proxy, :history

  def initialize(port)
    @history = {}
    @proxy = EvilProxy::MITMProxyServer.new Port: port
    proxy.before_request(&method(:before_request))
    proxy.before_response(&method(:before_response))
  end

  private

  def before_request(req, *other)
  end

  def before_response(req, res, *other)
    (history[req.host] ||= []) << [req, res]
  end
end
