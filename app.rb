$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)
  extend ActiveSupport

  %w{
    CertManager
    RequestHelper
    RequestLogger
    Logger
    SSLProxy
    WebUI
    ProxyServer
    ProxyRequest
    MyPumaServer
    HTTP1Response
    HTTP2Response
    CommonEnv
  }.each do |name|
    autoload name, "xjz/#{name.underscore}"
  end
end

