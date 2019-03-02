RSpec.describe Xjz::RequestHelper do
  describe '.process_res_headers' do
    let(:header) { { 'transfer-encoding' => 'chunked', 'content-type' => 'text/plan' } }

    it 'should delete transfer-encoding header' do
      expect(subject.process_res_headers(header)).to eql('content-type' => 'text/plan')
      expect(header).to eql('content-type' => 'text/plan')
    end
  end

  describe '.fetch_req_headers' do
    let(:env) do
      {
        'a' => '1',
        'b' => '2',
        'HTTP_A' => '123',
        'HTTP_USER_AGENT' => 'XjzProxy',
        'REQUEST_METHOD' => 'GET',
        'HTTP_VERSION' => 'HTTP/1.1',
        'HTTP_x' => 'x',
        'HTTP' => true,
        'rack.a' => 'y',
        'H2_A' => '123',
        'HTTP_CONNECTION' => 'keep-alive',
        'HTTP_KEEP_ALIVE' => 'k',
        'HTTP_PROXY_AUTHENTICATE' => 'user:pass',
        'HTTP_PROXY_AUTHORIZATION' => 'user:pass',
        'HTTP_TE' => 'te',
        'HTTP_TRAILERS' => 'xx',
        'HTTP_TRANSFER_ENCODING' => 'encoding',
        'HTTP_UPGRADE' => 'yyy',
        'HTTP_SET_COOKIE' => 'yyy',
        'HTTP_PROXY_CONNECTION' => 'cc'
      }
    end

    it 'should return http header and remove invalid' do
      header = {
        'a' => '123',
        'user-agent' => 'XjzProxy',
        'version' => 'HTTP/1.1',
        'x' => 'x'
      }
      expect(subject.fetch_req_headers(env)).to eql(header)
      expect(env['xjz.header']).to eql(header)
    end
  end

  describe '.nonblock_copy_stream' do
    let(:dst) { StringIO.new('') }

    it 'should copy stream and auto close' do
      rd, wr = IO.pipe
      wr << 'hello '
      expect(subject.nonblock_copy_stream(rd, dst)).to eql(true)
      expect(dst.closed_write?).to eql(false)
      dst.rewind
      expect(dst.read).to eql('hello ')

      wr << 'world'
      expect(subject.nonblock_copy_stream(rd, dst)).to eql(true)
      expect(dst.closed_write?).to eql(false)
      dst.rewind
      expect(dst.read).to eql('hello world')

      wr.close
      expect(subject.nonblock_copy_stream(rd, dst)).to eql(false)
      expect(dst.closed_write?).to eql(true)
      dst.rewind
      expect(dst.read).to eql('hello world')
    end

    it 'should not auto close if auto eof is false' do
      rd, wr = IO.pipe
      wr << 'hello '
      wr << ''
      wr << 'world'
      wr.close
      expect(subject.nonblock_copy_stream(rd, dst, auto_eof: false)).to eql(false)
      expect(dst.closed_write?).to eql(false)
      dst.rewind
      expect(dst.read).to eql('hello world')
    end
  end

  describe '.forward_stream' do
    it 'should forward stream by hash mapping' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      rw3 = StringIO.new

      w1 << 'some data'
      Thread.new do
        sleep 0.1
        w1 << ' more data'
        sleep 0.1
        w1 << ' end data'
        w1.close
      end

      expect(subject.forward_streams(r1 => w2, r2 => rw3)).to eql(true)
      expect(w2.closed?).to eql(true)
      expect(rw3.closed_write?).to eql(true)
      rw3.rewind
      expect(rw3.read).to eql('some data more data end data')
    end

    it 'should timeout when too long have no data' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      rw3 = StringIO.new
      w1 << 'a'

      expect(subject.forward_streams({ r1 => w2, r2 => rw3 }, timeout: 0.5)).to eql(false)
      expect(w2.closed?).to eql(false)
      expect(rw3.closed_write?).to eql(false)
      rw3.rewind
      expect(rw3.read).to eql('a')
    end
  end

  describe '.import_h2_header_to_env' do
    let(:h2_header) do
      [
        [':method', 'GET'], [':path', '/root'],
        [':authority', 'xjz.pw'], ['content-type', 'text/plan']
      ]
    end

    it 'should update env' do
      env = { 'xjz.url' => 'http://xjz.pw/asdf', 'REQUEST_METHOD' => 'PRI', 'REQUEST_PATH' => '*' }
      subject.import_h2_header_to_env(env, h2_header)
      expect(env).to eql(
        "H2_AUTHORITY" => "xjz.pw",
        "H2_METHOD" => "GET",
        "H2_PATH" => "/root",
        "HTTP_CONTENT_TYPE" => "text/plan",
        "HTTP_HOST" => "xjz.pw",
        "REQUEST_METHOD" => "GET",
        "REQUEST_PATH" => "/root",
        "xjz.h2_header" => h2_header,
        "xjz.url" => "http://xjz.pw/asdf"
      )
    end

    it 'should not update env host if env have http host' do
      env = { 'xjz.url' => 'http://xjz.pw/asdf', 'HTTP_HOST' => 'asdf.com' }
      subject.import_h2_header_to_env(env, h2_header)
      expect(env).to eql(
        "H2_AUTHORITY" => "xjz.pw",
        "H2_METHOD" => "GET",
        "H2_PATH" => "/root",
        "HTTP_CONTENT_TYPE" => "text/plan",
        "HTTP_HOST" => "asdf.com",
        "REQUEST_METHOD" => "GET",
        "REQUEST_PATH" => "/root",
        "xjz.h2_header" => h2_header,
        "xjz.url" => "http://xjz.pw/asdf"
      )
    end
  end

  describe '.generate_h2_response' do
    it 'should convert http1 response to h2' do
      data = 'hello world'
      header, body = subject.generate_h2_response([
        200, { 'content-type' => 'text/html', 'connection' => 'close' }, [data, data]
      ])
      expect(header).to eql([
        [':status', '200'],
        ['content-type', 'text/html'],
        ['content-length', (data.length * 2).to_s]
      ])
      expect(body).to eql(data * 2)
    end
  end
end
