RSpec.describe Xjz::Resolver::WebUI do
  let(:user_socket) { FakeIO.pair(:a).first  }
  let(:client) { FakeIO.pair(:a).last }
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
    it 'GET / should return index page', server: true do
      client.reply_data = proc { |msg, io| http_parser << msg }
      client.close_write
      Thread.new { sleep 1; client.close unless client.closed? }
      subject.perform
      http_parser << client.readpartial(65535) if IO.select([client], nil, nil, 0.1)
      expect(http_parser.status).to eql(200)
      expect(http_parser.headers).to eql(
        "connection" => "Keep-Alive",
        "content-length" => http_parser.body.bytesize.to_s
      )
      expect(http_parser.body).to be_match('XJZ Proxy')
    end

    it 'GET /root_ca.pem should return pem str' do
      client.reply_data = proc { |msg, io| http_parser << msg }
      client.close_write
      req.env['PATH_INFO'] = '/root_ca.pem'
      Thread.new { sleep 1; client.close unless client.closed? }
      subject.perform
      http_parser << client.readpartial(65535) if IO.select([client], nil, nil, 0.1)
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
      client.reply_data = proc { |msg, io| http_parser << msg }
      client.close_write
      req.env['PATH_INFO'] = '/root_ca.crt'
      Thread.new { sleep 1; client.close unless client.closed? }
      subject.perform
      http_parser << client.readpartial(65535) if IO.select([client], nil, nil, 0.1)
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
      client.reply_data = proc { |msg, io| http_parser << msg }
      client.close_write
      req.env['PATH_INFO'] = '/invalid path'
      Thread.new { sleep 1; client.close unless client.closed? }
      subject.perform
      http_parser << client.readpartial(65535) if IO.select([client], nil, nil, 0.1)
      expect(http_parser.status).to eql(404)
      expect(http_parser.headers).to eql(
        "connection" => "Keep-Alive",
        "content-length" => http_parser.body.bytesize.to_s,
      )
      expect(http_parser.body).to eql("Not Found")
    end
  end

  describe 'WebSocket', server: true do
    let(:wsc) { WebSocket::Handshake::Client.new(url: 'ws://127.0.0.1/ws') }

    it 'GET /ws should handle websocket' do
      expect($config.shared_data.app.webui).to receive(:watch).with(kind_of(Xjz::WebUI::WebSocket))
      req.env['PATH_INFO'] = '/ws'
      req.env['HTTP_UPGRADE'] = 'websocket'
      req.env['HTTP_CONNECTION'] = 'upgrade'
      allow(req).to receive(:to_s).and_return(wsc.to_s)
      client.reply_data = proc { |data, io| wsc << data }
      t = Thread.new { subject.perform }
      sleep 0.1
      wsc << client.read_nonblock(65535) if IO.select([client], nil, nil, 0.1)
      expect(wsc.finished?).to eql(true)
      expect(wsc.valid?).to eql(true)
      msg = []
      $config.shared_data.webui.ws.bind(:message) { |frame| msg << frame }
      frame = WebSocket::Frame::Outgoing::Server.new(version: wsc.version, data: "Hello", type: :text)
      client << frame.to_s
      client.flush
      sleep 0.1
      expect(msg.first.data).to eql('Hello')
      t.kill
    end
  end
end
