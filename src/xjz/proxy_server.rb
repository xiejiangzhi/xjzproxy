require 'socket'

module Xjz
  class ProxyServer
    attr_reader :server_socket, :server_thread, :thread_pool, :app

    def initialize
      @server_socket = TCPServer.new($config['proxy_port'])
      @thread_pool = Concurrent::ThreadPoolExecutor.new(
         min_threads: 2,
         max_threads: $config['max_threads'],
         max_queue: 512,
         fallback_policy: :discard
      )
      @server_thread = nil
      @app = Rack::Builder.app { run RequestDispatcher.new }
    end

    def start
      @server_thread = Thread.new do
        loop do
          begin
            conn = server_socket.accept
            thread_pool.post do
              Logger[:auto].info { "New connection" }
              HTTPParser.parse_request(conn) { |env| app.call(env) }
            rescue Exception => e
              Logger[:auto].error { e.log_inspect }
            ensure
              Logger[:auto].info { "Close connection" }
              Logger[:auto].reset_ts
              conn.close unless conn.closed?
            end
          rescue Exception => e
            Logger[:auto].error { e.log_inspect }
          end
        rescue Exception => e
          puts e.log_inspect
          # rescue logger error and ignore it
        end
      end
    end

    def stop
      server_socket.shutdown rescue nil
      server_thread.kill rescue nil
      server_pool.shutdown rescue nil
    end
  end
end
