RSpec.describe Xjz::ApiProject do
  let(:file_path) { File.join($root, 'spec/files/project.yml') }
  let(:dir_path) { File.join($root, 'spec/files/project') }
  let(:ap) { Xjz::ApiProject.new(file_path) }
  let(:grpc_poj_path) { File.join($root, 'spec/files/grpc.yml') }

  describe '#hack_req' do
    it 'should generate response for a valid req' do
      dts = ap.data['types']
      mid = 'MID-aaa-bbb'
      allow(dts['integer']).to receive(:generate).and_return(123)
      allow(dts['myid']).to receive(:generate).and_return(mid)
      allow(dts['text']).to receive(:generate).and_return('some text')
      allow(dts['string']).to receive(:generate).and_return('asdf')
      allow(dts['avatar']).to receive(:generate).and_return('http://a.com/a.png')

      r = ap.hack_req(Xjz::Request.new(
        'PATH_INFO' => '/api/v1/users', 'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_a(Xjz::Response)
      expect(r.code).to eql(200)
      expect(JSON.parse(r.body)).to eql(
        "items" => [
          {
            "avatar" => "http://a.com/a.png", "id" => 123, "nickname" => "asdf",
            "posts" => [
              { "body" => "some text", "id" => mid, "title" => "a post title" },
              { "body" => "some text", "id" => mid, "title" => "a post title" },
              { "body" => "some text", "id" => mid, "title" => "a post title" }
            ]
          },
          {
            "avatar" => "http://a.com/a.png", "id" => 123, "nickname" => "asdf",
            "posts" => [
              { "body" => "some text", "id" => mid, "title" => "a post title" },
              { "body" => "some text", "id" => mid, "title" => "a post title" },
              { "body" => "some text", "id" => mid, "title" => "a post title" }
            ]
          }
        ],
        "total" => 123
      )
      expect(r.h1_headers).to eql([
        ["content-type", "application/json; charset=utf-8"], ["content-length", "539"]
      ])
    end

    it 'should generate response for specified res name' do
      dts = ap.data['types']
      allow(dts['integer']).to receive(:generate).and_return(123)
      allow(dts['text']).to receive(:generate).and_return('some text')
      allow(dts['string']).to receive(:generate).and_return('asdf')
      allow(dts['avatar']).to receive(:generate).and_return('http://a.com/a.png')

      r = ap.data['apis'][0]['response']
      allow(r).to receive(:[]) { |k| k == '.default' ? 'error' : r.fetch(k) }

      r = ap.hack_req(Xjz::Request.new(
        'PATH_INFO' => '/api/v1/users', 'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_a(Xjz::Response)
      expect(r.code).to eql(400)
      expect(JSON.parse(r.body)).to eql("code" => 1, "msg" => 'Invalid token')
      expect(r.h1_headers).to eql([
        ["content-type", "application/json; charset=utf-8"], ["content-length", "32"]
      ])
    end

    it 'should return nil for a invalid req' do
      r = ap.hack_req(Xjz::Request.new(
        'PATH_INFO' => '/api/v4/uers', 'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_nil
    end

    it 'should return nil if api.enabled == false' do
      ap.data['apis'].each do |api|
        om = api.method(:[])
        allow(api).to receive(:[]) do |name|
          name == 'enabled' ? false : om.call(name)
        end
      end

      r = ap.hack_req(Xjz::Request.new(
        'PATH_INFO' => '/api/v1/users', 'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_nil
    end

    it 'should return nil if ap[.enabled] == false' do
      data = ap.data.deep_dup
      allow(ap).to receive(:data).and_return(data)
      data['.enabled'] = false

      r = ap.hack_req(Xjz::Request.new(
        'PATH_INFO' => '/api/v1/users', 'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_nil
    end

    it 'should return nil if ap[.mode] == watch' do
      data = ap.data.deep_dup
      allow(ap).to receive(:data).and_return(data)
      data['.mode'] = 'watch'

      r = ap.hack_req(Xjz::Request.new(
        'PATH_INFO' => '/api/v1/users', 'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_nil
    end

    it 'should return res if ap[.mode] == mock' do
      data = ap.data.deep_dup
      allow(ap).to receive(:data).and_return(data)
      data['.mode'] = 'mock'

      r = ap.hack_req(Xjz::Request.new(
        'PATH_INFO' => '/api/v1/users', 'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to_not be_nil
    end

    it 'should return a response for grpc request' do
      ap = Xjz::ApiProject.new(grpc_poj_path)
      r = ap.hack_req(Xjz::Request.new(
        'HTTP_CONTENT_TYPE' => 'application/grpc',
        'HTTP_ACCEPT' => 'application/grpc',
        'PATH_INFO' => '/Hw.Greeter/SayHello',
        'REQUEST_METHOD' => 'POST'
      ))
      expect(r.code).to eql(400)
      expect(r.h1_headers).to eql([
        ["a", "aaa"], ["content-type", "application/grpc; charset=utf-8"], ["content-length", "35"]
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
      data['project']['.dir'] = File.dirname(file_path)
      expect(ap.raw_data).to eql(data)
    end

    it 'should return raw_data when load a dir' do
      ap = Xjz::ApiProject.new(dir_path)
      erb = ERB.new(File.read(file_path))
      erb.filename = File.join(dir_path, 'config.yml')
      data = YAML.load(erb.result, filename: dir_path)
      data['project']['.dir'] = dir_path
      expect(ap.raw_data).to eql(data)
    end

    it 'should return empty data when load a empty file' do
      invalid_file = File.join($root, 'tmp/empty.yml')
      `touch #{invalid_file}`
      ap = Xjz::ApiProject.new(invalid_file)
      expect(ap.raw_data).to eql({})
    end

    it 'should return empty data when load a invalid file' do
      invalid_file = File.join($root, 'tmp/array.yml')
      `echo "- a: 1" > #{invalid_file}`
      ap = Xjz::ApiProject.new(invalid_file)
      expect(ap.raw_data).to eql({})
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
    it 'should return boolean according to host' do
      expect(ap.match_host?('xjz.pw')).to eql(true)

      k = '.host_regexp'
      allow(ap).to receive(:data).and_return('project' => { k => %r{.+\.xjz\.pw} })
      expect(ap.match_host?('xjz.pw')).to eql(false)
      expect(ap.match_host?('blog.xjz.pw')).to eql(true)

      expect(ap.match_host?('asdf.pw')).to eql(false)
    end

    it 'should return false if data[.enabled] == false ' do
      allow(ap).to receive(:data).and_return('.enabled' => false)
      expect(ap.match_host?('xjz.pw')).to eql(false)
    end
  end

  describe '#grpc' do
    let(:ap) { Xjz::ApiProject.new(grpc_poj_path) }

    it 'should return grpc instance' do
      expect(ap.grpc).to be_a(Xjz::ApiProject::GRPC)
    end

    it 'should return nil if for trial edition' do
      allow($config).to receive(:data).and_return($config.data.dup)
      $config['.edition'] = nil
      expect(ap.grpc).to eql(nil)
    end
  end

  describe '#find_api' do
    it 'should return api desc' do
      expect(ap.find_api('get', '/api/v1/users')['title']).to eql('Get all users')
      expect(ap.find_api('get', '/api/v1/users/123')['title']).to eql('Get user')
    end

    it 'should return nil if not found any' do
      expect(ap.find_api('post', '/api/v1/users/123')).to be_nil
      expect(ap.find_api('get', '/api/v2/users/123')).to be_nil
      expect(ap.find_api('get', '/api/v2/users/123')).to be_nil
    end
  end

  describe '#reload' do
    it 'should reload data' do
      [ap.data, ap.raw_data, ap.grpc, ap.errors]
      expect(Xjz::ApiProject::Parser).to receive(:parse).and_return({})
      expect(ap).to receive(:raw_data).and_return({})
      travel_to(Time.now + 5)
      ap.cache[:a] = 123

      data = { '.enabled' => nil, '.mode' => nil }

      expect {
        ap.reload
      }.to change {
        ap.instance_eval { [@data, @raw_data, @grpc, @errors, @cache] }
      }.to([data, nil, nil, nil, {}])
    end

    it 'should not reload data for new project' do
      [ap.data, ap.raw_data, ap.grpc, ap.errors]
      expect(Xjz::ApiProject::Parser).to_not receive(:parse)

      expect {
        ap.reload
      }.to_not change {
        ap.instance_eval { [@data, @raw_data, @grpc, @errors] }
      }
    end

    it 'should reload data once if reload interval too short' do
      [ap.data, ap.raw_data, ap.grpc, ap.errors]
      expect(Xjz::ApiProject::Parser).to receive(:parse).and_return({})
      travel_to(Time.now + 5)

      expect {
        ap.reload
        ap.reload
        ap.reload
      }.to change {
        ap.instance_eval { [@data, @raw_data, @grpc, @errors].map(&:object_id) }
      }
    end

    it 'should reload data again if reload interval > default value' do
      [ap.data, ap.raw_data, ap.grpc, ap.errors]
      expect(Xjz::ApiProject::Parser).to receive(:parse).and_return({}).twice
      travel_to(Time.now + 5)

      expect {
        ap.reload
        travel_to(Time.now + 5)
        ap.reload
        ap.reload
      }.to change {
        ap.instance_eval { [@data, @raw_data, @grpc, @errors].map(&:object_id) }
      }
    end
  end
end
