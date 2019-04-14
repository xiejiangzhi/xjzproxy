RSpec.describe Xjz::WebUI::WebSocket do
  let(:wsc) { WebSocket::Handshake::Client.new(url: 'ws://127.0.0.1/ws') }
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
      "REQUEST_METHOD" => "GET",
      "REQUEST_URI" => "/ws",
      "HTTP_HOST" => "127.0.0.1",
      "HTTP_ACCEPT" => "*/*",
      "HTTP_UPGRADE" => "websocket",
      "HTTP_CONNECTION" => "upgrade",
      'HTTP_SEC_WebSocket_Version' => '13',
      'HTTP_Sec_WebSocket_Key' => 'dGhlIHNhbXBsZSBub25jZQ==',
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
  let(:events) { [] }
  let(:msg_parser) { WebSocket::Frame::Incoming::Client.new(version: wsc.version) }

  describe 'receive/send msg' do
    before :each do
      subject.bind(:open) { events << :open }
      subject.bind(:message) { |f| events << [:message, f] }
      subject.bind(:close) { events << :close }
      client.reply_data = proc { |data, io| (wsc.finished? ? msg_parser : wsc) << data }
      @thread = Thread.new { subject.perform }
    end

    after :each do
      @thread.kill
    end

    def send_msg(msg)
      client << WebSocket::Frame::Outgoing::Client.new(version: wsc.version, data: msg, type: :text)
      client.flush
    end

    def recv_msg
      msg_parser.next
    end

    it 'should call events' do
      sleep 0.1
      expect(events).to eql([:open])
      send_msg('hello123')
      sleep 0.1
      expect(events.length).to eql(2)
      expect(events[1][0]).to eql(:message)
      expect(events[1][1].data).to eql('hello123')
      expect(recv_msg.data).to eql({ type: 'hello', data: "I'm XjzProxy server" }.to_json)
      subject.send_msg('hello', 'world 321')
      sleep 0.1
      expect(recv_msg.data).to eql({ type: 'hello', data: 'world 321' }.to_json)
      expect(recv_msg).to be_nil
      subject.conn.flush
      client.close
      sleep 0.1
      expect(recv_msg).to be_nil
      expect(events.length).to eql(3)
      expect(events.last).to eql(:close)
    end

    it 'should send and receive data when has multiple threads' do
      msgs = 20.times.map { |i| "msg #{i}" }
      10.times { |i| Thread.new { send_msg(msgs[i]) } }
      10.times { |i| Thread.new { subject.send_msg('v', msgs[19 - i]) } }
      sleep 0.1
      expect(events[1..-1].map { |e, f| [e, f.data] }.sort).to \
        eql(msgs[0..9].map { |m| [:message, m] })
      expect(12.times.map { recv_msg&.data }.sort_by(&:to_s)).to eql(
        [nil] + [{ type: "hello", data: "I'm XjzProxy server" }.to_json] +
        msgs[10..19].map { |v| { type: 'v', data: v }.to_json }
      )
    end
  end
end
