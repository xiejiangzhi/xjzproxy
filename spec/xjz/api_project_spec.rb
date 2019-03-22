RSpec.describe Xjz::ApiProject do
  let(:file_path) { File.join($root, 'spec/files/project.yml') }
  let(:dir_path) { File.join($root, 'spec/files/project') }

  describe '#hack_req' do
    let(:ap) { Xjz::ApiProject.new(file_path) }

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
      expect(Xjz::ApiProject::Parser).to receive(:verify) \
        .with(ap.raw_data, file_path).and_return([t])
      expect(ap.errors).to eql([t])
    end
  end
end
