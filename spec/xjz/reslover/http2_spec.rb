RSpec.describe Xjz::Reslover::HTTP2 do
  let(:h2_upgrade_req) do
    Xjz::Request.new(
      "rack.version" => [1, 3],
      "rack.errors" => StringIO.new,
      "rack.multithread" => true,
      "rack.multiprocess" => false,
      "rack.run_once" => false,
      "SCRIPT_NAME" => "",
      "QUERY_STRING" => "a=123",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "SERVER_SOFTWARE" => "puma 3.12.0 Llamas in Pajamas",
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "REQUEST_METHOD" => "GET",
      "REQUEST_URI" => "http://xjz.pw/asdf?a=1",
      "HTTP_VERSION" => "HTTP/1.1",
      "HTTP_HOST" => "xjz.pw",
      "HTTP_USER_AGENT" => "curl/7.54.0",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_PROXY_CONNECTION" => "Keep-Alive",
      "HTTP_CONNECTION" => "Upgrade, HTTP2-Settings",
      "HTTP_UPGRADE" => "h2c",
      "HTTP_HTTP2_SETTINGS" => "AAMAAABkAARAAAAAAAIAAAAA",
      "SERVER_NAME" => "xjz.pw",
      "SERVER_PORT" => "80",
      "REQUEST_PATH" => "/asdf",
      "PATH_INFO" => "/asdf",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => Proc.new { user_socket },
      "rack.hijack_io" => user_socket,
      "rack.input" => StringIO.new,
      "rack.url_scheme" => "http",
      "rack.after_reply" => []
    )
  end

  let(:req) do
    Xjz::Request.new_for_h2(
      {
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
        "REQUEST_METHOD" => "POST",
        "REQUEST_URI" => "http://xjz.pw/",
        "HTTP_VERSION" => "HTTP/1.1",
        "HTTP_HOST" => "xjz.pw",
        "HTTP_USER_AGENT" => "curl/7.54.0",
        "HTTP_ACCEPT" => "*/*",
        "HTTP_PROXY_CONNECTION" => "Keep-Alive",
        "SERVER_NAME" => "xjz.pw",
        "SERVER_PORT" => "443",
        "REQUEST_PATH" => "/asdf",
        "PATH_INFO" => "/asdf",
        "REMOTE_ADDR" => "127.0.0.1",
        "rack.hijack?" => true,
        "rack.hijack" => Proc.new { user_socket },
        "rack.hijack_io" => user_socket,
        "rack.input" => StringIO.new('hello'),
        "rack.url_scheme" => "http",
        "rack.after_reply" => []
      },
      [
        [':scheme', 'https'],
        [':method', 'post'],
        [':path', '/asdf?a=123'],
        ['host', 'xjz.pw']
      ],
      ['hello']
    )
  end

  let(:ss) { UNIXSocket.pair }
  let(:user_socket) { ss.first }
  let(:browser) { ss.last }

  after :each do
    ss.each { |s| s.close unless s.closed? }
  end

  it '#perform should return a response for https request' do
    subject = Xjz::Reslover::HTTP2.new(req)
    stub_request(:post, "https://xjz.pw/asdf?a=123").with(
      body: "hello",
      headers: req.h1_proxy_headers + [['Content-Length', '5']]
    ).to_return(status: 200, body: "world1234567", headers: new_http1_res_headers)
    allow(subject).to receive(:remote_support_h2?).and_return(false)
    t = Thread.new do
      user_socket.recv(24) # remove the request header
      subject.perform rescue Errno::EPIPE
    end
    res = new_http2_req(req, browser)
    browser.close
    expect(res.body).to eql("world1234567")
    expect(res.code).to eql(200)
    expect(res.h2_headers).to eql([
      [":status", "200"], ["content-type", "text/plain"], ["content-length", "12"]
    ])
    t.kill
  end

  it '#perform should return a response for http upgrade request' do
    subject = Xjz::Reslover::HTTP2.new(h2_upgrade_req)
    stub_request(:get, "http://xjz.pw/asdf?a=123").with(
      headers: {
        'Accept' => '*/*',
        'Content-Length' => '0',
        'Host' => 'xjz.pw',
        'Http2-Settings' => 'AAMAAABkAARAAAAAAAIAAAAA',
        'User-Agent' => 'curl/7.54.0',
        'Version' => 'HTTP/1.1'
      }
    ).to_return(status: 200, body: "hello", headers: { 'a' => '1' })
    allow(subject).to receive(:remote_support_h2?).and_return(false)
    t = Thread.new { subject.perform rescue Errno::EPIPE }
    expect(browser.recv(71)).to \
      eql("HTTP/1.1 101 Switching Protocols\r\nConnection: Upgrade\r\nUpgrade: h2c\r\n\r\n")
    res = new_http2_req(req, browser, upgrade: true)
    browser.close
    expect(res.body).to eql("hello")
    expect(res.code).to eql(200)
    expect(res.h2_headers).to eql([[":status", "200"], ['a', '1'], ["content-length", "5"]])
    t.kill
  end
end
