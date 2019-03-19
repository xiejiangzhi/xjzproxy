RSpec.describe Xjz::HTTPParser do
  it 'should call callback and give env' do
    r = nil
    subject.on_finish { |env| r = env }
    subject << <<~REQ
      POST /asdf?token=123 HTTP/1.1\r
      Host: xjz.pw\r
      Content-Length: 5\r
      Content-Type: application/x-www-form-urlencode
      \r
      a=123
    REQ
    expect(r.delete('rack.input').read).to eql('a=123')
    expect(r.delete('rack.errors').read).to eql('')

    expect(r).to eql(
      "REQUEST_METHOD" => "POST",
      "SCRIPT_NAME" => "",
      "REQUEST_URI" => "/asdf?token=123",
      "PATH_INFO" => "/asdf",
      "QUERY_STRING" => "token=123",
      "SERVER_NAME" => 'xjz.pw',
      "SERVER_PORT" => '80',
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "HTTP_HOST" => "xjz.pw",
      "HTTP_CONTENT_LENGTH" => "5",
      "HTTP_CONTENT_TYPE" => "application/x-www-form-urlencode",
      "rack.url_scheme" => "http",
      "rack.multithread" => true,
      "rack.multiprocess" => false
    )
  end

  it 'should call callback and give env with a empty query' do
    r = nil
    subject.on_finish { |env| r = env }
    subject << <<~REQ
      GET /asdf HTTP/1.1\r
      Host: xjz.pw\r
      \r
    REQ
    expect(r.delete('rack.input').read).to eql('')
    expect(r.delete('rack.errors').read).to eql('')

    expect(r).to eql(
      "REQUEST_METHOD" => "GET",
      "SCRIPT_NAME" => "",
      "REQUEST_URI" => "/asdf",
      "PATH_INFO" => "/asdf",
      "QUERY_STRING" => "",
      "SERVER_NAME" => 'xjz.pw',
      "SERVER_PORT" => '80',
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "HTTP_HOST" => "xjz.pw",
      "rack.url_scheme" => "http",
      "rack.multithread" => true,
      "rack.multiprocess" => false
    )
  end

  it 'should call callback and give env for a proxy POST request' do
    r = nil
    subject.on_finish { |env| r = env }
    subject << <<~REQ
      POST http://xjz.pw/asdf?token=123 HTTP/1.1\r
      Host: xjz.pw\r
      Content-Length: 5\r
      Content-Type: application/x-www-form-urlencode
      \r
      a=123
    REQ
    expect(r.delete('rack.input').read).to eql('a=123')
    expect(r.delete('rack.errors').read).to eql('')

    expect(r).to eql(
      "REQUEST_METHOD" => "POST",
      "SCRIPT_NAME" => "",
      "PATH_INFO" => "/asdf",
      "REQUEST_URI" => 'http://xjz.pw/asdf?token=123',
      "QUERY_STRING" => "token=123",
      "SERVER_NAME" => 'xjz.pw',
      "SERVER_PORT" => '80',
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "HTTP_HOST" => "xjz.pw",
      "HTTP_CONTENT_LENGTH" => "5",
      "HTTP_CONTENT_TYPE" => "application/x-www-form-urlencode",
      "rack.url_scheme" => "http",
      "rack.multithread" => true,
      "rack.multiprocess" => false
    )
  end

  it 'should call callback and give env for a proxy HTTPS connect request' do
    r = nil
    subject.on_finish { |env| r = env }
    subject << <<~REQ
      CONNECT xjz.pw:443 HTTP/1.1\r
      Host: xjz.pw:443\r
      \r
    REQ
    expect(r.delete('rack.input').read).to eql('')
    expect(r.delete('rack.errors').read).to eql('')

    expect(r).to eql(
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "REQUEST_METHOD" => "CONNECT",
      "SCRIPT_NAME" => '',
      "REQUEST_URI" => 'xjz.pw:443',
      "PATH_INFO" => "",
      "QUERY_STRING" => '',
      "SERVER_NAME" => 'xjz.pw',
      "SERVER_PORT" => '443',
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "HTTP_HOST" => "xjz.pw:443",
      "rack.url_scheme" => "http",
      "rack.multithread" => true,
      "rack.multiprocess" => false
    )
  end
end
