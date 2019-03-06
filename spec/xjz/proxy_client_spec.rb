RSpec.describe Xjz::ProxyClient do
  it 'should return true if support h2' do
    req = Xjz::Request.new({
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
    })
    url = "http://xjz.pw/asdf?a=123"
    req_headers = Hash[req.headers]

    stub_request(:get, url).with(headers: req_headers) \
      .to_return(status: 200, body: "", headers: {})
    expect(Xjz::ProxyClient.h2_test(req)).to eql(false)

    stub_request(:get, url).with(headers: req_headers) \
      .to_return(status: 101, body: "", headers: {})
    expect(Xjz::ProxyClient.h2_test(req)).to eql(true)
  end

  it 'should create client for http1' do
    c = Xjz::ProxyClient.new protocol: 'http1'
    expect(c.client).to be_a(Xjz::ProxyClient::HTTP1)
    expect(c.client).to receive(:send_req).with('asdf')
    c.send_req('asdf')
  end

  it 'should create client for http2' do
    c = Xjz::ProxyClient.new protocol: 'http2'
    expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
    expect(c.client).to receive(:send_req).with('aaa')
    c.send_req('aaa')
  end
end
