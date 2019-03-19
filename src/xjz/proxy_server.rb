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
              parse_conn(conn) { |env| app.call(env) }
            ensure
              conn.close unless conn.closed?
            end
          rescue Exception => e
            Logger[:auto].error { "#{e.message}: #{e.backtrace[0]}" }
          end
        rescue Exception
          # rescue logger error, ignore
        end
      end
    end

    def stop
      server_socket.shutdown rescue nil
      server_thread.kill rescue nil
      server_pool.shutdown rescue nil
    end

    def parse_conn(conn, &block)
      parser = HTTPParser.new
      stop_copy = false
      parser.on_finish do |env|
        HTTPHelper.write_conn_info_to_env!(env, conn)
        stop_copy = true
        block.call(env)
      end
      IOHelper.forward_streams(
        { conn => WriterIO.new(parser) },
        stop_wait_cb: proc { stop_copy }
      )
    end
  end
end
