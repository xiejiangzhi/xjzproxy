RSpec.describe Xjz::Helper::Webview do
  let(:m) { described_class.new }

  describe '.render' do
    it 'should call instance#render' do
      expect_any_instance_of(Xjz::Helper::Webview).to receive(:render) \
        .with(123, 'asdf', 'fdswa')
      Xjz::Helper::Webview.render(123, 'asdf', 'fdswa')
    end
  end

  describe '#render' do
    it 'should render to string' do
      expect(m.render('index.html', 'a' => 12332111)).to eql(
        "<p>hello</p><div class=\"a\">test webview var 12332111</div>" +
          "<a>var 12332111</a><p>this is a sub template</p><p>999</p>"
      )
    end

    it 'should render without vars' do
      expect(m.render('index.html')).to eql(
        "<p>hello</p><div class=\"a\">test webview var </div>" +
          "<p>this is a sub template</p><p>999</p>"
      )
    end

    it 'should support block' do
      expect(m.render('block.html', &(proc { 123 }))).to eql('<div>123</div>')
    end

    it 'should read read from Xjz.get_res' do
      expect(XjzLoader).to receive(:get_res).and_call_original
      expect(m.render('block.html', &(proc { 123 }))).to eql('<div>123</div>')
    end

    it 'should raise error when not found' do
      tengines = Xjz::Helper::Webview::TEMPLATE_ENGINES
      expect {
        m.render('not_found_xxasdf.html')
      }.to raise_error(
        "Not found template not_found_xxasdf.html.(#{tengines.join('|')})"
      )
    end

    it 'should not raise error if myres include the template(for prod)' do
      path = 'src/webviews/not_found_xxasdf.html.erb'
      regexp = /^src\/webviews\/not_found_xxasdf.html.(erb|slim|scss)$/
      expect(XjzLoader).to receive(:has_res?).with(regexp).and_return(path)
      expect(XjzLoader).to receive(:get_res).with(path).and_return('xxx')
      expect {
        m.render('not_found_xxasdf.html')
      }.to_not raise_error
    end

    it 'should back to default template if we have a default template' do
      expect(m.render('test')).to eql('<p>This is a default test template</p>')
    end

    it 'should catch template error in non-test env', stub_app_env: true, log: false do
      $app_env = 'dev'
      expect(m.render('error')).to eql('Failed to render template')
    end

    it 'support erb template' do
      expect(m.render('a', 'val' => '123')).to eql(<<~TEXT)
        This is a erb template
        vars[val]: 123
        val: 123
        012
        0
        1
        2
      TEXT
    end

    it 'support erb template' do
      md = Module.new { def m_asdf; "m asdf string"; end }
      expect(m.render('need_helper_module', {}, [md])).to eql("m asdf string")
    end

    it 'should render with layout' do
      data = m.render(['webui/layout.html', 'webui/index.html'], 'a' => 12332111)
      expect(data).to eql(
        "<!DOCTYPE html><html><head><meta charset=\"utf-8\" />"\
        "<meta content=\"initial-scale=1.0,user-scalable=no,maximum-scale=1,width=device-width\""\
        " name=\"viewport\" /><title>test</title></head>"\
        "<body><a href='#123'>xxx</a>\n<b>a</b>\n\n<i>b</i></body></html>"
      )
    end
  end
end
