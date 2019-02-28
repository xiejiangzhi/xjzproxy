module RequestHelper
  extend self

  BUFFER_SIZE = 4096

  def process_res_headers(headers)
    # headers['proxy-connection'] = "close"
    # headers['connection'] = "close"
    headers.delete 'transfer-encoding' # Rack::Chunked will process transfer-encoding
    headers
  end

  def fetch_req_headers(env)
    env.each_with_object({}) do |kv, r|
      k, v = kv
      next unless k =~ /\AHTTP_\w+/
      k = k[5..-1].downcase.tr('_', '-')
      next if HOP_BY_HOP.include?(k) || SHOULD_NOT_TRANSFER.include?(k)
      r[k] = v
    end
  end

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
      AppLogger[:misc].debug "Copy #{data.to_s.length} bytes to #{stream_inspect(dst)}"
      if data && data != ''
        dst.write(data)
      else
        AppLogger[:misc].debug "EOF #{stream_inspect(src)}"
        dst.close_write if auto_eof
        break false
      end
    end
  rescue IO::EAGAINWaitReadable, Errno::EINTR
    true
  ensure
    dst.flush
  end

  def forward_streams(streams_mapping)
    streams = streams_mapping.keys

    loop do
      break if streams.empty?
      rs, _ = IO.select(streams, [], [], 60)
      break unless rs # timeout

      rs.each do |src|
        dst = streams_mapping[src]

        unless nonblock_copy_stream(src, dst)
          streams.delete(src)
          AppLogger[:misc].debug "Finished forward #{stream_inspect(src)} => #{stream_inspect(dst)}"
        end
      end
    end
  end

  def stream_inspect(stream)
    case stream
    when OpenSSL::SSL::SSLSocket
      stream.to_io.remote_address.inspect
    when stream.respond_to?(:remote_address)
      stream.remote_address.inspect
    else
      stream.inspect
    end
  end
end
