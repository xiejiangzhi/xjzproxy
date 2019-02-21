require 'puma/configuration'

class ProxyServer
  attr_reader :server, :events, :binder

  def initialize
    @events = Puma::Events.stdio
    @binder = Puma::Binder.new(events)
    @server = MyPumaServer.new app, events, options
    @server_thread = nil
    Puma::MiniSSL::Context.new
  end

  def start
    binder.parse(options[:binds], events)
    server.min_threads = options[:min_threads]
    server.max_threads = options[:max_threads]
    server.inherit_binder binder
    @server_thread = server.run
  end

  def stop
    server.stop
  end

  def options
    @options ||= conf.options
  end

  def conf
    @conf ||= Puma::Configuration.new do |config|
      config.bind "tcp://0.0.0.0:#{$config['proxy_port']}"
      config.bind "ssl://0.0.0.0:0?cert=auto&key=auto"
      config.threads 1, $config['max_threads']
    end
  end

  def app
    @app ||= Rack::Builder.app do
      use RequestLogger

      use WebUI

      use SSLProxy

      use Rack::Chunked
      run ProxyRequest.new
    end
  end
end
