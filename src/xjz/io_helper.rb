module Xjz
  module IOHelper
    extend self

    BUFFER_SIZE = 4096

    # read stream
    # Return
    #   true: ok, wait or EINTR. wait next
    #   false: stop, eof. End of this socket
    def read_nonblock(src, &recv_block)
      data = src.read_nonblock(BUFFER_SIZE)
      unless data.empty?
        Logger[:auto].debug { "#{data.bytesize} bytes < #{io_inspect(src)}" }
        recv_block.call(data)
        true
      else
        false
      end
    rescue IO::EAGAINWaitReadable, Errno::EINTR, OpenSSL::SSL::SSLErrorWaitReadable
      true
    rescue Errno::ECONNRESET, EOFError, Errno::ETIMEDOUT
      false
    end

    def write_nonblock(dst, data, &block)
      byte_len = dst.write_nonblock(data)
      Logger[:auto].debug { "#{byte_len} bytes > #{io_inspect(dst)}" }
      block ? block.call(byte_len) : data.slice!(0, byte_len)
    rescue IO::WaitWritable, Errno::EINTR, OpenSSL::SSL::SSLErrorWaitWritable
      # ignore
    end

    # Params
    #   streams_mapping:
    #     read_stream => write_stream
    #   timeout: seconds
    #   stop_wait_cb: proc, stop check stream if return true
    # Return:
    #   true: completed
    #   false: timeout, or
    #
    def forward_streams(streams_mapping, timeout: $config['proxy_timeout'], stop_wait_cb: nil)
      readers = streams_mapping.keys
      writers = []
      rs = readers
      ws = []
      buffers = {}
      ws_data_end = {}

      loop do
        rs.each do |src|
          dst = streams_mapping[src]
          buffers[dst] ||= ''
          next if read_nonblock(src) { |data| writers << dst; buffers[dst] << data }
          # src eof
          ws_data_end[dst] = true
          readers.delete(src)
        end
        ws.each do |dst|
          data = buffers[dst]
          write_nonblock(dst, data)
          writers.delete(dst) if data.empty?
        end
        ws_data_end.delete_if do |dst, data_end|
          if data_end && buffers[dst].empty?
            Logger[:auto].debug { "Write completed #{io_inspect(dst)}" }
            dst.close_write if dst.respond_to?(:close_write)
            true
          else
            # wait write data
            false
          end
        end

        return true if readers.empty? && writers.empty?
        rs, ws, es = io_select([readers, writers], timeout, stop_wait_cb)
        return false if rs.nil? || ws.nil? # timeout or stop
        unless es.empty?
          Logger[:auto].error do
            "Stop forward streams, error streams: #{es.map(&method(:io_inspect))}"
          end
          return false
        end
      end
    end

    def io_inspect(stream)
      case stream
      when OpenSSL::SSL::SSLSocket
        ad = stream.to_io.remote_address
        [ad.ip_address, ad.ip_port].join(':')
      when TCPSocket
        ad = stream.remote_address
        [ad.ip_address, ad.ip_port].join(':')
      when WriterIO
        stream.writer.class
      when IO
        "io-#{stream.fileno}"
      else
        if stream.respond_to?(:remote_address)
          ad = stream.remote_address
          [ad.ip_address, ad.ip_port].join(':')
        else
          stream.inspect
        end
      end
    rescue => e
      Logger[:auto].error { e.log_inspect }
      stream.inspect
    end

    def generate_h2_response(res)
      code, header, body = res
      body = body.is_a?(Rack::BodyProxy) ? body.body.join : body.join

      header['content-length'] = body.bytesize.to_s
      header.delete 'connection'
      h2_header = header.to_a.map { |k, v| [k, v.is_a?(Array) ? v.join(',') : v] }
      h2_header.unshift([':status', code.to_s])

      [h2_header, body]
    end

    def set_proxy_host_port(io, host, port)
      return if io.methods.include?(:proxy_host)
      io.instance_eval do
        define_singleton_method(:proxy_host) { host }
        define_singleton_method(:proxy_port) { port }
      end
    end

    def ssl_connect(ssl_sock)
      ssl_sock.connect_nonblock
    rescue IO::WaitReadable
      if IO.select([ssl_sock], nil, nil, $config['proxy_timeout'])
        retry
      else
        raise "Timeout to connection remote SSL"
      end
    rescue IO::WaitWritable
      if IO.select(nil, [ssl_sock], nil, $config['proxy_timeout'])
        retry
      else
        raise "Timeout to connection remote SSL"
      end
    end

    private

    # Args:
    #   streams: [readers, writers], [[io1, io2], [io3, io4]]
    # Return:
    #   [readables, writeables]
    def io_select(streams, timeout, stop_wait_cb = nil)
      readers, writers = streams
      all_streams = streams.flatten.compact
      return if all_streams.empty?
      st = Time.now
      loop do
        return if stop_wait_cb && (stop_wait_cb.call(st) == true)
        rs, ws, es = IO.select(readers, writers, all_streams, 0.2)
        return [rs, ws, []] if (rs && !rs.empty?) || (ws && !ws.empty?)
        return [[], [], es] if es && !es.empty?
        return if (Time.now - st) >= timeout
      end
    end
  end
end
