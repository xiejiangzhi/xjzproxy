require 'socket'

module Xjz
  class Server
    attr_reader :proxy_socket, :proxy_thread, :proxy_thread_pool, :app
    attr_reader :ui_socket, :ui_thread, :ui_thread_pool

    def initialize
      @proxy_socket = nil
      @ui_socket = nil

      @proxy_thread = nil
      @ui_thread = nil
      @app = Rack::Builder.app { run RequestDispatcher.new }
    end

    def start
      start_ui
      start_proxy
    end

    def stop
      stop_proxy
      stop_ui
    end

    def start_proxy
      unless @proxy_socket
        @proxy_socket ||= TCPServer.new('0.0.0.0', $config['proxy_port'])
        Logger[:auto].info { "Start Proxy at port #{proxy_addr}" }
        @proxy_thread, @proxy_thread_pool = loop_server(proxy_socket, 'Proxy')
      end
    rescue Errno::EADDRINUSE => e
      Logger[:auto].error { e.log_inspect }
      nil
    end

    def start_ui
      unless @ui_socket
        @ui_socket ||= TCPServer.new('127.0.0.1', 0)
        Logger[:auto].info { "Start UI at port #{ui_addr}" }
        @ui_thread, @ui_thread_pool = loop_server(ui_socket, 'UI')
      end
    end

    def stop_proxy
      Logger[:auto].info { "Stopping Proxy" }
      stop_server(:proxy)
      @proxy_socket = nil
      @proxy_thread = nil
      Logger[:auto].info { "Proxy Stopped" }
    end

    def stop_ui
      Logger[:auto].info { "Stopping UI" }
      stop_server(:ui)
      @ui_socket = nil
      @ui_thread = nil
      Logger[:auto].info { "UI Stopped" }
    end

    def proxy_run?
      @proxy_thread&.alive?
    end

    def proxy_addr
      addr = proxy_socket.local_address
      ip = (Socket.ip_address_list.detect { |intf| intf.ipv4_private? } || addr).ip_address
      "#{ip}:#{addr.ip_port}"
    end

    def ui_addr
      addr = ui_socket.local_address
      "#{addr.ip_address}:#{addr.ip_port}"
    end

    def total_proxy_conns
      proxy_thread_pool.instance_exec do
        @pool.size - @pool.count do |w|
          w.instance_eval { @thread.inspect =~ /sleep_forever>$/ }
        end
      end
    end

    private

    def stop_server(name)
      socket, thread, thread_pool = case name
      when :proxy
        [proxy_socket, proxy_thread, proxy_thread_pool]
      when :ui
        [ui_socket, ui_thread, ui_thread_pool]
      else
        raise "Invalid server name #{name}"
      end

      if socket
        socket.shutdown rescue nil
        socket.close unless socket.closed?
      end

      thread.kill if thread && thread.alive?
      if thread_pool
        thread_pool.shutdown
        thread_pool.kill
      end
    end

    def loop_server(server_sock, name = '')
      start_msg = ['New', name, 'connection'].join(' ')
      end_msg = ['Close', name, 'connection'].join(' ')

      thread_pool = Concurrent::ThreadPoolExecutor.new(
        min_threads: 2,
        max_threads: $config['max_threads'],
        max_queue: 256,
        fallback_policy: :discard
      )

      t = Thread.new do
        loop do
          conn = server_sock.accept rescue nil
          break unless conn
          begin
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

      [t, thread_pool]
    end
  end
end
