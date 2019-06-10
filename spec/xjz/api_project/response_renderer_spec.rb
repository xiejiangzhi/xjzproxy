RSpec.describe Xjz::ApiProject::ResponseRenderer do
  let(:ap) { $config['.api_projects'].first }
  let(:subject) { described_class.new(ap) }
  let(:req) { Xjz::Request.new('HTTP_CONTENT_TYPE' => 'text/plain') }

  describe '.render' do
    describe 'without content-type' do
      it 'should return a response for a string' do
        r = subject.render(req, {
          http_code: 201,
          desc: 'asdf',
          data: 'hello'
        }.stringify_keys)
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(201)
        expect(r.body).to eql('hello')
        expect(r.h1_headers).to eql([['content-type', 'text/plain; charset=utf-8'], ['content-length', '5']])
      end

      it 'should return a response for a hash' do
        default_types = Xjz::ApiProject::DataType.default_types
        allow(default_types['integer']).to receive(:generate).and_return(123)
        allow(default_types['name']).to receive(:generate).and_return('name')
        r = subject.render(req, {
          http_code: 201,
          desc: 'asdf',
          data: {
            id: default_types['integer'],
            name: default_types['name'],
            other: 123,
            '.other' => 'desc'
          }
        }.deep_stringify_keys)
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(201)
        expect(r.body).to eql("{\"id\":123,\"name\":\"name\",\"other\":123}")
        expect(r.h1_headers).to eql([['content-type', 'application/json; charset=utf-8'], ['content-length', '36']])
      end

      it 'should return a json response for a hash if accpet type is text' do
        default_types = Xjz::ApiProject::DataType.default_types
        allow(default_types['integer']).to receive(:generate).and_return(123)
        allow(default_types['name']).to receive(:generate).and_return('name')
        req.env['HTTP_ACCEPT'] = 'text/html'
        r = subject.render(req, {
          http_code: 201,
          desc: 'asdf',
          data: {
            id: default_types['integer'],
            name: default_types['name'],
            other: 123,
            '.other' => 'desc'
          }
        }.deep_stringify_keys)
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(201)
        expect(r.body).to eql("{\"id\":123,\"name\":\"name\",\"other\":123}")
        expect(r.h1_headers).to eql([['content-type', 'text/html; charset=utf-8'], ['content-length', '36']])
      end

      it 'should return a response for a array' do
        default_types = Xjz::ApiProject::DataType.default_types
        allow(default_types['integer']).to receive(:generate).and_return(123)
        allow(default_types['name']).to receive(:generate).and_return('name')
        r = subject.render(req, {
          http_code: 201,
          desc: 'asdf',
          data: [default_types['integer'], default_types['name'], 123]
        }.deep_stringify_keys)
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(201)
        expect(r.body).to eql("[123,\"name\",123]")
        expect(r.h1_headers).to eql([['content-type', 'application/json; charset=utf-8'], ['content-length', '16']])
      end

      it 'should return a response for grpc request' do
        ap = Xjz::ApiProject.new(File.join($root, 'spec/files/grpc.yml'))
        subject = described_class.new(ap)
        default_types = Xjz::ApiProject::DataType.default_types
        allow(default_types['integer']).to receive(:generate).and_return(123)
        allow(default_types['string']).to receive(:generate).and_return('str')
        req = Xjz::Request.new(
          'HTTP_CONTENT_TYPE' => 'application/grpc',
          'PATH_INFO' => '/Hw.Greeter/SayName'
        )

        # a gRPC request, and we didn't define mock data
        r = subject.render(req, ap.grpc.res_desc(req.path))
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(200)
        data = ap.grpc.find_rpc(req.path).output.decode(r.body[5..-1]).to_hash
        type = data.delete(:type)
        expect(%i{VIP NORMAL}).to be_include(type)
        expect(data).to eql(
          message: 'str',
          info: { age: 123 },
          keywords: ['str'],
          aa: '',
          bb: 'str'
        )
        expect(r.h1_headers).to eql([
          ["content-type", "application/grpc; charset=utf-8"],
          ["content-length", (type == :NORMAL) ? '24' : "26"]
        ])
      end
    end

    describe 'with content-type' do
      it 'should return a response for a string' do
        r = subject.render(req, {
          http_code: 201,
          headers: { content_type: 'application/json' },
          desc: 'asdf',
          data: 'hello'
        }.deep_stringify_keys)
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(201)
        expect(r.body).to eql('"hello"')
        expect(r.h1_headers).to eql([
          ['content-type', 'application/json; charset=utf-8'], ['content-length', '7']
        ])
      end

      it 'should return a response for a hash' do
        default_types = Xjz::ApiProject::DataType.default_types
        allow(default_types['integer']).to receive(:generate).and_return(123)
        allow(default_types['name']).to receive(:generate).and_return('name')
        r = subject.render(req, {
          http_code: 201,
          desc: 'asdf',
          headers: { 'content-type' => 'application/xml; charset=utf-8' },
          data: {
            id: default_types['integer'],
            name: default_types['name'],
            other: 123
          }
        }.deep_stringify_keys)
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(201)
        expect(r.body).to eql(<<~XML
          <?xml version="1.0" encoding="UTF-8"?>
          <hash>
            <id type="integer">123</id>
            <name>name</name>
            <other type="integer">123</other>
          </hash>
        XML
        )
        expect(r.h1_headers).to eql([
          ['content-type', 'application/xml; charset=utf-8'], ['content-length', '140']
        ])
      end

      it 'should return a response for a array' do
        default_types = Xjz::ApiProject::DataType.default_types
        allow(default_types['integer']).to receive(:generate).and_return(123)
        allow(default_types['name']).to receive(:generate).and_return('name')
        r = subject.render(req, {
          http_code: 201,
          headers: { 'content-type' => 'text/csv' },
          desc: 'asdf',
          data: [[default_types['integer'], default_types['name'], 123], [1, 2, 3]]
        }.deep_stringify_keys)
        expect(r).to be_a(Xjz::Response)
        expect(r.code).to eql(201)
        expect(r.body).to eql("123,name,123\n1,2,3\n")
        expect(r.h1_headers).to eql([['content-type', 'text/csv; charset=utf-8'], ['content-length', '19']])
      end
    end
  end
end
