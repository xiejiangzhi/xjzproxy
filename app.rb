$app_name = 'XjzProxy'

module Xjz
  require File.expand_path('../env', __FILE__)
  extend ActiveSupport

  %w{
    CertManager

    RequestHelper

    RequestLogger

    Logger

    ProxyServer
    MyPumaServer
    WriterIO

    Request
    Response

    RequestDispatcher

    SSLReslover
    HTTP1Reslover
    HTTP2Reslover
    WebUIReslover
  }.each do |name|
    autoload name, "xjz/#{name.underscore}"
  end
end
