module Support
  module NetworkHelper
    def new_http2_server(writer, &res_block)
      HTTP2::Server.new.tap do |conn|
        conn.on(:frame) { |bytes| writer << bytes }
        conn.on(:stream) do |stream|
          header = []
          buffer = []

          stream.on(:headers) { |h| header.push(*h) }
          stream.on(:data) { |d| buffer << d }
          stream.on(:half_close) do
            res_block.call(stream, header, buffer)
          end
        end
      end
    end
  end
end
