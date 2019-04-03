RSpec.describe Xjz::Resolver::Forward do
  describe 'perform' do
    it 'should should forward user_socket & req target' do
      FakeIO.hijack_socket!(binding)
      r1, l1 = FakeIO.pair
      r2, l2 = FakeIO.pair
      r2.reply_data = [['data', 1024], ['', 1024]]
      req = Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'SERVER_PORT' => '443',
        'PATH_INFO' => '/',
        'REQUEST_METHOD' => 'CONNECT',
        'rack.hijack' => proc { r1.to_io },
        'rack.hijack_io' => r1.to_io
      )
      subject = Xjz::Resolver::Forward.new(req)
      expect(Socket).to receive(:tcp).with('xjz.pw', 443, connect_timeout: 1).and_return(l2.to_io)

      l1.write("hello")
      Thread.new { sleep 0.1; l1.write(" asdf"); l1.close_write }
      Thread.new { r2.ssl_accept }
      subject.perform
      expect(l1.readpartial(1024)).to eql("HTTP/1.1 200 OK\r\ncontent-length: 0\r\n\r\ndata")
      expect(r2.rdata).to eql(['hello', ' asdf'])

      expect(l2.sslsock.sync_close).to eql(true)
      expect(l2.sslsock.hostname).to eql('xjz.pw')
    end

    it 'should should forward socket for http request' do
      r1, l1 = FakeIO.pair
      r2, l2 = FakeIO.pair
      req = Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'http',
        'SERVER_PORT' => '443',
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/',
        'HTTP_CONNECTION' => 'Upgrade',
        'rack.hijack' => proc { r1.io },
        'rack.hijack_io' => r1.io,
        'rack.input' => StringIO.new('hello')
      )
      new_req = req.dup
      new_req.forward_conn_attrs = true
      new_req.instance_eval { @body = req.env['rack.input'].string }
      subject = Xjz::Resolver::Forward.new(req)
      expect(Socket).to receive(:tcp).with('xjz.pw', 443, connect_timeout: 1).and_return(l2.to_io)
      Thread.new { sleep 0.1; r2.write("world"); l1.close_write }
      subject.perform
      expect(l1.tread).to eql('world')
      expect(r2.tread).to eql(new_req.to_s)
    end
  end
end
