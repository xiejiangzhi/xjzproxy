RSpec.describe Xjz::WebUI, server: true do
  let(:server) { $config.shared_data.app.server }
  let(:subject) { Xjz::WebUI.new(server) }

  describe '#start' do
    it 'should open window when websocket is ready', allow_local_http: true do
      ui_url = "http://127.0.0.1:#{server.ui_socket.local_address.ip_port}"
      expect_any_instance_of(Xjz::WebUI::Browser).to receive(:open).with(ui_url)
      # start once
      expect(subject.start).to eql(true)
      expect(subject.start).to eql(true)
      expect(subject.start).to eql(true)
    end

    it 'should return true if ui socket is return 200', log: false do
      ui_url = "http://127.0.0.1:#{server.ui_socket.local_address.ip_port}/status"
      stub_request(:get, ui_url).to_return(status: 200, body: "")
      expect_any_instance_of(Xjz::WebUI::Browser).to receive(:open)
      expect(subject.start).to eql(true)
    end

    it 'should return false if ui socket is failed to open', log: false do
      ui_url = "http://127.0.0.1:#{server.ui_socket.local_address.ip_port}/status"
      stub_request(:get, ui_url).to_return(status: 400, body: "err")
      expect_any_instance_of(Xjz::WebUI::Browser).to_not receive(:open)
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

  describe "#emit_message" do
    it 'should call page_manager#emit_message' do
      expect(subject.page_manager).to receive(:emit_message).with('server.a', 123)
      subject.emit_message('a', 123)
    end
  end
end
