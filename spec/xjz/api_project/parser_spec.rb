RSpec.describe Xjz::ApiProject::Parser do
  let(:file_path) { File.join($root, 'spec/files/project.yml') }
  let(:raw_data) { Xjz::ApiProject.new(file_path).raw_data }

  describe 'parse' do
    it 'should convert to DataTypes' do
      r = subject.parse(raw_data)['types']
      r.each { |name, dt| expect(dt).to be_a(Xjz::ApiProject::DataType) }
      expect(r.object_id).to_not eql(Xjz::ApiProject::DataType.default_types.object_id)
      expect(r['status'].raw_data).to eql(raw_data['types']['status'])
      expect(r['avatar'].raw_data).to eql(raw_data['types']['avatar'])
    end

    it 'should expand partials' do
      r = subject.parse(raw_data)
      partials = r['partials']
      types = r['types']
      expect(partials['simple_user']).to eql(
        "id" => types['integer'],
        "avatar" => types['avatar'],
        "nickname" => types['string'],
      )
      expect(partials['user']).to eql(
        ".posts" => { "desc" => "a list of post" },
        "avatar" => types['avatar'],
        "id" => types['integer'],
        "nickname" => types['string'],
        "posts" => [{
          "body" => types['text'],
          "id" => types['integer'],
          "title" => "a post title"
        }] * 3
      )
      expect(partials['post']).to eql(
        'id' => types['integer'],
        'body' => types['text'],
        'title' => 'a post title'
      )
    end

    it 'should expand responses' do
      r = subject.parse(raw_data)
      responses = r['responses']
      pts = r['partials']
      types = r['types']

      expect(responses).to eql(
        "invalid_token" => {
          "http_code" => 400,
          "desc" => "xxx",
          "data" => { "code" => 1, "msg" => "Invalid token" }
        },
        "show_user" => {
          "http_code" => 200,
          "desc" => "xxx",
          "data" => pts['user']
        },
        "show_post" => {
          "http_code" => 200,
          "desc" => "hello",
          "data" => {
            "id" => types['integer'],
            "user" => pts['user'],
            "status" => types['status']
          }
        },
        "list_users" => {
          "http_code" => 200,
          "data" => {
            "items" => [pts['user']] * 2,
            ".items" => { "desc" => "a array of user" },
            "total" => types['integer'],
            ".total" => { "desc" => "val" }
          }
        }
      )
    end

    it 'should copy project data' do
      expect(subject.parse(raw_data)['project']).to eql(
        'host' => 'xjz\.pw',
        '.host_regexp' => /\Axjz\.pw\Z/,
        'desc' => 'desc',
        ".dir" => File.join($root, "spec/files"),
      )
    end

    it 'should generate ruby proto and load them' do
      raw_data = Xjz::ApiProject.new(File.join($root, 'spec/files/grpc.yml')).raw_data
      gm = subject.parse(raw_data)['project']['.grpc_module']
      expect(gm).to be_a(Module)
      expect(gm.pb_pool).to be_a(Google::Protobuf::DescriptorPool)
      expect(gm::Hw::Ms::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Ms::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw::Greeter::Service.included_modules).to be_include(GRPC::GenericService)
      expect(gm::Hw2::Reply.included_modules).to be_include(Google::Protobuf::MessageExts)
      expect(gm::Hw2::Request.included_modules).to be_include(Google::Protobuf::MessageExts)
    end

    it 'should parse plugins' do
      r = subject.parse(raw_data)
      types = r['types']
      expect(r['plugins']).to eql([
        {
          "title" => "auth token",
          "labels" => ["auth", "l1"],
          "template" => { "params" => { "token" => types['string'] } },
          ".index" => 0
        },
        { "title" => "script", "labels" => ["l1"], "script" => "\nputs 'hello'\n", ".index" => 1 },
        {
          "title" => "l1 plug",
          "labels" => ["l1", "l2"],
          "template" => {
            "response" => {
              "err" => { "http_code" => 400, "data" => { "code" => 1, "msg" => "err" } }
            }
          },
          ".index" => 2
        }
      ])

      expect(r['.label_indexed_plugins']).to eql(
        'auth' => [r['plugins'][0]],
        'l1' => r['plugins'],
        'l2' => [r['plugins'][2]]
      )
    end

    it 'should parse apis' do
      r = subject.parse(raw_data)
      expect(r['apis']).to eql([
        {
          "title" => "Get all users",
          "desc" => "more desc of this API",
          "method" => "GET",
          "path" => "/api/v1/users",
          ".path_regexp" => %r{\A/api/v1/users(\.\w+)?\Z},
          "labels" => ['auth'],
          "query" => {
            "page" => 1,
            ".page" => { 'optional' => true },
            "q" => 123,
            "status" => r['types']['integer'],
            ".status" => { "optional" => { "unless" => "q" }, "rejected" => { "if" => "q" } }
          },
          "params" => { 'token' => r['types']['string'] },
          '.index' => 0,
          "response" => {
            "success" => r['responses']['list_users'],
            'r2' => {
              http_code: 200,
              data: {
                items: [r['partials']['user']] * 2,
                total: r['types']['integer']
              }
            }.deep_stringify_keys,
            'r3' => {
               data: {
                items: [r['partials']['user']] * 2,
                '.items' => { 'desc' => 'some desc' },
                total: r['types']['integer'],
                '.total' => { 'desc' => 'some desc' }
              }
            }.deep_stringify_keys,
            "error" => r['responses']['invalid_token']
          }
        },
        {
          "title" => "Get user",
          "desc" => "show a user's info",
          'enabled' => true,
          "method" => "GET",
          "path" => '/api/v1/users/\d+',
          ".path_regexp" => %r{\A/api/v1/users/\d+(\.\w+)?\Z},
          "labels" => ['auth', 'l1'],
          "params" => { 'token' => r['types']['string'] },
          "query" => nil,
          '.index' => 1,
          "response" => {
            "success" => r['responses']['show_user'],
            "error" => r['responses']['invalid_token'],
            "err" => {
              "http_code" => 400,
              "data" => { "code" => 1, "msg" => "err" }
            }
          }
        }
      ])
    end

    it 'should skip if data is nil' do
      r = subject.parse({})
      expect(r).to eql(
        'apis' => {},
        "partials" => {},
        "plugins" => {},
        "project" => {},
        "responses" => {},
        "types" => Xjz::ApiProject::DataType.default_types
      )
    end

    describe 'edition' do
      it 'should parse over 10 apis' do
        r = subject.parse({
          project: { host: 'xjz\.pw' },
          apis: 12.times.map do |i|
            {
              method: 'get',
              path: "/path/#{i}",
              response: { success: 'hello' }
            }
          end
        }.deep_stringify_keys)

        expect(r['apis'].map { |r| r['path'] }).to eql(12.times.map { |i| "/path/#{i}" })
      end

      it 'should parse 10 apis for trial edition' do
        allow($config).to receive(:data).and_return($config.data.dup)
        $config['.edition'] = nil

        r = subject.parse({
          project: { host: 'xjz\.pw' },
          apis: 12.times.map do |i|
            {
              method: 'get',
              path: "/path/#{i}",
              response: { success: 'hello' }
            }
          end
        }.deep_stringify_keys)

        expect(r['apis'].map { |r| r['path'] }).to eql(10.times.map { |i| "/path/#{i}" })
      end
    end
  end
end
