RSpec.describe Xjz::WebUI::Browser do
  describe '#open' do
    it 'should open app mode if system has Chrome' do
      expect(subject).to receive(:exec_cmd).with(
        "/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome"\
        " --app=http://localhost:1234/asdf --window-size=1290,800"
      ).and_return(true)
      expect(Launchy).to_not receive(:open)
      subject.open('http://localhost:1234/asdf')
    end

    it 'should open browser if not found Chrome' do
      url = "http://localhost:22344/index"
      expect(subject).to receive(:exec_cmd).with(
        "/Applications/Google\\ Chrome.app/Contents/MacOS/Google\\ Chrome"\
        " --app=#{url} --window-size=1290,800"
      ).and_return(false)
      expect(Launchy).to receive(:open).with(url)
      subject.open(url)
    end
  end
end
