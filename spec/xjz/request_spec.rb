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
      "HTTP_HOST" => "baidu.com",
      "HTTP_USER_AGENT" => "curl/7.54.0",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_PROXY_CONNECTION" => "Keep-Alive",
      "HTTP_CONTENT_TYPE" => "text/plain; charset=utf-8",
      "HTTP_CONNECTION" => "keep-alive",
      "SERVER_NAME" => "baidu.com",
      "SERVER_PORT" => "80",
      "REQUEST_PATH" => "/asdf",
      "PATH_INFO" => "/asdf",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => proc { 'user_socket' },
      "rack.hijack_io" => 'user_socket',
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
    expect(req.user_socket).to eql('user_socket')
  end

  it '#headers should return all headers' do
    expect(req.headers).to eql([
      ["host", "baidu.com"],
      ["user-agent", "curl/7.54.0"],
      ["accept", "*/*"],
      ["proxy-connection", "Keep-Alive"],
      ["content-type", 'text/plain; charset=utf-8'],
      ["connection", 'keep-alive']
    ])
  end

  describe '#proxy_headers' do
    it 'should remove invalid headers' do
      expect(req.proxy_headers).to eql([
        ["host", "baidu.com"],
        ["user-agent", "curl/7.54.0"],
        ["accept", "*/*"],
        ["content-type", 'text/plain; charset=utf-8'],
        ["content-length", '5']
      ])
    end

    it 'should keep connection attrs if forward_conn_attrs is true' do
      req.forward_conn_attrs = true
      expect(req.proxy_headers).to eql([
        ["host", "baidu.com"],
        ["user-agent", "curl/7.54.0"],
        ["accept", "*/*"],
        ["content-type", 'text/plain; charset=utf-8'],
        ["connection", "keep-alive"],
        ["content-length", '5']
      ])
    end
  end

  it '#h1_proxy_headers should remove h2 headers' do
    req.proxy_headers.unshift [':a', '123']
    expect(req.proxy_headers).to eql([
      [':a', '123'],
      ["host", "baidu.com"],
      ["user-agent", "curl/7.54.0"],
      ["accept", "*/*"],
      ["content-type", 'text/plain; charset=utf-8'],
      ["content-length", '5']
    ])
    expect(req.h1_proxy_headers).to eql([
      ["host", "baidu.com"],
      ["user-agent", "curl/7.54.0"],
      ["accept", "*/*"],
      ["content-type", 'text/plain; charset=utf-8'],
      ["content-length", '5']
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

  it '#protocol should return protocol' do
    expect(req.protocol).to eql('http/1.1')
  end

  it '#content_type should return content_type' do
    expect(req.content_type).to eql('text/plain')
  end

  it '#upgrade_flag should return the flag content' do
    req.headers << ['upgrade', 'h2c']
    expect(req.upgrade_flag).to eql('h2c')
  end

  it '#scheme should return the http scheme' do
    expect(req.scheme).to eql('http')
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
        "SERVER_NAME" => "localhost",
        "SERVER_PORT" => "443",
        "REQUEST_PATH" => "*",
        "PATH_INFO" => "*",
        "REMOTE_ADDR" => "127.0.0.1",
        "puma.socket" => 'puma.sock',
        "rack.hijack?" => true,
        "rack.hijack" => proc { 'hijack socket' },
        "rack.hijack_io" => 'hijack socket',
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
      expect(req.user_socket).to eql('hijack socket')
      expect(req.headers).to eql([
        [":method", "GET"], [":path", "/?a=123"], [":scheme", "https"],
        [":authority", "baidu.com"], ["user-agent", "curl/7.54.0"], ["accept", "*/*"],
        ['connection', 'close']
      ])
      expect(req.proxy_headers).to eql([
        [":method", "GET"], [":path", "/?a=123"], [":scheme", "https"],
        [":authority", "baidu.com"], ["user-agent", "curl/7.54.0"], ["accept", "*/*"],
        ['content-length', '11']
      ])
      expect(req.body).to eql('hello world')
      expect(req.protocol).to eql('http/2.0')
    end
  end

  describe 'to_s' do
    it 'should return string of request' do
      expect(req.to_s).to eql(<<~REQ.strip
        GET /asdf?a=123 HTTP/1.1\r
        host: baidu.com\r
        user-agent: curl/7.54.0\r
        accept: */*\r
        content-type: text/plain; charset=utf-8\r
        content-length: 5\r
        \r
        hello
      REQ
      )
    end
  end

  it '#query_hash should parse query string' do
    expect(req.query_hash).to eql('a' => '123')
  end

  it '#body_hash should parse json' do
    allow(req).to receive(:content_type).and_return('application/json')
    allow(req).to receive(:body).and_return({ a: 1 }.to_json)
    expect(req.body_hash).to eql('a' => 1)
  end

  it '#body_hash should parse www-form-urlencoded' do
    allow(req).to receive(:content_type).and_return('application/x-www-form-urlencoded')
    allow(req).to receive(:body).and_return('a=1&b=123')
    expect(req.body_hash).to eql('a' => '1', 'b' => '123')
  end

  it '#body_hash should parse xml' do
    allow(req).to receive(:content_type).and_return('application/xml')
    allow(req).to receive(:body).and_return(<<-XML)
      <?xml version="1.0" encoding="UTF-8"?>
      <xxx>
        <foo type="integer">1</foo>
        <bar type="integer">2</bar>
      </xxx>
    XML
    expect(req.body_hash).to eql('xxx' => { 'foo' => 1, 'bar' => 2 })
  end

  it '#body_hash should parse undefined type' do
    allow(req).to receive(:content_type).and_return('asdf')
    allow(req).to receive(:body).and_return('a=1&b=123')
    expect(req.body_hash).to eql('a' => '1', 'b' => '123')

    req.instance_eval { @body_hash = nil }
    allow(req).to receive(:body).and_return({ a: 1 }.to_json)
    expect(req.body_hash).to eql('a' => 1)

    req.instance_eval { @body_hash = nil }
    allow(req).to receive(:body).and_return({ a: 2 }.to_xml)
    expect(req.body_hash).to eql('hash' => { 'a' => 2 })
  end

  it '#params should merge body & query' do
    allow(req).to receive(:content_type).and_return('asdf')
    allow(req).to receive(:body).and_return('b=321')
    expect(req.params).to eql('a' => '123', 'b' => '321')
  end
end
