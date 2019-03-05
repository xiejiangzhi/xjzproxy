RSpec.describe Xjz::HTTPHelper do
  describe 'get_header' do
    let(:headers) { [[':method', 'a'], ['hehe', 123]] }

    it 'should get return header' do
      expect(Xjz::HTTPHelper.get_header(headers, ':method')).to eql('a')
      expect(Xjz::HTTPHelper.get_header(headers, 'hehe')).to eql(123)
      expect(Xjz::HTTPHelper.get_header(headers, :hehe)).to eql(123)
      expect(Xjz::HTTPHelper.get_header(headers, :adsf)).to eql(nil)
    end
  end

  describe 'get_header' do
    let(:headers) { [[':method', 'a'], ['hehe', 123]] }

    it 'should update headers' do
      Xjz::HTTPHelper.set_header(headers, ':method', 'GET')
      expect(headers).to eql([[':method', 'GET'], ['hehe', 123]])

      Xjz::HTTPHelper.set_header(headers, 'hehe', '321')
      expect(headers).to eql([[':method', 'GET'], ['hehe', '321']])

      Xjz::HTTPHelper.set_header(headers, 'asdf', 'aaa')
      expect(headers).to eql([[':method', 'GET'], ['hehe', '321'], ['asdf', 'aaa']])

      Xjz::HTTPHelper.set_header(headers, ':status', '200')
      expect(headers).to eql([[':status', '200'], [':method', 'GET'], ['hehe', '321'], ['asdf', 'aaa']])
    end
  end
end
