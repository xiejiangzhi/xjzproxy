RSpec.describe Xjz::RequestFilter do
  describe 'filter' do
    let(:subject) { Xjz::RequestFilter.new('xjz api/v1 status>=200 status<=300 method=Post') }

    it 'should return true if match' do
      expect(
        subject.valid?(host: 'xjz.pw', path: '/api/v1/users', status: 200, http_method: 'post')
      ).to eql(true)
      expect(
        subject.valid?(host: 'xjz.pw', path: '/api/v1/users', status: '299', http_method: 'post')
      ).to eql(true)
      expect(
        subject.valid?(host: 'www.xjz.pw', path: '/api/v1/users', status: '299', http_method: 'post')
      ).to eql(true)
    end

    it 'should return false if not match' do
      expect(
        subject.valid?(host: 'x-jz.pw', path: '/api/v1/users', status: 200, http_method: 'post')
      ).to eql(false)
      expect(
        subject.valid?(host: 'xjz.pw', path: '/api/v1/users', status: '399', http_method: 'post')
      ).to eql(false)
      expect(
        subject.valid?(host: 'xjz.pw', path: '/api/v2/users', status: '299', http_method: 'post')
      ).to eql(false)
      expect(
        subject.valid?(host: 'xjz.pw', path: '/api/v1/users', status: 200, http_method: 'get')
      ).to eql(false)
    end

    it 'should return true if filter is empty' do
      subject = Xjz::RequestFilter.new(nil)
      expect(
        subject.valid?(host: 'xjz.pw', path: '/api/v1/users', status: 200, http_method: 'get')
      ).to eql(true)
    end
  end
end
