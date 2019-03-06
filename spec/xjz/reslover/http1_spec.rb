RSpec.describe Xjz::Reslover::HTTP1 do
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
      "puma.socket" => 'puma.user_socket',
      "rack.hijack?" => true,
      "rack.hijack" => 'puma.client',
      "rack.input" => StringIO.new('hello'),
      "rack.url_scheme" => "http",
      "rack.after_reply" => []
    )
  end

  let(:subject) { Xjz::Reslover::HTTP1.new(req) }

  before :each do
    stub_request(:post, "http://xjz.pw/asdf?a=123").with(
      body: "hello",
      headers: {
       'Accept' => '*/*', 'Content-Length' => '5',
       'Host' => 'xjz.pw', 'User-Agent' => 'curl/7.54.0', 'Version' => 'HTTP/1.1'
      }
    ).to_return(status: 200, body: "world1234567", headers: new_http1_res_headers)
  end

  it '#response should return a response of this request' do
    res = subject.response
    expect(res).to be_a(Xjz::Response)
    expect(res.code).to eql(200)
    expect(res.body).to eql('world1234567')
    expect(res.h1_headers).to eql(new_http1_res_headers)
  end

  it '#perform should return a rack response' do
    expect(subject.perform).to eql([200, new_http1_res_headers, ['world1234567']])
  end
end
