RSpec.describe Xjz::ProxyClient::HTTP2 do
  let(:req) do
    Xjz::Request.new(
      "rack.version" => [1, 3],
      "rack.errors" => 'error.io',
      "rack.multithread" => true,
      "rack.multiprocess" => false,
      "rack.run_once" => false,
      "SCRIPT_NAME" => "",
      "QUERY_STRING" => "a=123",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "SERVER_SOFTWARE" => "puma 3.12.0 Llamas in Pajamas",
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "REQUEST_METHOD" => "GET",
      "REQUEST_URI" => "http://www.slack.com/",
      "HTTP_VERSION" => "HTTP/1.1",
      "HTTP_HOST" => "baidu.com",
      "HTTP_USER_AGENT" => "curl/7.54.0",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_PROXY_CONNECTION" => "Keep-Alive",
      "SERVER_NAME" => "www.slack.com",
      "SERVER_PORT" => "443",
      "REQUEST_PATH" => "/asdf",
      "PATH_INFO" => "/asdf",
      "REMOTE_ADDR" => "127.0.0.1",
      "puma.socket" => StringIO.new("sock data"),
      "rack.hijack?" => true,
      "rack.hijack" => 'puma.client',
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
      "rack.after_reply" => []
    )
  end

  describe '#send_req' do
    let(:ss) { UNIXSocket.pair }

    after :each do
      ss.each { |s| s.close unless s.closed? }
    end

    it 'should return response' do
      server_client, local_remote = ss
      res_headers = [
        [':status', '200'], ['content-type', 'text/plain']
      ]
      stop_wait = false

      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        stop_wait = true
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end

      Thread.new do
        Xjz::IOHelper.forward_streams(
          { server_client => Xjz::WriterIO.new(h2s) },
          stop_wait_cb: proc { stop_wait }
        )
      end

      allow(subject).to receive(:remote_sock).and_return(local_remote)
      res = subject.send_req(req)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(200)
      expect(res.h2_headers).to eql(res_headers + [['content-length', '5']])
      expect(res.body).to eql('hello')
    end
  end
end
