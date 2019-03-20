RSpec.describe Xjz::Reslover::SSL do
  describe 'perform' do
    it 'should wrap socket with ssl and call http1 reslover' do
      client, remote = socket_pair
      ssl_client = OpenSSL::SSL::SSLSocket.new(client)
      req = Xjz::Request.new(
        'rack.hijack' => Proc.new { remote },
        'rack.hijack_io' => remote
      )
      expect_any_instance_of(Xjz::RequestDispatcher).to receive(:call) do |t, env|
        new_req = Xjz::Request.new(env)
        expect(new_req.http_method).to eql('get')
        expect(new_req.url).to eql('https://xjz.pw/')
        expect(new_req.host).to eql('xjz.pw')
      end
      reslover = Xjz::Reslover::SSL.new(req)
      t = Thread.new { reslover.perform }
      IO.select([client])
      expect(client.read_nonblock(1024)).to eql("HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\n")
      ssl_client.hostname = 'xjz.pw'
      ssl_client.connect
      expect(ssl_client.peer_cert.subject.to_s).to eql("/CN=xjz.pw/O=XjzProxy")
      ssl_client << <<~REQ
        GET / HTTP/1.1
        Host: xjz.pw:443

      REQ
      client.close_write
      sleep 0.1
      t.kill
      client.close
      remote.close
    end
  end
end
