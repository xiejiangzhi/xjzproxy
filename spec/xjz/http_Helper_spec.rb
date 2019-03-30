RSpec.describe Xjz::HTTPHelper do
  describe 'get_header' do
    let(:headers) { [[':method', 'a'], ['hehe', 123], ['Content-Type', 'text/plain']] }

    it 'should get return header' do
      expect(Xjz::HTTPHelper.get_header(headers, ':method')).to eql('a')
      expect(Xjz::HTTPHelper.get_header(headers, 'hehe')).to eql(123)
      expect(Xjz::HTTPHelper.get_header(headers, :hehe)).to eql(123)
      expect(Xjz::HTTPHelper.get_header(headers, :adsf)).to eql(nil)
      expect(Xjz::HTTPHelper.get_header(headers, 'conTent-tYpe')).to eql('text/plain')
    end
  end

  describe 'set_header' do
    let(:headers) { [[':method', 'a'], ['hehe', 123]] }

    it 'should update headers' do
      Xjz::HTTPHelper.set_header(headers, ':method', 'GET')
      expect(headers).to eql([[':method', 'GET'], ['hehe', 123]])

      Xjz::HTTPHelper.set_header(headers, 'hehe', '321')
      expect(headers).to eql([[':method', 'GET'], ['hehe', '321']])

      Xjz::HTTPHelper.set_header(headers, 'asdf', 'aaa')
      expect(headers).to eql([[':method', 'GET'], ['hehe', '321'], ['asdf', 'aaa']])

      Xjz::HTTPHelper.set_header(headers, ':status', '200')
      expect(headers).to eql([[':status', '200'], [':method', 'GET'], ['hehe', '321'], ['asdf', 'aaa']])
    end
  end

  describe 'write_conn_info_to_env!' do
    it 'should update env' do
      addr = double('addr', ip_address: '1.2.3.4')
      conn = double('conn', remote_address: addr)
      Xjz::IOHelper.set_proxy_host_port(conn, 'xjz.pw', '80')
      env = {}
      Xjz::HTTPHelper.write_conn_info_to_env!(env, conn)
      expect(env.keys).to eql(%w{
        REMOTE_ADDR SERVER_NAME SERVER_PORT rack.hijack? rack.hijack rack.hijack_io
      })
      expect(env['REMOTE_ADDR']).to eql('1.2.3.4')
      expect(env['SERVER_NAME']).to eql('xjz.pw')
      expect(env['SERVER_PORT']).to eql('80')
      expect(env['rack.hijack?']).to eql(true)
      expect(env['rack.hijack_io']).to eql(conn)
      expect(env['rack.hijack'].call).to eql(conn)
    end

    it 'should update env to https if conn is a sslsocket' do
      addr = double('addr', ip_address: '1.2.3.4')
      conn = double('conn', remote_address: addr, to_io: nil)
      Xjz::IOHelper.set_proxy_host_port(conn, 'xjz.pw', '443')
      allow(OpenSSL::SSL::SSLSocket).to receive('===').and_return(true)
      allow(conn).to receive(:to_io).and_return(conn)
      env = {}
      Xjz::HTTPHelper.write_conn_info_to_env!(env, conn)
      expect(env.keys).to eql(%w{
        REMOTE_ADDR SERVER_NAME SERVER_PORT rack.url_scheme rack.hijack? rack.hijack rack.hijack_io
      })
      expect(env['REMOTE_ADDR']).to eql('1.2.3.4')
      expect(env['SERVER_NAME']).to eql('xjz.pw')
      expect(env['SERVER_PORT']).to eql('443')
      expect(env['rack.hijack?']).to eql(true)
      expect(env['rack.hijack_io']).to eql(conn)
      expect(env['rack.hijack'].call).to eql(conn)
      expect(env['rack.url_scheme']).to eql('https')
    end
  end

  describe 'write_res_to_conn!' do
    it 'should send data to conn' do
      conn = StringIO.new
      res = Xjz::Response.new(
        [['Host', 'xjz.pw'], ['Content-Type', 'text/plan']],
        ['hello', ' world'],
        200
      )
      Xjz::HTTPHelper.write_res_to_conn(res, conn)
      conn.rewind
      expect(conn.read).to eql(
        <<~RES.strip
          HTTP/1.1 200 OK\r
          host: xjz.pw\r
          content-type: text/plan\r
          content-length: 11\r
          \r
          hello world
        RES
      )
    end

    it 'should not send data to conn if body is empty' do
      conn = StringIO.new
      res = Xjz::Response.new(
        [['Host', 'xjz.pw'], ['Content-Type', 'text/plan']], [], 200
      )
      Xjz::HTTPHelper.write_res_to_conn(res, conn)
      conn.rewind
      expect(conn.read).to eql(
        <<~RES
          HTTP/1.1 200 OK\r
          host: xjz.pw\r
          content-type: text/plan\r
          content-length: 0\r
          \r
        RES
      )
    end
  end
end
