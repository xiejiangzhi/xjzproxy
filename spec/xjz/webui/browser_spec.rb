RSpec.describe Xjz::WebUI::Browser do
  describe '#open/close' do
    it 'should open app window by webview' do
      expect(subject).to receive(:exec_cmd).with(
        "/Users/xiejiangzhi/Code/xjzproxy/lib/webview/webview"\
        " -url http://localhost:1234/asdf -debug"
      ).and_call_original
      expect(subject.open('http://localhost:1234/asdf')).to eql(true)
      sleep 1
      ap = subject.app_process
      expect(ap.alive?).to eql(true)
      expect {
        subject.close
      }.to change { ap.alive? }.to(false)
      expect(subject.app_process).to eql(nil)
    end
  end
end
