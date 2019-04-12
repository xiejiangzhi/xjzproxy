RSpec.describe Xjz::WebUI::PageManager do
  let(:req) do
    Xjz::Request.new(
      "QUERY_STRING" => "",
      "SERVER_PROTOCOL" => "HTTP/1.1",
      "REQUEST_METHOD" => "GET",
      "REQUEST_URI" => "/ws",
      "HTTP_HOST" => "127.0.0.1",
      "HTTP_UPGRADE" => "websocket",
      "HTTP_CONNECTION" => "upgrade",
      'HTTP_SEC_WebSocket_Version' => '13',
      'HTTP_Sec_WebSocket_Key' => 'dGhlIHNhbXBsZSBub25jZQ==',
      "SERVER_NAME" => "127.0.0.1",
      "SERVER_PORT" => "80",
      "PATH_INFO" => "/",
      "REMOTE_ADDR" => "127.0.0.1",
      "rack.hijack?" => true,
      "rack.hijack" => Proc.new { StringIO.new },
      "rack.hijack_io" => StringIO.new,
      "rack.input" => StringIO.new,
      "rack.url_scheme" => "http"
    )
  end
  let(:ws) { Xjz::WebUI::WebSocket.new(req) }
  let(:sframe) { WebSocket::Frame::Incoming::Server.new(version: 13) }

  describe '#watch' do
    it 'should bind message event' do
      expect(ws).to receive(:bind) do |name, &block|
        expect(name).to eql(:message)
        expect(block.source).to eql(subject.method(:on_message).source)
      end

      subject.watch(ws)
    end
  end

  describe '#on_message' do
    def new_msg(type, data)
      WebSocket::Frame::Outgoing::Client.new(
        version: 13, data: { type: type, data: data }.to_json, type: :text
      ).to_s
    end

    it 'should process message' do
      r = Time.now.to_f
      expect(subject.action_router).to receive(:call) do |msg_obj|
        expect(msg_obj.type).to eql('ready')
        expect(msg_obj.data).to eql('hello')
        expect(msg_obj).to be_respond_to(:send_msg)
        r
      end
      sframe << new_msg('ready', 'hello')
      expect(subject.on_message(sframe.next)).to eql(r)
    end
  end
end
