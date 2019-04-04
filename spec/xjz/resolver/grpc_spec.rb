RSpec.describe Xjz::Resolver::GRPC do
  describe 'perform' do
    it 'should connect with tcp and call RequestDispatcher resolver' do
      _server, rsock, lsock = FakeIO.server_pair
      req = Xjz::Request.new(
        'rack.hijack' => Proc.new { rsock.io },
        'rack.hijack_io' => rsock.io
      )
      resolver = Xjz::Resolver::GRPC.new(req)
      expect_any_instance_of(Xjz::RequestDispatcher).to receive(:call) do |t, env|
        new_req = Xjz::Request.new(env)
        expect(new_req.http_method).to eql('get')
        expect(new_req.url).to eql('http://xjz.pw/')
        expect(new_req.host).to eql('xjz.pw')
      end
      t = Thread.new { resolver.perform }
      IO.select([lsock])
      expect(lsock.read_nonblock(1024)).to eql("HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n")
      lsock << <<~REQ
        GET / HTTP/1.1
        Host: xjz.pw

      REQ
      rsock.close_write
      sleep 0.1
      t.kill
    end
  end
end
