RSpec.describe Xjz::Request do
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
      "REQUEST_URI" => "http://baidu.com/",
      "HTTP_VERSION" => "HTTP/1.1",
      "HTTP_HOST" => "baidu.com",
      "HTTP_USER_AGENT" => "curl/7.54.0",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_PROXY_CONNECTION" => "Keep-Alive",
      "SERVER_NAME" => "baidu.com",
      "SERVER_PORT" => "80",
      "REQUEST_PATH" => "/asdf",
      "PATH_INFO" => "/asdf",
      "REMOTE_ADDR" => "127.0.0.1",
      "puma.socket" => 'puma.user_socket',
      "rack.hijack?" => true,
      "rack.hijack" => 'puma.client',
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
      "rack.after_reply" => []
    )
  end

  it '#req_method should return http request method' do
    expect(req.http_method).to eql('get')
  end

  it '#url should return request url' do
    expect(req.url).to eql('http://baidu.com/asdf?a=123')
  end

  it '#user_socket should return request url' do
    expect(req.user_socket).to eql('puma.user_socket')
  end

  it '#headers should return all headers' do
    expect(req.headers).to eql([
      ["version", "HTTP/1.1"],
      ["host", "baidu.com"],
      ["user-agent", "curl/7.54.0"],
      ["accept", "*/*"],
      ["proxy-connection", "Keep-Alive"]
    ])
  end

  it '#proxy_headers should remove invalid headers' do
    expect(req.proxy_headers).to eql([
      ["version", "HTTP/1.1"],
      ["host", "baidu.com"],
      ["user-agent", "curl/7.54.0"],
      ["accept", "*/*"]
    ])
  end

  it '#body should return body' do
    expect(req.body).to eql('hello')
  end

  it '#host should return host' do
    expect(req.host).to eql('baidu.com')
  end

  it '#port should return port' do
    expect(req.port).to eql(80)
  end

  describe '.new_for_h2' do
    let(:h2_env) do
      {
        "rack.version" => [1, 3],
        "rack.errors" => StringIO.new,
        "rack.multithread" => true,
        "rack.multiprocess" => false,
        "rack.run_once" => false,
        "SCRIPT_NAME" => "",
        "QUERY_STRING" => "",
        "SERVER_PROTOCOL" => "HTTP/1.1",
        "SERVER_SOFTWARE" => "puma 3.12.0 Llamas in Pajamas",
        "GATEWAY_INTERFACE" => "CGI/1.2",
        "HTTPS" => "https",
        "REQUEST_METHOD" => "PRI",
        "REQUEST_URI" => "*",
        "HTTP_VERSION" => "HTTP/2.0",
        "SERVER_NAME" => "localhost",
        "SERVER_PORT" => "443",
        "REQUEST_PATH" => "*",
        "PATH_INFO" => "*",
        "REMOTE_ADDR" => "127.0.0.1",
        "puma.socket" => 'puma.sock',
        "rack.hijack?" => true,
        "rack.hijack" => 'hijack',
        "rack.input" => StringIO.new,
        "rack.url_scheme" => "https",
        "rack.after_reply" => []
      }
    end
    let(:h2_headers) do
      [
        [":method", "GET"],
        [":path", "/?a=123"],
        [":scheme", "https"],
        [":authority", "baidu.com"],
        ["user-agent", "curl/7.54.0"],
        ["accept", "*/*"],
        ['connection', 'close']
      ]
    end

    it '.new_for_h2 should create new req' do
      req = Xjz::Request.new_for_h2(h2_env, h2_headers, ['hello', ' world'])
      expect(req.http_method).to eql('get')
      expect(req.host).to eql('baidu.com')
      expect(req.port).to eql(443)
      expect(req.url).to eql('https://baidu.com/?a=123')
      expect(req.user_socket).to eql('puma.sock')
      expect(req.headers).to eql([
        [":method", "GET"], [":path", "/?a=123"], [":scheme", "https"],
        [":authority", "baidu.com"], ["user-agent", "curl/7.54.0"], ["accept", "*/*"],
        ['connection', 'close']
      ])
      expect(req.proxy_headers).to eql([
        [":method", "GET"], [":path", "/?a=123"], [":scheme", "https"],
        [":authority", "baidu.com"], ["user-agent", "curl/7.54.0"], ["accept", "*/*"]
      ])
      expect(req.body).to eql('hello world')
    end
  end
end
