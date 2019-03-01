module RequestHelper
  extend self

  BUFFER_SIZE = 4096

  # https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers
  # only for single transport-level connection, must not be retransmitted by proxies or cached
  HOP_BY_HOP = %w{
    connection keep-alive proxy-authenticate proxy-authorization
    te trailers transfer-encoding upgrade
  }
  SHOULD_NOT_TRANSFER = %w{set-cookie proxy-connection}

  def process_res_headers(headers)
    # headers['proxy-connection'] = "close"
    # headers['connection'] = "close"
    headers.delete 'transfer-encoding' # Rack::Chunked will process transfer-encoding
    headers
  end

  def fetch_req_headers(env)
    env['xjz.header'] ||= env.each_with_object({}) do |kv, r|
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

  def import_h2_header_to_env(env, header)
    header.each_with_object({}) do |line, h2r|
      k, v = line
      k = k.tr('-', '_').upcase

      if k =~ /^:/
        env["H2_#{k[1..-1]}"] = v
      else
        env["HTTP_#{k}"] = v
      end
    end
    env['HTTP_HOST'] ||= env['H2_AUTHORITY']
    env['REQUEST_METHOD'] = env['H2_METHOD'] if env['H2_METHOD']
    env['REQUEST_PATH'] = env['H2_PATH'] if env['H2_PATH']
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
end
