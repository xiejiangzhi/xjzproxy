RSpec.describe Xjz::ApiProject do
  let(:file_path) { File.join($root, 'spec/files/project.yml') }
  let(:dir_path) { File.join($root, 'spec/files/project') }

  describe '#hack_req' do
    let(:ap) { Xjz::ApiProject.new(file_path) }

    fit 'should generate response for a valid req' do
      r = ap.hack_req(Xjz::Request.new(
        'HTTP_HOST' => 'xjz.pw',
        'rack.url_scheme' => 'https',
        'PATH_INFO' => '/api/v4/users',
        'REQUEST_METHOD' => 'GET'
      ))
      expect(r).to be_a(Xjz::Response)
      expect(r.code).to eql(200)
      expect(r.h1_headers).to eql([["content-type", "application/json"], ["content-length", "1967"]])
      expect(JSON.parse(r.body)).to eql(
        {}
      )
    end
  end

  describe '#raw_data' do
    it 'should return raw_data when load a file' do
      ap = Xjz::ApiProject.new(file_path)
      data = YAML.load_file(file_path)
      expect(ap.raw_data).to eql(data)
    end

    it 'should return raw_data when load a dir' do
      ap = Xjz::ApiProject.new(dir_path)
      expect(ap.raw_data).to eql(YAML.load_file(file_path))
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
      expect(Xjz::ApiProject::Parser).to receive(:verify).with(ap.raw_data).and_return([t])
      expect(ap.errors).to eql([t])
    end
  end
end
