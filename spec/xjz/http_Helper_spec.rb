RSpec.describe Xjz::HTTPHelper do
  let(:subject) { Xjz::HTTPHelper }

  describe 'get_header' do
    let(:headers) { [[':method', 'a'], ['hehe', 123], ['Content-Type', 'text/plain']] }

    it 'should get return header' do
      expect(subject.get_header(headers, ':method')).to eql('a')
      expect(subject.get_header(headers, 'hehe')).to eql(123)
      expect(subject.get_header(headers, :hehe)).to eql(123)
      expect(subject.get_header(headers, :adsf)).to eql(nil)
      expect(subject.get_header(headers, 'conTent-tYpe')).to eql('text/plain')
    end
  end

  describe 'set_header' do
    let(:headers) { [[':method', 'a'], ['hehe', 123]] }

    it 'should update headers' do
      subject.set_header(headers, ':method', 'GET')
      expect(headers).to eql([[':method', 'GET'], ['hehe', 123]])

      subject.set_header(headers, 'hehe', '321')
      expect(headers).to eql([[':method', 'GET'], ['hehe', '321']])

      subject.set_header(headers, 'asdf', 'aaa')
      expect(headers).to eql([[':method', 'GET'], ['hehe', '321'], ['asdf', 'aaa']])

      subject.set_header(headers, ':status', '200')
      expect(headers).to eql([[':status', '200'], [':method', 'GET'], ['hehe', '321'], ['asdf', 'aaa']])
    end
  end

  describe 'write_conn_info_to_env!' do
    it 'should update env' do
      addr = double('addr', ip_address: '1.2.3.4')
      conn = double('conn', remote_address: addr)
      Xjz::IOHelper.set_proxy_host_port(conn, 'xjz.pw', '80')
      env = {}
      subject.write_conn_info_to_env!(env, conn)
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
      subject.write_conn_info_to_env!(env, conn)
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
      subject.write_res_to_conn(res, conn)
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
      subject.write_res_to_conn(res, conn)
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

    describe '.parse_data_by_type' do
      it 'should parse json' do
        r = subject.parse_data_by_type({ a: 1 }.to_json, 'application/json')
        expect(r).to eql('a' => 1)
      end

      it 'should parse www-form-urlencoded' do
        r = subject.parse_data_by_type('a=1&b=123', 'application/x-www-form-urlencoded')
        expect(r).to eql('a' => '1', 'b' => '123')
      end

      it 'should parse xml' do
        r = subject.parse_data_by_type(<<-XML, 'application/xml')
          <?xml version="1.0" encoding="UTF-8"?>
          <xxx>
            <foo type="integer">1</foo>
            <bar type="integer">2</bar>
          </xxx>
        XML
        expect(r).to eql('xxx' => { 'foo' => 1, 'bar' => 2 })
      end

      it 'should parse undefined type' do
        r = subject.parse_data_by_type('a=1&b=123', 'asdf')
        expect(r).to eql('a' => '1', 'b' => '123')

        r = subject.parse_data_by_type({ a: 122 }.to_json, 'asdf')
        expect(r).to eql('a' => 122)

        r = subject.parse_data_by_type({ a: 2 }.to_xml, 'asdf')
        expect(r).to eql('hash' => { 'a' => 2 })
      end
    end
  end
end
