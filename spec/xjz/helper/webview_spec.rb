RSpec.describe Xjz::Helper::Webview do
  let(:m) { described_class }

  describe 'render' do
    it 'should render to string' do
      expect(m.render('index.html', 'a' => 12332111)).to eql(
        "<p>hello</p><div class=\"a\">test webview var 12332111</div>" +
          "<p>this is a sub template</p>"
      )
    end

    it 'should render without vars' do
      expect(m.render('index.html')).to eql(
        "<p>hello</p><div class=\"a\">test webview var </div><p>this is a sub template</p>"
      )
    end

    it 'should raise error when not found' do
      expect {
        m.render('not_found_xxasdf.html')
      }.to raise_error('Not found template not_found_xxasdf.html.slim')
    end

    it 'should back to default template if we have a default template' do
      expect(m.render('test')).to eql('<p>This is a default test template</p>')
    end
  end
end
