RSpec.describe Xjz::Reslover::HTTP1 do
  let(:rw_io) { FakeIO.pair(:a, :b) }
  let(:user_socket) { rw_io.first }
  let(:client_socket) { rw_io.last }
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
      "REQUEST_METHOD" => "POST",
      "REQUEST_URI" => "http://xjz.pw/",
      "HTTP_VERSION" => "HTTP/1.1",
      "HTTP_HOST" => "xjz.pw",
      "HTTP_USER_AGENT" => "curl/7.54.0",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_PROXY_CONNECTION" => "Keep-Alive",
      "SERVER_NAME" => "xjz.pw",
      "SERVER_PORT" => "80",
      "REQUEST_PATH" => "/asdf",
      "PATH_INFO" => "/asdf",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => Proc.new { user_socket },
      "rack.hijack_io" => user_socket,
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
      "rack.after_reply" => []
    )
  end

  let(:subject) { Xjz::Reslover::HTTP1.new(req) }

  it '#perform should write response' do
    stub_request(:post, "http://xjz.pw/asdf?a=123").with(
      body: "hello",
      headers: {
       'Accept' => '*/*', 'Content-Length' => '5',
       'Host' => 'xjz.pw', 'User-Agent' => 'curl/7.54.0', 'Version' => 'HTTP/1.1'
      }
    ).to_return(status: 200, body: "world1234567", headers: new_http1_res_headers)
    expect(Xjz::HTTPHelper).to receive(:write_res_to_conn) do |r, s|
      expect(r.code).to eql(200)
      expect(r.body).to eql('world1234567')
      expect(r.h1_headers).to eql(new_http1_res_headers)
      expect(s).to eql(req.user_socket)
    end
    subject.perform
  end

  it '#perform should support multiple req/res in one connection' do
    res = [
      [200, 'world1234567', new_http1_res_headers(keep_alive: true)],
      [400, 'err', [['content-length', '3']] ]
    ]
    stub_request(:post, "http://xjz.pw/asdf?a=123").with(
      body: "hello",
      headers: {
       'Accept' => '*/*', 'Content-Length' => '5',
       'Host' => 'xjz.pw', 'User-Agent' => 'curl/7.54.0', 'Version' => 'HTTP/1.1'
      }
    ).to_return(status: res[0][0], body: res[0][1], headers: res[0][2])

    stub_request(:get, "http://xjz.pw/index?t=11").with(
      headers: { 'Host' => 'xjz.pw', 'X-A' => '123' }
    ).to_return(status: res[1][0], body: res[1][1], headers: res[1][2])

    expect(Xjz::HTTPHelper).to receive(:write_res_to_conn).twice do |r, s|
      code, body, headers = res.shift
      expect(r.code).to eql(code)
      expect(r.body).to eql(body)
      expect(r.h1_headers).to eql(headers)
      expect(s).to eql(req.user_socket)
    end

    client_socket << <<~REQ
      GET /index?t=11 HTTP/1.1\r
      Host: xjz.pw\r
      X-A: 123\r
      \r
    REQ
    subject.perform
    expect(res).to be_empty
  end
end
