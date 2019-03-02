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
  }.each do |name|
    autoload name, "xjz/#{name.underscore}"
  end

  module Reslover
    %w{
      SSL
      HTTP1
      HTTP2
      WebUI
    }.each do |name|
      autoload name, "xjz/reslover/#{name.underscore}"
    end
  end
end
