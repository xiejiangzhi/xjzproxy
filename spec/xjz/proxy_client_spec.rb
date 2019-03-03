RSpec.describe Xjz::ProxyClient do
  it 'should create client for http1' do
    c = Xjz::ProxyClient.new protocol: 'http1'
    expect(c.client).to be_a(Xjz::ProxyClient::HTTP1)
    expect(c.client).to receive(:send_req).with('asdf')
    c.send_req('asdf')
  end

  it 'should create client for http2' do
    c = Xjz::ProxyClient.new protocol: 'http2'
    expect(c.client).to be_a(Xjz::ProxyClient::HTTP2)
    expect(c.client).to receive(:send_req).with('aaa')
    c.send_req('aaa')
  end
end
