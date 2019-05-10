RSpec.describe Xjz::WebUI::Browser do
  describe '#open/close' do
    it 'should open app window by webview' do
      expect(subject).to receive(:exec_cmd).with(
        File.join($root, 'ext/webview/webview') + " -url http://localhost:1234/asdf"
      ).and_call_original
      expect(subject.open('http://localhost:1234/asdf')).to eql(true)
      sleep 0.5
      ap = subject.app_process
      expect(ap.alive?).to eql(true)
      expect {
        subject.close
      }.to change { ap.alive? }.to(false)
      expect(subject.app_process).to eql(nil)
    end

    it 'should open app window with debug if debug is open' do
      data = $config.data.dup.merge!('webview_debug' => true)
      allow($config).to receive(:data).and_return(data)
      expect(subject).to receive(:exec_cmd).with(
        File.join($root, 'ext/webview/webview') + " -url http://localhost:4321/aaa -debug"
      ).and_call_original
      expect(subject.open('http://localhost:4321/aaa')).to eql(true)
      sleep 0.5
      ap = subject.app_process
      expect(ap.alive?).to eql(true)
      expect {
        subject.close
      }.to change { ap.alive? }.to(false)
      expect(subject.app_process).to eql(nil)
    end
  end
end
