RSpec.describe Xjz::ApiProject do
  let(:file_path) { File.join($root, 'spec/files/project.yml') }
  let(:dir_path) { File.join($root, 'spec/files/project') }
  let(:ap) { Xjz::ApiProject.new(file_path) }

  describe '#hack_req' do
    it 'should generate response for a valid req' do
      dts = ap.data['types']
      allow(dts['integer']).to receive(:generate).and_return(123)
      allow(dts['text']).to receive(:generate).and_return('some text')
      allow(dts['string']).to receive(:generate).and_return('asdf')
      allow(dts['avatar']).to receive(:generate).and_return('http://a.com/a.png')

      r = ap.hack_req(Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'PATH_INFO' => '/api/v1/users',
        'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_a(Xjz::Response)
      expect(r.code).to eql(200)
      expect(JSON.parse(r.body)).to eql(
        "items" => [
          {
            "avatar" => "http://a.com/a.png", "id" => 123, "nickname" => "asdf",
            "posts" => [
              { "body" => "some text", "id" => 123, "title" => "a post title" },
              { "body" => "some text", "id" => 123, "title" => "a post title" },
              { "body" => "some text", "id" => 123, "title" => "a post title" }
            ]
          },
          {
            "avatar" => "http://a.com/a.png", "id" => 123, "nickname" => "asdf",
            "posts" => [
              { "body" => "some text", "id" => 123, "title" => "a post title" },
              { "body" => "some text", "id" => 123, "title" => "a post title" },
              { "body" => "some text", "id" => 123, "title" => "a post title" }
            ]
          }
        ],
        "total" => 123
      )
      expect(r.h1_headers).to eql([["content-type", "application/json"], ["content-length", "479"]])
    end

    it 'should return nil for a invalid req' do
      r = ap.hack_req(Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'PATH_INFO' => '/api/v4/uers',
        'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_nil
    end

    it 'should return nil if api.enabled == true' do
      ap.data['apis'].values.map(&:values).flatten.each do |api|
        om = api.method(:[])
        allow(api).to receive(:[]) do |name|
          name == 'enabled' ? false : om.call(name)
        end
      end

      r = ap.hack_req(Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'PATH_INFO' => '/api/v1/users',
        'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_nil
    end

    it 'should return nil if api[.enabled] == true' do
      ap.data['apis'].values.map(&:values).flatten.each do |api|
        om = api.method(:[])
        allow(api).to receive(:[]) do |name|
          name == '.enabled' ? false : om.call(name)
        end
      end

      r = ap.hack_req(Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'PATH_INFO' => '/api/v1/users',
        'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_nil
    end

    it 'should return a response for grpc request' do
      file_path = File.join($root, 'spec/files/grpc.yml')
      ap = Xjz::ApiProject.new(file_path)
      r = ap.hack_req(Xjz::Request.new(
        'HTTP_HOST' => 'grpc.xjz.pw',
        'HTTP_CONTENT_TYPE' => 'application/grpc',
        'HTTP_ACCEPT' => 'application/grpc',
        'rack.url_scheme' => 'https',
        'PATH_INFO' => '/Hw.Greeter/SayHello',
        'REQUEST_METHOD' => 'POST'
      ))
      expect(r.code).to eql(400)
      expect(r.h1_headers).to eql([
        ["a", "aaa"], ["content-type", "application/grpc"], ["content-length", "35"]
      ])
      expect(r.body).to eql("\x00\x00\x00\x00\x1E\n\nhello gRPC\x12\x02\b\x17\x1A\x01a\x1A\x01b*\x06data b")
    end
  end

  describe '#raw_data' do
    it 'should return raw_data when load a file' do
      ap = Xjz::ApiProject.new(file_path)
      erb = ERB.new(File.read(file_path))
      erb.filename = file_path
      data = YAML.load(erb.result, filename: file_path)
      data['project']['dir'] = File.dirname(file_path)
      expect(ap.raw_data).to eql(data)
    end

    it 'should return raw_data when load a dir' do
      ap = Xjz::ApiProject.new(dir_path)
      erb = ERB.new(File.read(file_path))
      erb.filename = File.join(dir_path, 'config.yml')
      data = YAML.load(erb.result, filename: dir_path)
      data['project']['dir'] = dir_path
      expect(ap.raw_data).to eql(data)
    end
  end

  describe '#data' do
    it 'should parse data by Parser' do
      ap = Xjz::ApiProject.new(file_path)
      t = Time.now
      expect(Xjz::ApiProject::Parser).to receive(:parse).with(ap.raw_data).and_return(a: t)
      expect(ap.data).to eql(a: t)
      expect(ap.data).to eql(a: t)
    end
  end

  describe '#errors' do
    it 'should verify by Parser' do
      ap = Xjz::ApiProject.new(file_path)
      t = Time.now
      expect(Xjz::ApiProject::Verifier).to receive(:verify) \
        .with(ap.raw_data, file_path).and_return([t])
      expect(ap.errors).to eql([t])
    end
  end

  describe '.match_host?' do
    it 'should return true if match host' do
      expect(ap.match_host?('xjz.pw')).to eql(true)
    end

    it 'should return false if not match host' do
      expect(ap.match_host?('asdf.pw')).to eql(false)
    end
  end

  describe '#find_api' do
    it 'should return api desc' do
      expect(ap.find_api('get', 'https', 'xjz.pw', '/api/v1/users')['title']).to \
        eql('Get all users')
      expect(ap.find_api('get', 'http', 'xjz.pw', '/api/v1/users')['title']).to \
        eql('Get all users')
      expect(ap.find_api('get', 'http', 'asdf.com', '/api/v1/users/123')['title']).to \
        eql('Get user')
    end

    it 'should return nil if not found any' do
      expect(ap.find_api('get', 'https', 'xjz.pw123', '/api/v1/users')).to be_nil
      expect(ap.find_api('get', 'hxxp', 'xjz.pw', '/api/v1/users')).to be_nil
      expect(ap.find_api('get', 'https', 'asdf.com', '/api/v1/users/123')).to be_nil
      expect(ap.find_api('get', 'http', 'asdf.com', '/api/v2/users/123')).to be_nil
      expect(ap.find_api('get', nil, 'asdf.com', '/api/v2/users/123')).to be_nil
    end

    it 'should return api if have not scheme and host' do
      expect(ap.find_api('get', nil, nil, '/api/v1/users')['title']).to eql('Get all users')
      expect(ap.find_api('get', nil, nil, '/api/v1/users/3')['title']).to eql('Get user')
    end
  end
end
