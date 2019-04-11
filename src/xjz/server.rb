require 'socket'

module Xjz
  class Server
    attr_reader :proxy_socket, :proxy_thread, :proxy_thread_pool, :app
    attr_reader :ui_socket, :ui_thread, :ui_thread_pool

    def initialize
      @proxy_socket = TCPServer.new('0.0.0.0', $config['proxy_port'])
      @ui_socket = TCPServer.new('127.0.0.1', 0)

      @proxy_thread = nil
      @ui_thread = nil
      @app = Rack::Builder.app { run RequestDispatcher.new }
    end

    def start_proxy
      unless @proxy_thread
        @proxy_thread, @proxy_thread_pool = loop_server(proxy_socket, 'Proxy')
      end
    end

    def start_ui
      unless @ui_thread
        @ui_thread, @ui_thread_pool = loop_server(ui_socket, 'UI')
      end
    end

    def stop_proxy
      proxy_socket.shutdown rescue nil
      proxy_thread.kill rescue nil
      proxy_thread_pool.shutdown rescue nil
      @proxy_thread = nil
    end

    def proxy_run?
      @proxy_thread.alive?
    end

    def proxy_url
      addr = proxy_socket.local_address
      "http://#{addr.ip_address}:#{addr.ip_port}"
    end

    private

    def loop_server(server_sock, name = '')
      start_msg = ['New', name, 'connection'].join(' ')
      end_msg = ['Close', name, 'connection'].join(' ')

      thread_pool = Concurrent::ThreadPoolExecutor.new(
         min_threads: 2,
         max_threads: $config['max_threads'],
         max_queue: 512,
         fallback_policy: :discard
      )

      Thread.new do
        loop do
          begin
            conn = server_sock.accept
            thread_pool.post do
              Logger[:auto].info { start_msg }
              HTTPParser.parse_request(conn) { |env| app.call(env) }
            rescue Exception => e
              Logger[:auto].error { e.log_inspect }
            ensure
              Logger[:auto].info { end_msg }
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
  end
end
