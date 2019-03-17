RSpec.describe Xjz::ApiProject::Parser do
  let(:file_path) { File.join($root, 'spec/files/project.yml') }
  let(:raw_data) { YAML.load_file(file_path) }

  before :each do
    raw_data['project']['dir'] = File.expand_path('../', file_path)
  end

  describe 'verify' do
    it 'should return nil if has no error' do
      expect(subject.verify(raw_data)).to eql(nil)
    end

    it 'should return nil if has undefined keys' do
      d = raw_data.deep_dup
      d['asdf'] = 'lkajsdf'
      d['types']['avatar']['lkjalksdf'] = 123
      d['apis'][0]['lkjalksdf'] = 123
      d['project']['asdf'] = '12313'
      d['responses']['show_user']['asdf'] = '12313'
      d['plugins']['auth']['asdf'] = '12313'
      expect(subject.verify(raw_data)).to eql(nil)
    end

    it 'should return errors if has some bad format' do
      d = raw_data.deep_dup
      d['types']['xxx'] = { 'items' => 1 }
      d['partials']['xxx'] = 123
      d['apis'] << { a: 1 }
      d['responses']['123'] = { b: 2 }
      d['plugins']['xxx'] = { b: 2 }
      expect(subject.verify(d)).to eql([

        { full_path: "Hash[\"responses\"][\"123\"][\"http_code\"]", message: "present" },
        { full_path: "Hash[\"responses\"][\"123\"][\"data\"]", message: "present" },
        { full_path: "Hash[\"plugins\"][\"xxx\"][\"filter\"]", message: "present" },
        { full_path: "Hash[\"types\"][\"xxx\"][\"items\"]", message: "a/an NilClass" },
        { full_path: "Hash[\"types\"][\"xxx\"][\"items\"]", message: "a/an Array" },
        {
          full_path: "Hash[\"types\"][\"xxx\"][\"items\"]",
          message: "one of absent (marked as :optional), a/an NilClass, a/an Array"
        },
        { full_path: "Hash[\"apis\"][2][\"title\"]", message: "present" },
        { full_path: "Hash[\"apis\"][2][\"method\"]", message: "present" },
        { full_path: "Hash[\"apis\"][2][\"path\"]", message: "present" },
        { full_path: "Hash[\"apis\"][2][\"response\"]", message: "present" }
      ])
    end
  end

  describe 'parse' do
    it 'should convert to DataTypes' do
      r = subject.parse(raw_data)['types']
      r.each { |name, dt| expect(dt).to be_a(Xjz::ApiProject::DataType) }
      expect(r['status'].raw_data).to eql(raw_data['types']['status'])
      expect(r['avatar'].raw_data).to eql(raw_data['types']['avatar'])
    end

    it 'should expand partials' do
      r = subject.parse(raw_data)
      partials = r['partials']
      types = r['types']
      expect(partials['user']).to eql(
        "./posts.desc" => "a list of post",
        "avatar" => types['avatar'],
        "id" => types['integer'],
        "nickname" => types['string'],
        "posts" => [{
          "body" => types['text'],
          "id" => types['integer'],
          "title" => "a post title"
        }] * 3)
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
            "items" => [pts['user']] * 4,
            "./items.desc" => "a array of user",
            "total" => types['integer'],
            "./total.desc" => "val"
          }
        }
      )
    end

    it 'should copy project data' do
      expect(subject.parse(raw_data)['project']).to eql(
        'url' => 'https://xjz.pw',
        'desc' => 'desc',
        "dir" => "/Users/xiejiangzhi/Code/xjzproxy/spec/files"
      )
    end

    it 'should parse plugins' do
      r = subject.parse(raw_data)
      expect(r['plugins']).to eql(
        "auth" => {
          "body" => nil,
          "filter" => {
            "exclude_labels" => ['no_auth'],
            "include_labels" => ['all'],
            "methods" => ['GET', 'POST'],
            "path" => "/api/v1"
          },
          "headers" => nil,
          "params" => {
            "./token.required" => true,
            "token" => r['types']['string']
          },
          "query" => nil
        },
        "other" => {
          "filter" => { "include_labels" => ['all'], "path" => "/api/v1" },
          "script" => "\nputs 'hello'\n"
        }
      )
    end

    it 'should parse apis' do
      r = subject.parse(raw_data)
      expect(r['apis']).to eql(
        "GET https://xjz.pw/api/v1/users" => {
          "title" => "Get all users",
          "desc" => "more desc of this API",
          "method" => "GET",
          "path" => "/api/v1/users",
          "labels" => ['auth'],
          "query" => {
            "page" => 1,
            "./page.required" => true,
            "q" => 123,
            "status" => "$t/integer",
            "./status.required" => { "unless" => "q" },
            "./status.rejected" => { "if" => "q" }
          },
          "response" => {
            "success" => [
              r['responses']['list_users'],
              {
                http_code: 200,
                data: {
                  items: [r['partials']['user']] * 2,
                  total: r['types']['integer']
                }
              }.deep_stringify_keys,
              {
                data: {
                  items: [r['partials']['user']] * 2,
                  './items.desc' => 'some desc',
                  total: r['types']['integer'],
                  './total.desc' => 'some desc'
                }
              }.deep_stringify_keys
            ],
            "error" => [r['responses']['invalid_token']]
          }
        },
        "GET http://asdf.com/api/v1/users/:id" => {
          "title" => "Get user",
          "desc" => "show a user's info",
          "method" => "GET",
          "url" => 'http://asdf.com',
          "path" => "/api/v1/users/:id",
          "labels" => ['auth'],
          "query" => nil,
          "response" => {
            "success" => [r['responses']['show_user']],
            "error" => [r['responses']['invalid_token']]
          }
        }
      )
    end
  end
end
