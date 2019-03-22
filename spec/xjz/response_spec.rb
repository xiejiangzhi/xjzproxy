RSpec.describe Xjz::Response do
  describe 'From HTTP1' do
    let(:res) do
      Xjz::Response.new({
        'connection' => 'close',
        'transfer-encoding' => 'chunked',
        'other' => ['xxx', 'bb']
      }, ['hello', ' world'], 201)
    end

    it '#h1_headers should return http1 response headers' do
      expect(res.h1_headers).to eql([
        ['connection', 'close'], ['other', 'xxx, bb'], ['content-length', '11']
      ])
    end

    it '#h2_headers should return http1 response headers' do
      expect(res.h2_headers).to eql([
        [':status', '201'], ['other', 'xxx, bb'], ['content-length', '11']
      ])
    end

    it '#code should use http2 status' do
      expect(res.code).to eql(201)
    end

    it '#body should return body' do
      expect(res.body).to eql('hello world')
    end

    it '#body should convert nil to empty string' do
      expect(Xjz::Response.new({}, nil).body).to eql('')
    end

    it '#to_rack_response should return rack response' do
      expect(res.to_rack_response).to eql([201, res.h1_headers, ['hello world']])
    end

    it '#protocol should return true' do
      expect(res.protocol).to eql('http/1.1')
    end
  end

  describe 'From HTTP2' do
    let(:res) do
      Xjz::Response.new([
        [':status', '222'],
        ['connection', 'close'],
        ['transfer-encoding', 'chunked'],
        ['other', ['xxx', 'bb']]
      ], ['hello', ' world'])
    end

    it '#h1_headers should return http1 response headers' do
      expect(res.h1_headers).to eql([
        ['connection', 'close'], ['other', 'xxx, bb'], ['content-length', '11']
      ])
    end

    it '#h1_headers should return http1 response headers' do
      res = Xjz::Response.new([], [], nil)
      expect(res.code).to eql(200)
      expect(res.body).to eql('')
      expect(res.h1_headers).to eql([['content-length', '0']])
    end

    it '#h2_headers should return http1 response headers' do
      expect(res.h2_headers).to eql([
        [':status', '222'], ['other', 'xxx, bb'], ['content-length', '11']
      ])
    end

    it '#code should use http2 status' do
      expect(res.code).to eql(222)
    end

    it '#body should response body' do
      expect(res.body).to eql('hello world')
    end

    it '#to_rack_response should return rack response' do
      expect(res.to_rack_response).to eql([222, res.h1_headers, ['hello world']])
    end

    it '#protocol should return false' do
      expect(res.protocol).to eql('http/2.0')
    end
  end

  describe '#to_s' do
    let(:res) do
      Xjz::Response.new({
        'connection' => 'close',
        'transfer-encoding' => 'chunked',
        'other' => ['xxx', 'bb']
      }, ['hello', ' world'], 201)
    end

    it 'should return string of response' do
      expect(res.to_s).to eql(<<~RES.strip
        HTTP/1.1 201 Created\r
        connection: close\r
        other: xxx, bb\r
        content-length: 11\r
        \r
        hello world
      RES
      )
    end
  end
end
