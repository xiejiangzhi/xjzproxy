RSpec.describe Xjz::Server do
  describe 'Start' do
    let(:server) { Xjz::Server.new }

    after :each do
      server.stop_proxy
    end

    it 'should auto fetch first request' do
      server.start_proxy
      expect(server.app).to receive(:call) do |env|
        expect(env.delete('rack.errors')).to be_a(StringIO)
        expect(env.delete('rack.hijack')).to be_a(Proc)
        expect(env.delete('rack.hijack_io')).to be_a(TCPSocket)
        expect(env.delete('rack.hijack?')).to eql(true)
        expect(env.delete('rack.input')).to be_a(StringIO)
        expect(env).to eql(
          "GATEWAY_INTERFACE" => "CGI/1.2",
          "HTTP_HOST" => "xjz.pw",
          "PATH_INFO" => "/",
          "QUERY_STRING" => '',
          "REMOTE_ADDR" => "127.0.0.1",
          "REQUEST_METHOD" => "GET",
          "REQUEST_URI" => "/",
          "SCRIPT_NAME" => "",
          "SERVER_NAME" => "xjz.pw",
          "SERVER_PORT" => "80",
          "SERVER_PROTOCOL" => "HTTP/1.1",
          "rack.multiprocess" => false,
          "rack.multithread" => true,
          "rack.url_scheme" => "http"
        )
      end
      client = TCPSocket.new('127.0.0.1', $config['proxy_port'])
      client << <<~REQ
        GET / HTTP/1.1
        Host: xjz.pw

      REQ
      client.flush
      sleep 0.1
    end
  end
end
