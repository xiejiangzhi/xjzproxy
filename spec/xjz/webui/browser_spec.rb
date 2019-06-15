RSpec.describe Xjz::WebUI::Browser do
  describe '#open/close/join' do
    it 'should open/close app window' do
      expect(subject.app).to receive(:open).with('xxx')
      expect(subject.app).to receive(:join)
      expect(subject.app).to receive(:close)
      subject.open('xxx')
      subject.join
      subject.close
    end

    it 'should set debug flag', stub_config: true do
      $config['webview_debug'] = true
      title = "#{$app_name} - #{$app_version}"
      expect(subject.app.options).to eql(debug: true, title: title)
    end
  end
end
