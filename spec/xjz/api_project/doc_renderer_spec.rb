RSpec.describe Xjz::ApiProject::DocRenderer do
  let(:ap) { $config['.api_projects'].first }

  describe '#render' do
    let(:subject) { described_class.new(ap) }

    it 'should render with ap data' do
      str = subject.render
      expect(str).to be_match(/\AXJZapi Document/)
      expect(str['Request']).to_not be_nil
    end
  end

  describe Xjz::ApiProject::DocRenderer::DocViewHelper do
    let(:subject) do
      Xjz::Helper::Webview::ViewEntity.new(
        { project: ap },
        [Xjz::ApiProject::DocRenderer::DocViewHelper]
      ).tap { |o| o._setup_vars! }
    end

    it '#format_data should return formated data' do
      expect(subject.format_data(
        'a' => 123,
        '.a.desc' => 'some desc',
        '.a.required' => true,
        '.a.xxx' => 'yyy',
        'b' => '.t/integer',
        '.b.desc' => 'bdd'
      )).to eql(
        "a" => {
          "desc" => "some desc",
          "required" => true,
          "val" => 123,
          "xxx" => "yyy"
        },
        "b" => {
          "desc" => "bdd",
          "type" => ".t/integer"
        }
      )
    end

    it '#format_data should deep format data' do
      expect(subject.format_data(
        'a' => 123,
        '.a.xxx' => 'yyy',
        'b' => {
          'a' => 'ba',
          '.a.desc' => 'xxx',
          'b' => {
            'a' => '.t/integer * 10'
          },
          '.b.desc' => 'xxx'
        },
        '.b.desc' => 'bdd',
        'c' => [['a', 'b', { 'a' => 1 }]]
      )).to eql(
        "a" => { "val" => 123, "xxx" => "yyy" },
        "b" => { "desc" => "bdd", "type" => "hash" },
        "b[\"a\"]" => { "desc" => "xxx", "val" => "ba" },
        "b[\"b\"]" => { "desc" => "xxx", "type" => "hash" },
        "b[\"b\"][\"a\"]" => {
          "type" => ".t/integer", 'type_oper' => '*', 'type_args' => ['10']
        },
        "c" => { "type" => "array" },
        "c[\"0\"]" => { "type" => "array" },
        "c[\"0\"][\"0\"]" => { "val" => "a" },
        "c[\"0\"][\"1\"]" => { "val" => "b" },
        "c[\"0\"][\"2\"]" => { "type" => "hash" },
        "c[\"0\"][\"2\"][\"a\"]" => { "val" => 1 },
      )
    end

    it '#render_data should render json data of current project for responses' do
      expect(subject.render_project_data('responses', 'invalid_token')).to eql(<<~JSON.strip)
        {
          "code": 1,
          "msg": "Invalid token"
        }
      JSON
    end

    it '#render_data should render json data of current project for partials' do
      types = ap.data['types']
      allow(types['integer']).to receive(:generate).and_return(123)
      allow(types['string']).to receive(:generate).and_return('ssstring')
      allow(types['avatar']).to receive(:generate).and_return('https://xxx.com/path/to/1.png')

      expect(subject.render_project_data('partials', 'simple_user')).to eql(<<~JSON.strip)
        {
          "id": 123,
          "nickname": "ssstring",
          "avatar": "https://xxx.com/path/to/1.png"
        }
      JSON
    end

    it '#render_data should render json data of current project for apis' do
      types = ap.data['types']
      allow(types['integer']).to receive(:generate).and_return(123)
      allow(types['string']).to receive(:generate).and_return('ssstring')
      allow(types['avatar']).to receive(:generate).and_return('https://xxx.com/path/to/1.png')
      allow(types['text']).to receive(:generate).and_return('some text')

      expect(subject.render_project_data(
        'apis', [ap.data['apis'].keys[1], 'GET', "/api/v1/users/\\d+", 'success']
      )).to eql(<<~JSON.strip)
        {
          "id": 123,
          "nickname": "ssstring",
          "avatar": "https://xxx.com/path/to/1.png",
          "posts": [
            {
              "id": 123,
              "title": "a post title",
              "body": "some text"
            },
            {
              "id": 123,
              "title": "a post title",
              "body": "some text"
            },
            {
              "id": 123,
              "title": "a post title",
              "body": "some text"
            }
          ]
        }
      JSON
    end
  end
end
