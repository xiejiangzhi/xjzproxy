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
      "rack.hijack" => proc { 'puma.client' },
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
    )
  end

  let(:res) { Xjz::Response.new({}, [], 200) }
  let(:config_data) { @config_data }

  before :each do
    key = '.api_projects'
    @config_data = $config.data.deep_dup.reject { |k, v| k == key }
    @config_data[key] = []
    allow($config).to receive(:data).and_return(@config_data)
    allow($config.shared_data.app.webui).to receive(:emit_message)
  end

  describe '#send_req' do
    it 'should create client for http1' do
      c = Xjz::ProxyClient.new '127.0.0.1', 0, protocol: 'http1'
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP1)
      expect(c.client).to receive(:send_req).with(req).and_return(res)
      c.send_req(req)
    end

    it 'should create client for http2' do
      c = Xjz::ProxyClient.new '127.0.0.1', 123, protocol: 'http2'
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client).to receive(:send_req).with(req).and_return(res)
      c.send_req(req)
    end

    it 'should use ApiProject response if hack_req return a response' do
      ap = Xjz::ApiProject.new('repopath')
      c = Xjz::ProxyClient.new '1.1.1.1', 0, protocol: 'http1', api_project: ap
      config_data['.api_projects'] = [ap]
      allow(ap).to receive(:hack_req).and_return(nil)

      allow(c.client).to receive(:send_req).with(req).and_return(res)
      expect(c.send_req(req)).to eql(res)

      res2 = Xjz::Response.new({}, ['asdf'], 201)
      allow(ap).to receive(:hack_req).and_return(res2)
      expect(c.send_req(req)).to eql(res2)
    end

    it 'should catch net timeout error and return 504' do
      c = Xjz::ProxyClient.new '127.0.0.1', 123, protocol: 'http1'
      allow(c.client).to receive(:send_req).with(req).and_raise(Net::OpenTimeout.new('err'))
      expect(c.send_req(req).code).to eql(504)

      allow(c.client).to receive(:send_req).with(req).and_raise(Net::ReadTimeout.new('err'))
      expect(c.send_req(req).code).to eql(504)
    end
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
        "SERVER_NAME" => lsock.remote_address.ip_address,
        "SERVER_PORT" => lsock.remote_address.ip_port,
        "REQUEST_PATH" => "/asdf",
        "PATH_INFO" => "/asdf",
        "REMOTE_ADDR" => "127.0.0.1",
        "rack.hijack?" => true,
        "rack.hijack" => proc { 'puma.client' },
        "rack.input" => StringIO.new('hello'),
        "rack.url_scheme" => "https",
      )
    end
    let(:rsock) { @rsock }
    let(:lsock) { @lsock }

    before :each do
      @server, @rsock, @lsock = FakeIO.server_pair
      Xjz::Resolver::SSL.reset_certs
    end

    it 'should return protocol and client if server support h2 alpn' do
      config_data['alpn_protocols'] = ['h2', 'http/1.1']
      t = Thread.new do
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Resolver::SSL.ssl_ctx)
        ssl_sock = ssl_server.accept
        sleep 0.1
        ssl_sock.close
      end
      p, c = Xjz::ProxyClient.auto_new_client(req)
      expect(p).to eql(:h2)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(true)
      expect(c.client.upgrade).to eql(false)
      t.join
    end

    it 'should return protocol and client if server support h2 without alpn' do
      config_data['alpn_protocols'] = ['http/1.1']
      t = Thread.new do
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Resolver::SSL.ssl_ctx)
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

    it 'should return protocol and client if request include upgrade for h2c' do
      config_data['alpn_protocols'] = ['http/1.1']
      allow(req).to receive(:upgrade_flag).and_return('h2c')
      t = Thread.new {
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Resolver::SSL.ssl_ctx)
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

    it 'should return protocol and client if server do not support h2', log: false do
      config_data['alpn_protocols'] = ['http/1.1']
      t = Thread.new do
        ssl_server = OpenSSL::SSL::SSLServer.new(@server, Xjz::Resolver::SSL.ssl_ctx)
        ssl_server.accept.close
      end
      p, c = Xjz::ProxyClient.auto_new_client(req)
      expect(p).to eql(:h1)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP1)
      expect(c.client.use_ssl).to eql(true)
      expect(c.client.upgrade).to eql(false)
      t.join
    end

    it 'should return protocol and client if api_project protocol is http2' do
      ap = Xjz::ApiProject.new('a_dir')
      allow(ap).to receive(:data).and_return('project' => { 'protocol' => 'http1' })
      allow(ap).to receive(:grpc).and_return(nil)
      p, c = Xjz::ProxyClient.auto_new_client(req, ap)
      expect(p).to eql(:h1)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP1)
      expect(c.client.use_ssl).to eql(false)
      expect(c.client.upgrade).to eql(false)
    end

    it 'should return protocol and client if api_project protocol is http2' do
      ap = Xjz::ApiProject.new('a_dir')
      allow(ap).to receive(:data).and_return('project' => { 'protocol' => 'http2' })
      allow(ap).to receive(:grpc).and_return(nil)
      p, c = Xjz::ProxyClient.auto_new_client(req, ap)
      expect(p).to eql(:h2c)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(false)
      expect(c.client.upgrade).to eql(false)
    end

    it 'should return protocol and client if api_project protocol is http2 with ssl' do
      ap = Xjz::ApiProject.new('a_dir')
      allow(ap).to receive(:data).and_return('project' => { 'protocol' => 'http2', 'ssl' => true })
      allow(ap).to receive(:grpc).and_return(nil)
      p, c = Xjz::ProxyClient.auto_new_client(req, ap)
      expect(p).to eql(:h2)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(true)
      expect(c.client.upgrade).to eql(false)
    end

    it 'should return protocol and client if api_project is a grpc project' do
      ap = Xjz::ApiProject.new('a_dir')
      allow(ap).to receive(:data).and_return('project' => {})
      allow(ap).to receive(:grpc).and_return('grpc')
      p, c = Xjz::ProxyClient.auto_new_client(req, ap)
      expect(p).to eql(:h2c)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(false)
      expect(c.client.upgrade).to eql(false)
    end

    it 'should return protocol and client if api_project is http2 and req upgrade', log: false do
      ap = Xjz::ApiProject.new('a_dir')
      allow(ap).to receive(:data).and_return('project' => {})
      allow(ap).to receive(:grpc).and_return('grpc')
      allow(req).to receive(:upgrade_flag).and_return('h2c')
      p, c = Xjz::ProxyClient.auto_new_client(req, ap)
      expect(p).to eql(:h2c)
      expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
      expect(c.client.use_ssl).to eql(false)
      expect(c.client.upgrade).to eql(true)
    end
  end
end
