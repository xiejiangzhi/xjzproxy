RSpec.describe Xjz::ProxyClient::HTTP1 do
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

  describe '#send_req' do
    it 'should retrun response' do
      res_headers = { 'content-type' => 'text/plain', 'content-length' => '5', 'asdf' => '123' }
      stub_request(:get, "http://baidu.com/asdf?a=123").with(
        body: "hello",
        headers: {
          'Accept' => '*/*', 'Host' => 'baidu.com',
          'User-Agent' => 'curl/7.54.0', 'Version' => 'HTTP/1.1'
        }
      ).to_return(
        status: 234,
        body: "world",
        headers: res_headers
      )

      res = subject.send_req(req)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(234)
      expect(res.h1_headers).to eql(res_headers.to_a)
      expect(res.body).to eql('world')
    end

    it 'should remove h2 headers when send request' do
      res_headers = { 'content-type' => 'text/plain', 'content-length' => '5', 'asdf' => '123' }
      stub_request(:get, "http://baidu.com/asdf?a=123").with(
        body: "hello",
        headers: {
          'Accept' => '*/*', 'Host' => 'baidu.com',
          'User-Agent' => 'curl/7.54.0', 'Version' => 'HTTP/1.1'
        }
      ).to_return(
        status: 234,
        body: "world",
        headers: res_headers
      )
      req.proxy_headers.unshift [':method', 'get']

      res = subject.send_req(req)
      expect(res).to be_a(Xjz::Response)
      expect(res.code).to eql(234)
      expect(res.h1_headers).to eql(res_headers.to_a)
      expect(res.body).to eql('world')
    end
  end
end
