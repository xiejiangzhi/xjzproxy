RSpec.describe Xjz::WebUI, server: true do
  let(:server) { $config.shared_data.app.server }
  let(:subject) { Xjz::WebUI.new(server) }

  describe '#start' do
    it 'should open window when websocket is ready' do
      ui_url = "http://127.0.0.1:#{server.ui_socket.local_address.ip_port}"
      expect_any_instance_of(Xjz::WebUI::Browser).to receive(:open).with(ui_url)
      # start once
      expect(subject.start).to eql(true)
      expect(subject.start).to eql(true)
      expect(subject.start).to eql(true)
    end

    it 'should return false if ui socket is failed to open', log: false do
      expect_any_instance_of(Xjz::WebUI::Browser).to_not receive(:open)
      allow(Socket).to receive(:tcp).and_raise('err')
      expect(subject.start).to eql(false)
    end
  end

  describe '#watch' do
    it 'should watch on_message event of websocket' do
      expect(subject.page_manager).to receive(:watch).with('ws')
      subject.watch('ws')
      expect(subject.websocket).to eql('ws')
    end
  end
end
