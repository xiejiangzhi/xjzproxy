RSpec.describe Xjz::ProxyClient do
  let(:req) do
    Xjz::Request.new(
      "SCRIPT_NAME" => "",
      "QUERY_STRING" => "a=123",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "REQUEST_METHOD" => "GET",
      "REQUEST_URI" => "http://xjz.pw/",
      "HTTP_HOST" => "xjz.pw",
      'HTTP_CONNECTION' => 'Upgrade; HTTP2-Settings',
      'HTTP_UPGRADE' => 'h2c',
      'HTTP_HTTP2_SETTINGS' => 'aabbcc',
      "SERVER_NAME" => "xjz.pw",
      "SERVER_PORT" => "80",
      "REQUEST_PATH" => "/asdf",
      "PATH_INFO" => "/asdf",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => 'puma.client',
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
    )
  end

  let(:res) { Xjz::Response.new({}, [], 200) }

  before :each do
    @ap_config = $config['.api_projects']
    $config['.api_projects'] = []
  end

  after :each do
    $config['.api_projects'] = @ap_config
  end

  describe '.h2_test' do
    it 'should return h1upgrade if support upgrade by h1' do
      url = "http://xjz.pw/asdf?a=123"
      req_headers = Hash[req.headers]

      stub_request(:get, url).with(headers: req_headers) \
        .to_return(status: 200, body: "", headers: {})
      expect(Xjz::ProxyClient.h2_test(req)).to eql(false)

      stub_request(:get, url).with(headers: req_headers) \
        .to_return(status: 101, body: "", headers: {})
      expect(Xjz::ProxyClient.h2_test(req)).to eql('h1upgrade')
    end

    it 'should return h2 if support direct h2' do
      server_client, local_remote = UNIXSocket.pair
      h2s = new_http2_server(server_client) { nil }

      Thread.new do
        Xjz::IOHelper.forward_streams(
          { server_client => Xjz::WriterIO.new(h2s) }, stop_wait_cb: proc { false }
        )
      end

      allow_any_instance_of(Xjz::ProxyClient::HTTP2).to receive(:remote_sock).and_return(local_remote)
      expect(Xjz::ProxyClient.h2_test(req)).to eql('h2')
    end
  end

  it 'should create client for http1' do
    c = Xjz::ProxyClient.new protocol: 'http1'
    expect(c.client).to be_a(Xjz::ProxyClient::HTTP1)
    expect(c.client).to receive(:send_req).with(req).and_return(res)
    c.send_req(req)
  end

  it 'should create client for http2' do
    c = Xjz::ProxyClient.new protocol: 'http2'
    expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
    expect(c.client).to receive(:send_req).with(req).and_return(res)
    c.send_req(req)
  end

  it 'should use ApiProject response if hack_req return a response' do
    c = Xjz::ProxyClient.new protocol: 'http1'
    ap = Xjz::ApiProject.new('repopath')
    $config['.api_projects'] = [ap]
    allow(ap).to receive(:hack_req).and_return(nil)

    allow(c.client).to receive(:send_req).with(req).and_return(res)
    expect(c.send_req(req)).to eql(res)

    res2 = Xjz::Response.new({}, ['asdf'], 201)
    allow(ap).to receive(:hack_req).and_return(res2)
    expect(c.send_req(req)).to eql(res2)
  end

  describe '.auto_new_client' do
    let(:req) do
      Xjz::Request.new(
        "SCRIPT_NAME" => "",
        "SERVER_PROTOCOL" => "HTTP/1.1",
        "GATEWAY_INTERFACE" => "CGI/1.2",
        "REQUEST_METHOD" => "GET",
        "REQUEST_URI" => "http://xjz.pw/",
        "HTTP_HOST" => lsock.remote_address.ip_address,
        'HTTP_CONNECTION' => 'Upgrade; HTTP2-Settings',
        "SERVER_NAME" => "xjz.pw",
        "SERVER_PORT" => lsock.remote_address.ip_port,
        "REQUEST_PATH" => "/asdf",
        "PATH_INFO" => "/asdf",
        "REMOTE_ADDR" => "127.0.0.1",
        "rack.hijack?" => true,
        "rack.hijack" => 'puma.client',
        "rack.input" => StringIO.new('hello'),
        "rack.url_scheme" => "https",
      )
    end
    let(:rsock) { @rsock }
    let(:lsock) { @lsock }

    before :each do
      @server, @rsock, @lsock = FakeIO.server_pair(:s, :a, :b)
    end

    it 'should return protocol and client if server support h2 alpn' do
      allow($config).to receive(:[]) do |key|
        key == 'alpn_protocols' ? ['h2', 'http/1.1'] : $config.data[key]
      end
      t = Thread.new do
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        sock = ssl_server.accept
        sleep 0.1
        sock.close
      end
      p, c = Xjz::ProxyClient.auto_new_client(req)
      expect(p).to eql(:h2)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(true)
      expect(c.client.upgrade).to eql(false)
      t.join
    end

    it 'should return protocol and client if server support h2 without alpn' do
      allow($config).to receive(:[]) do |key|
        key == 'alpn_protocols' ? ['http/1.1'] : $config.data[key]
      end
      t = Thread.new do
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        ssl_server.accept.close
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        sock = ssl_server.accept
        h2s = new_http2_server(sock)
        h2io = Xjz::WriterIO.new(h2s)
        FakeIO.new('test1', sock).copy_to(h2io)
        sock.close
      end
      p, c = Xjz::ProxyClient.auto_new_client(req)
      expect(p).to eql(:h2)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(true)
      expect(c.client.upgrade).to eql(false)
      t.join
    end

    it 'should return protocol and client if server support h2c' do
      allow($config).to receive(:[]) do |key|
        key == 'alpn_protocols' ? ['http/1.1'] : $config.data[key]
      end
      t = Thread.new {
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        ssl_server.accept.close
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        ssl_server.accept.close
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        sock = ssl_server.accept
        d = sock.readpartial(1024)
        expect(d).to eql(<<~REQ
          GET / HTTP/1.1\r
          Connection: Upgrade, HTTP2-Settings\r
          HTTP2-Settings: AAEAABAAAAIAAAABAAMAAABkAAQAAP__AAUAAEAAAAZ_____\r
          Upgrade: h2c\r
          Host: 127.0.0.1\r
          User-Agent: http-2 upgrade\r
          Accept: */*\r
          \r
        REQ
        )
        sock << <<~RES
          HTTP/1.1 101 Protocol Switch\r
          Upgrade: h2c\r
          Connection: upgrade\r
          \r
        RES
        h2s = new_http2_server(sock)
        h2io = Xjz::WriterIO.new(h2s)
        FakeIO.new('test1', sock).copy_to(h2io)
        sock.close
      }
      p, c = Xjz::ProxyClient.auto_new_client(req)
      expect(p).to eql(:h2c)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(true)
      expect(c.client.upgrade).to eql(true)
      t.join
    end

    it 'should return protocol and client if server do not support h2' do
      allow($config).to receive(:[]) do |key|
        key == 'alpn_protocols' ? ['http/1.1'] : $config.data[key]
      end
      t = Thread.new do
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        ssl_server.accept.close
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        ssl_server.accept.close
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Reslover::SSL.ssl_ctx)
        ssl_server.accept.close
      end
      p, c = Xjz::ProxyClient.auto_new_client(req)
      expect(p).to eql(:h1)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP1)
      expect(c.client.use_ssl).to eql(true)
      expect(c.client.upgrade).to eql(false)
      t.join
    end
  end
end
