RSpec.describe Xjz::Reslover::Forward do
  describe 'perform' do
    it 'should should forward user_socket & req target' do
      user, client = UNIXSocket.pair
      remote, server = UNIXSocket.pair
      req = Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'SERVER_PORT' => '443',
        'PATH_INFO' => '/',
        'REQUEST_METHOD' => 'CONNECT',
        'rack.hijack' => proc { client },
        'rack.hijack_io' => client
      )
      subject = Xjz::Reslover::Forward.new(req)
      expect(TCPSocket).to receive(:new).with('xjz.pw', 443).and_return('tcpsock')
      expect(OpenSSL::SSL::SSLSocket).to receive(:new) \
        .with('tcpsock', kind_of(OpenSSL::SSL::SSLContext)).and_return(remote)
      remote.singleton_class.class_eval { attr_accessor :sync_close, :hostname, :connect }
      expect(remote).to receive(:sync_close=).with(true)
      expect(remote).to receive(:hostname=).with('xjz.pw')
      expect(remote).to receive(:connect)

      user.write("hello")
      server.write("world")
      Thread.new { sleep 0.1; user.write(" asdf"); user.close_write }
      subject.perform
      expect(user.read).to eql('world')
      expect(server.read).to eql('hello asdf')

      [user, client, remote, server].each(&:close)
    end

    it 'should should forward socket for http request' do
      user, client = UNIXSocket.pair
      remote, server = UNIXSocket.pair
      req = Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'http',
        'SERVER_PORT' => '443',
        'REQUEST_METHOD' => 'GET',
        'PATH_INFO' => '/',
        'HTTP_CONNECTION' => 'Upgrade',
        'rack.hijack' => proc { client },
        'rack.hijack_io' => client,
        'rack.input' => StringIO.new('hello')
      )
      new_req = req.dup
      new_req.forward_conn_attrs = true
      new_req.instance_eval { @body = 'hello' }
      subject = Xjz::Reslover::Forward.new(req)
      expect(TCPSocket).to receive(:new).with('xjz.pw', 443).and_return(remote)
      server.write("world")
      Thread.new { user.close_write }
      subject.perform
      expect(user.read).to eql('world')
      expect(server.read).to eql(new_req.to_s)

      [user, client, remote, server].each(&:close)
    end
  end
end
