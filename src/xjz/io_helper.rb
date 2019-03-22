module Xjz
  module IOHelper
    extend self

    BUFFER_SIZE = 4096

    # Copy stream from src to dst
    # Return
    #   true: wait or EINTR
    #   false: eof
    def nonblock_copy_stream(src, dst, auto_eof: true)
      loop do
        data = begin
          src.read_nonblock(BUFFER_SIZE) # raise and return true if no data able to read
        rescue EOFError
          # eof, no data
        end
        if data && data != ''
          Logger[:auot].debug { "#{data.bytesize} bytes > #{stream_inspect(dst)}" }
          dst.write(data)
        else
          dst.close_write if auto_eof && dst.respond_to?(:close_write)
          break false
        end
      end
    rescue IO::EAGAINWaitReadable, Errno::EINTR, OpenSSL::SSL::SSLErrorWaitReadable
      true
    rescue Errno::ECONNRESET
      false
    ensure
      dst.flush unless auto_eof
    end

    # streams_mapping:
    #   read_stream => write_stream
    # timeout: seconds
    # stop_wait_cb: proc, stop check stream if return true
    def forward_streams(streams_mapping, timeout: $config['proxy_timeout'], stop_wait_cb: nil)
      streams = streams_mapping.keys
      rs = streams

      loop do
        rs.each do |src|
          dst = streams_mapping[src]

          unless nonblock_copy_stream(src, dst)
            streams.delete(src)
          end
        end

        break if streams.empty?
        rs = wait_readable(streams, timeout, stop_wait_cb)
        return false unless rs # timeout or stop wait
      end

      true
    end

    def stream_inspect(stream)
      case stream
      when OpenSSL::SSL::SSLSocket
        ad = stream.to_io.remote_address
        [ad.ip_address, ad.ip_port].join(':')
      when stream.respond_to?(:remote_address)
        ad = stream.remote_address
        [ad.ip_address, ad.ip_port].join(':')
      when WriterIO
        stream.writer.class
      else
        stream.inspect
      end
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

    private

    def wait_readable(streams, timeout, stop_wait_cb = nil)
      return if streams.empty?
      st = Time.now
      loop do
        return if stop_wait_cb && (stop_wait_cb.call(st) == true)
        rs, _ = IO.select(streams, [], [], 0.1)
        return rs if rs
        return if (Time.now - st) >= timeout
      end
    end
  end
end
