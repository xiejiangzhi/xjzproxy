require 'puma'
require 'puma/configuration'
require 'puma/server'

class ProxyServer < Puma::Server
  def normalize_env(env, client)
    env[REQUEST_PATH] ||= '' if env[REQUEST_METHOD] == 'CONNECT'
    super
  end
end

class Server
  attr_reader :server, :events, :binder

  def initialize
    @events = Puma::Events.stdio
    @binder = Puma::Binder.new(events)
    @server = ProxyServer.new app, events, options
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
    method(:on_request)
  end

  def on_request(env)
    puts env.inspect
    [200, {}, ["hello world"]]
  end
end



