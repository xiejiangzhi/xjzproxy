RSpec.describe Xjz::Reslover::Forward do
  describe 'perform' do
    it 'should should forward user_socket & req target' do
      user, client = UNIXSocket.pair
      remote, server = UNIXSocket.pair
      req = Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'SERVER_PORT' => '443',
        'rack.hijack' => proc { client },
        'rack.hijack_io' => client
      )
      subject = Xjz::Reslover::Forward.new(req)
      expect(TCPSocket).to receive(:new).with('xjz.pw', 443).and_return(remote)
      user.write("hello")
      server.write("world")
      Thread.new { sleep 0.1; user.write(" asdf"); user.close_write }
      subject.perform
      expect(user.read).to eql('world')
      expect(server.read).to eql('hello asdf')

      [user, client, remote, server].each(&:close)
    end
  end
end
