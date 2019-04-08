RSpec.describe Xjz::Resolver::WebUI do
  let(:ss) { FakeIO.pair }
  let(:user_socket) { ss.first }
  let(:client) { ss.last }
  let(:req) do
    Xjz::Request.new(
      "rack.version" => [1, 3],
      "rack.errors" => 'error.io',
      "rack.multithread" => true,
      "rack.multiprocess" => false,
      "SCRIPT_NAME" => "",
      "QUERY_STRING" => "",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "GATEWAY_INTERFACE" => "CGI/1.2",
      "REQUEST_METHOD" => "POST",
      "REQUEST_URI" => "/",
      "HTTP_HOST" => "127.0.0.1",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_CONNECTION" => "Keep-Alive",
      "SERVER_NAME" => "127.0.0.1",
      "SERVER_PORT" => "80",
      "PATH_INFO" => "/",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => Proc.new { user_socket },
      "rack.hijack_io" => user_socket,
      "rack.input" => StringIO.new,
      "rack.url_scheme" => "http"
    )
  end
  let(:subject) { described_class.new(req) }
  let(:http_parser) do
    obj = OpenStruct.new(headers: nil, body: '')
    parser = HTTP::Parser.new
    parser.on_headers_complete = proc { obj.headers = parser.headers }
    parser.on_body = proc { |data| obj.body << data }
    parser.on_message_complete = proc { obj.status = parser.status_code }
    obj.define_singleton_method(:<<) { |data| parser << data }
    obj
  end

  before :each do
    odata = $config.data
    allow($config).to receive(:data).and_return(odata.merge('template_dir' => nil))
  end

  describe 'HTTP' do
    it 'GET / should return index page' do
      client.reply_data = proc { |msg, io| io.close }
      subject.perform
      http_parser << client.rdata.join
      expect(http_parser.status).to eql(200)
      expect(http_parser.headers).to eql(
        "connection" => "Keep-Alive",
        "content-length" => http_parser.body.bytesize.to_s
      )
      expect(http_parser.body).to be_match('XJZ Proxy')
    end

    it 'GET /root_ca.pem should return pem str' do
      client.reply_data = proc { |msg, io| io.close }
      req.env['PATH_INFO'] = '/root_ca.pem'
      subject.perform
      http_parser << client.rdata.join
      expect(http_parser.status).to eql(200)
      expect(http_parser.headers).to eql(
        "connection" => "Keep-Alive",
        "content-length" => http_parser.body.bytesize.to_s,
        "content-type" => "application/octet-stream; charset=utf-8",
        "content-disposition" => "attachment; filename=\"xjzproxy_root_ca.pem\""
      )
      expect(http_parser.body).to eql(Xjz::Resolver::SSL.cert_manager.root_ca.to_pem)
    end

    it 'GET /root_ca.crt should return pem str' do
      client.reply_data = proc { |msg, io| io.close }
      req.env['PATH_INFO'] = '/root_ca.crt'
      subject.perform
      http_parser << client.rdata.join
      expect(http_parser.status).to eql(200)
      expect(http_parser.headers).to eql(
        "connection" => "Keep-Alive",
        "content-length" => http_parser.body.bytesize.to_s,
        "content-type" => "application/octet-stream; charset=utf-8",
        "content-disposition" => "attachment; filename=\"xjzproxy_root_ca.crt\""
      )
      expect(http_parser.body).to eql(Xjz::Resolver::SSL.cert_manager.root_ca.to_pem)
    end

    it 'GET invalid path should return 404' do
      client.reply_data = proc { |msg, io| io.close }
      req.env['PATH_INFO'] = '/invalid path'
      subject.perform
      http_parser << client.rdata.join
      expect(http_parser.status).to eql(404)
      expect(http_parser.headers).to eql(
        "connection" => "Keep-Alive",
        "content-length" => http_parser.body.bytesize.to_s,
      )
      expect(http_parser.body).to eql("Not Found")
    end
  end

  describe 'WebSocket' do
  end
end
