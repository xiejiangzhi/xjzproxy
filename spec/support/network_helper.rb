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

    def new_http2_req(req, writer, upgrade: false)
      client = HTTP2::Client.new
      client.on(:frame) { |bytes| writer << bytes; writer.flush }

      stream = upgrade ? client.upgrade : client.new_stream
      res_header = []
      res_buffer = []
      res = nil
      stop_wait = false

      stream.on(:headers) { |h| res_header.push(*h) }
      stream.on(:data) { |d| res_buffer << d }

      stream.on(:close) do
        stop_wait = true
        res = Xjz::Response.new(res_header, res_buffer)
      end

      unless upgrade
        if req.body.empty?
          stream.headers(req.headers, end_stream: true)
        else
          stream.headers(req.headers, end_stream: false)
          stream.data(req.body, end_stream: true)
        end
      end

      Xjz::IOHelper.forward_streams(
        { writer => Xjz::WriterIO.new(client) },
        stop_wait_cb: proc { stop_wait }, timeout: 1
      )
      res
    end
  end
end
