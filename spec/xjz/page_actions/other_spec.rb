RSpec.describe 'other', webpage: true do
  before :each do
    cdata = $config.data.deep_dup
    allow($config).to receive(:data).and_return(cdata)
  end

  describe 'other.open_buy_page' do
    it 'should open url' do
      expect(Kernel).to receive(:system).with("open https://xjz.pw").and_return(true)
      expect_runner.to_not receive(:send_msg)
      emit_msg('other.open_buy_page.click')
    end

    it 'should open url for linux' do
      expect(Gem::Platform.local).to receive(:os).and_return('linux')
      expect(Kernel).to receive(:system).with('which xdg-open').and_return(false)
      expect(Kernel).to receive(:system).with('which firefox').and_return(true)
      expect(Kernel).to receive(:system).with("firefox https://xjz.pw").and_return(true)
      expect_runner.to_not receive(:send_msg)
      emit_msg('other.open_buy_page.click')
    end

    it 'should send error msg if not found cmd to open url', log: false do
      expect(Gem::Platform.local).to receive(:os).and_return('linux')
      expect(Kernel).to receive(:system).with(/^which /).and_return(false).exactly(3).times
      expect_runner_send_msg([
        'alert',
        type: :error,
        message: "Failed to open #{$config['home_url']} . please copy it to browser to open"
      ], :original)
      emit_msg('other.open_buy_page.click')
    end
  end

  describe 'other.new_licese_path.change' do
    it 'should update license' do
      path = '/path/to/license.lcs'
      expect($config).to receive(:update_license).and_return(true)
      expect($config).to receive(:save)
      expect_runner_send_msg(
        ['alert', type: :success, message: "Successfully update license"], :original
      )
      expect_runner_send_msg(
        ['el.html', selector: '#f_other', html: kind_of(String)], :original
      )
      emit_msg('other.new_license_path.change', 'value' => path)
    end

    it 'should send error msg if failed to update' do
      path = '/path/to/license.lcs'
      expect($config).to receive(:update_license).and_return(false)
      expect($config).to_not receive(:save)
      expect_runner_send_msg([
        'alert',
        type: :error,
        message: "Failed to update license, " + \
          "Please make sure the file is a valid license and try again"
      ])
      emit_msg('other.new_license_path.change', 'value' => path)
    end
  end
end
