require 'puma/configuration'

class ProxyServer
  attr_reader :server, :events, :binder

  def initialize
    @events = Puma::Events.stdio
    @binder = Puma::Binder.new(events)
    @server = MyPumaServer.new app, events, options
    @server_thread = nil
  end

  def start
    binder.parse(options[:binds], events)
    server.min_threads = options[:min_threads]
    server.max_threads = options[:max_threads]
    server.inherit_binder binder
    @server_thread = server.run
  end

  def options
    @options ||= conf.options
  end

  def conf
    cert = $cert_gen.issue_cert('default.dev')
    File.write($config['default_cert_path'], cert.to_pem)
    @conf ||= Puma::Configuration.new do |config|
      config.bind 'tcp://0.0.0.0:9898'
      config.bind "ssl://0.0.0.0:9899?key=#{$config['key_path']}&cert=#{$config['default_cert_path']}"
      config.threads 1, 1
    end
  end

  def app
    @app ||= Rack::Builder.app do
      use Rack::CommonLogger
      # use RequestLogger
      use WebUI

      run ProxyRequest.new(ssl_port: 9899)
    end
  end
end
