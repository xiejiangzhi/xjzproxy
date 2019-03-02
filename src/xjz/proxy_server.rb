require 'puma/server'
require 'puma/configuration'

module Xjz
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

    def get_ssl_port
      _, ssl_socket = binder.listeners.find { |a, b| a =~ /^ssl/ }
      @ssl_port ||= ssl_socket.local_address.ip_port
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
      proxy_server = self
      @app ||= Rack::Builder.app do
        use RequestLogger

        use SSLProxy, cb_ssl_port: -> { proxy_server.get_ssl_port }

        use CommonEnv
        use WebUI
        run ProxyRequest.new
      end
    end
  end
end
