RSpec.describe Xjz::ProxyClient::HTTP2 do
  let(:subject) { described_class.new(req.host, req.port) }
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
    it 'should return response' do
      server_client, local_remote = FakeIO.pair
      res_headers = [[':status', '200'], ['content-type', 'text/plain']]

      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end

      server_client.reply_data = proc { |data, io| Xjz::WriterIO.new(h2s) << data if data }

      allow(subject).to receive(:remote_sock).and_return(local_remote)
      res = subject.send_req(req)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(200)
      expect(res.h2_headers).to eql(res_headers + [['content-length', '5']])
      expect(res.body).to eql('hello')
    end

    it 'should request with callback' do
      server_client, local_remote = FakeIO.pair
      res_headers = [[':status', '200'], ['content-type', 'text/plain']]

      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end

      server_client.reply_data = proc { |data, io| Xjz::WriterIO.new(h2s) << data if data }

      allow(subject).to receive(:remote_sock).and_return(local_remote)
      data = []
      res = subject.send_req(req) { |*args| data << args }
      expect(data.inspect).to eql([
        [
          :headers,
          [[":status", "200"], ["content-type", "text/plain"], ["content-length", "5"]], [:end_headers]
        ],
        [:data, "hello", [:end_stream]],
        [:close]
      ].inspect)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(200)
      expect(res.h2_headers).to eql(res_headers + [['content-length', '5']])
      expect(res.body).to eql('hello')
    end

    it 'should send upgrade request if upgrade is ture' do
      server_client, local_remote = FakeIO.pair
      server_client.reply_data << [<<~RES, 1024]
        HTTP/1.1 101 Protocol switch\r
        Upgrade: h2c\r
        \r
      RES

      allow_any_instance_of(described_class).to receive(:remote_sock).and_return(local_remote)
      subject = described_class.new(req.host, req.port, upgrade: true)
      expect(server_client.rdata.join).to eql(<<~REQ
        GET / HTTP/1.1\r
        Connection: Upgrade, HTTP2-Settings\r
        HTTP2-Settings: AAEAABAAAAIAAAABAAMAAABkAAQAAP__AAUAAEAAAAZ_____\r
        Upgrade: h2c\r
        Host: baidu.com\r
        User-Agent: http-2 upgrade\r
        Accept: */*\r
        \r
      REQ
      )

      res_headers = [[':status', '200'], ['content-type', 'text/plain']]
      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end
      server_client.reply_data = proc { |msg, io| Xjz::WriterIO.new(h2s) << msg if msg }

      data = []
      res = subject.send_req(req) { |*args| data << args }
      expect(data.inspect).to eql([
        [
          :headers,
          [[":status", "200"], ["content-type", "text/plain"], ["content-length", "5"]], [:end_headers]
        ],
        [:data, "hello", [:end_stream]],
        [:close]
      ].inspect)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(200)
      expect(res.h2_headers).to eql(res_headers + [['content-length', '5']])
      expect(res.body).to eql('hello')
    end
  end

  describe 'remote_socket' do
    it 'should return ssl sock if use ssl' do
      pclient = described_class.new(req.host, req.port, ssl: true)
      expect(pclient.remote_sock).to be_a(OpenSSL::SSL::SSLSocket)
    end

    it 'should return tcp sock if not use ssl' do
      pclient = described_class.new(req.host, req.port, ssl: false)
      expect(pclient.remote_sock).to be_a(Socket)
    end

    it 'should timeout if cannot connect to remote' do
      s = TCPServer.new(0)
      addr = s.local_address
      pclient = described_class.new(addr.ip_address, addr.ip_port, ssl: true)
      expect {
        pclient.remote_sock
      }.to raise_error("Timeout to connection remote SSL")
    end
  end
end
