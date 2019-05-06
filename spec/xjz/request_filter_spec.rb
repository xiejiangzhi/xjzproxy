RSpec.describe Xjz::RequestFilter do
  describe 'filter' do
    let(:subject) do
      Xjz::RequestFilter.new('xjz api/v1 status>=200 status<=300 method=Post type~text')
    end

    def fargs(http_method, host, path, status, type = 'text/plain')
      {
        req: double('req', host: host, path: path, http_method: http_method, content_type: type),
        res: double('res', code: status, content_type: type)
      }
    end

    it 'should return true if match' do
      expect(subject.valid?(fargs('post', 'xjz.pw', '/api/v1/users', 200))).to eql(true)
      expect(subject.valid?(fargs('post', 'xjz.pw', '/api/v1/users', 299))).to eql(true)
      expect(subject.valid?(fargs('post', 'www.xjz.pw', '/api/v1/users', 299))).to eql(true)
    end

    it 'should return false if not match' do
      expect(subject.valid?(fargs('post', 'x-jz.pw', '/api/v1/users', 200))).to eql(false)
      expect(subject.valid?(fargs('post', 'xjz.pw', '/api/v1/users', 399))).to eql(false)
      expect(subject.valid?(fargs('post', 'xjz.pw', '/api/v2/users', 299))).to eql(false)
      expect(subject.valid?(fargs('get', 'xjz.pw', '/api/v1/users', 200))).to eql(false)
    end

    it 'other cases' do
      subject = Xjz::RequestFilter.new(nil)
      expect(subject.valid?(fargs('get', 'xjz.pw', '/api/v1/users', 200))).to eql(true)

      subject = Xjz::RequestFilter.new('method!=post')
      expect(subject.valid?(fargs('get', 'xjz.pw', '/api/v1/users', 200))).to eql(true)

      subject = Xjz::RequestFilter.new('method!=get')
      expect(subject.valid?(fargs('get', 'xjz.pw', '/api/v1/users', 200))).to eql(false)

      subject = Xjz::RequestFilter.new('method=ge')
      expect(subject.valid?(fargs('get', 'xjz.pw', '/api/v1/users', 200))).to eql(false)

      subject = Xjz::RequestFilter.new('method~^ge')
      expect(subject.valid?(fargs('get', 'xjz.pw', '/api/v1/users', 200))).to eql(true)

      subject = Xjz::RequestFilter.new('method!~po')
      expect(subject.valid?(fargs('get', 'xjz.pw', '/api/v1/users', 200))).to eql(true)

      subject = Xjz::RequestFilter.new('status>0')
      req = double(
        'req',
        http_method: 'get', host: 'xjz.pw',
        path: '/api/v1/users', content_type: 'text/plain'
      )
      expect(subject.valid?(req: req)).to eql(false)
    end

    it 'should check all type if opt is !~' do
      args = fargs('get', 'xjz.pw', '/api/v1/users', 200)
      allow(args[:req]).to receive(:content_type).and_return('image/png')

      subject = Xjz::RequestFilter.new('type!~image')
      expect(subject.valid?(args)).to eql(false)

      subject = Xjz::RequestFilter.new('type~image')
      expect(subject.valid?(args)).to eql(true)
    end
  end
end
