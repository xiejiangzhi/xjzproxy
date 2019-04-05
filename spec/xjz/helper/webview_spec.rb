RSpec.describe Xjz::Helper::Webview do
  let(:m) { described_class }

  describe 'render' do
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

    it 'should raise error when not found' do
      expect {
        m.render('not_found_xxasdf.html')
      }.to raise_error('Not found template not_found_xxasdf.html.(erb|slim)')
    end

    it 'should back to default template if we have a default template' do
      expect(m.render('test')).to eql('<p>This is a default test template</p>')
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
  end
end
