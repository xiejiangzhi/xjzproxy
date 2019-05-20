RSpec.describe Xjz::Server do
  describe 'start', server: true do
    let(:server) { $config.shared_data.app.server }

    it 'should auto fetch first request' do
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
      client.close_write
      sleep 0.1
    end
  end

  describe '#total_proxy_conns' do
    it 'should return a number' do
      expect($config.shared_data.app.server.total_proxy_conns).to eql(0)
    end
  end

  describe 'start_proxy' do
    it 'should not raise error if port was used', log: false do
      s = Xjz::Server.new
      expect { s.start_proxy }.to_not raise_error
      expect(s.proxy_socket).to be_nil
    end
  end
end
