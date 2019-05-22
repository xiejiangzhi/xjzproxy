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
      "rack.hijack" => proc { 'puma.client' },
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
      "rack.after_reply" => []
    )
  end

  after :each do
    subject.close
  end

  describe '#send_req' do
    def forward_test_conns(server_client, h2s, subject)
      Thread.new do
        Xjz::IOHelper.forward_streams(server_client => Xjz::WriterIO.new(h2s))
      end
    end

    it 'should return response' do
      server_client, local_remote = FakeIO.pair
      res_headers = [[':status', '200'], ['content-type', 'text/plain']]

      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end
      allow(subject).to receive(:remote_sock).and_return(local_remote)
      t = forward_test_conns(server_client, h2s, subject)

      stream = subject.client.new_stream
      allow(subject.client).to receive(:new_stream).and_return(stream)
      expect(stream).to receive(:headers).with(kind_of(Array), end_stream: false).and_call_original
      expect(stream).to receive(:data).with(kind_of(String)).and_call_original

      res = subject.send_req(req)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(200)
      expect(res.h2_headers).to eql(res_headers + [['content-length', '5']])
      expect(res.body).to eql('hello')
      t.kill
    end

    it 'should return response with empty body' do
      server_client, local_remote = FakeIO.pair
      res_headers = [[':status', '200'], ['content-type', 'text/plain']]

      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end
      allow(subject).to receive(:remote_sock).and_return(local_remote)
      t = forward_test_conns(server_client, h2s, subject)

      stream = subject.client.new_stream
      allow(subject.client).to receive(:new_stream).and_return(stream)
      expect(stream).to receive(:headers).with(kind_of(Array), end_stream: true).and_call_original
      expect(stream).to_not receive(:data)

      allow(req).to receive(:body).and_return('')
      res = subject.send_req(req)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(200)
      expect(res.h2_headers).to eql(res_headers + [['content-length', '0']])
      expect(res.body).to eql('')
      t.kill
    end


    it 'should request with callback' do
      server_client, local_remote = FakeIO.pair
      res_headers = [[':status', '200'], ['content-type', 'text/plain']]

      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end
      allow(subject).to receive(:remote_sock).and_return(local_remote)
      t = forward_test_conns(server_client, h2s, subject)

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
      t.kill
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
      t = forward_test_conns(server_client, h2s, subject)

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
      t.kill
    end

    it 'should return nil if remote_sock is nil ' do
      allow(subject).to receive(:remote_sock).and_return(nil)
      expect(subject.send_req(req)).to eql(nil)
    end

    it 'should work for concurrent' do
      server_client, local_remote = FakeIO.pair
      res_headers = [[':status', '200'], ['content-type', 'text/plain']]

      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end
      allow(subject).to receive(:remote_sock).and_return(local_remote)
      t = forward_test_conns(server_client, h2s, subject)

      rs = []
      ts = %w{c a b hello world}.map do |str|
        r = req.dup
        allow(r).to receive(:body).and_return(str)
        Thread.new { rs << subject.send_req(r) }
      end
      ts.each(&:join)
      expect(rs.map(&:body).sort).to eql(%w{a b c hello world})
      t.kill
    end
  end

  describe '#remote_sock' do
    it 'should return ssl sock if use ssl' do
      pclient = described_class.new(req.host, req.port, ssl: true)
      expect(pclient.remote_sock).to be_a(OpenSSL::SSL::SSLSocket)
    end

    it 'should return tcp sock if not use ssl' do
      pclient = described_class.new(req.host, req.port, ssl: false)
      expect(pclient.remote_sock).to be_a(Socket)
    end

    it 'should timeout if cannot connect to remote', log: false do
      s = TCPServer.new(0)
      addr = s.local_address
      pclient = described_class.new(addr.ip_address, addr.ip_port, ssl: true)
      expect(pclient.remote_sock).to eql(nil)
    end

    it 'should return nil for invalid host name', log: false do
      pclient = described_class.new('alksjdfkljaks12lk3jl1kj2kj31.asdf', 12352, ssl: true)
      expect(pclient.remote_sock).to eql(nil)
    end
  end

  describe '#ping' do
    it 'should return false if remote_sock is nil' do
      allow(subject).to receive(:remote_sock).and_return(nil)
      expect(subject.ping).to eql(false)
    end

    it 'should return false if remote_sock is closed' do
      server_client, local_remote = FakeIO.pair
      server_client.close
      allow(subject).to receive(:remote_sock).and_return(local_remote)
      expect(subject.ping).to eql(false)
    end

    it 'should return false when timeout' do
      _server_client, local_remote = FakeIO.pair
      allow(subject).to receive(:remote_sock).and_return(local_remote)
      expect(subject.ping).to eql(false)
    end

    it 'should return true for a valid request' do
      server_client, local_remote = FakeIO.pair
      h2s = new_http2_server(server_client) do |stream, headers, buffer|
        data = buffer.join
        stream.headers(res_headers + [['content-length', data.bytesize.to_s]])
        stream.data(data)
      end
      server_client.reply_data = proc { |data, io| Xjz::WriterIO.new(h2s) << data if data }

      allow(subject).to receive(:remote_sock).and_return(local_remote)
      expect(subject.ping).to eql(true)
    end
  end

  describe '#closed?' do
    it 'should return false for valid connection' do
      a, _ = FakeIO.pair
      allow(subject).to receive(:remote_sock).and_return(a)
      expect(subject.closed?).to eql(false)
    end

    it 'should return true for invalid connection' do
      a, _ = FakeIO.pair
      allow(subject).to receive(:remote_sock).and_return(nil)
      expect(subject.closed?).to eql(true)

      a.close
      allow(subject).to receive(:remote_sock).and_return(a)
      expect(subject.closed?).to eql(true)
    end
  end
end
