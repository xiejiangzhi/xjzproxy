RSpec.describe FakeIO do
  it 'should return real io for same args' do
    s, r, l = FakeIO.server_pair(:a)
    l << 'hello'
    expect(r.readpartial(5)).to eql('hello')
    s2, r2, l2 = FakeIO.server_pair(:a)
    expect(s2).to eql(s)
    expect(r2).to eql(r)
    expect(l2).to eql(l)

    r2 << 'world'
    expect(l.readpartial(5)).to eql('world')
  end

  it 'should new different and real io for default args' do
    s1, r1, l1 = FakeIO.server_pair
    s2, r2, l2 = FakeIO.server_pair
    expect(s2).to eql(s1)
    expect(r1.local_address.inspect).to eql(r2.local_address.inspect)
    expect(l1.remote_address.inspect).to eql(l2.remote_address.inspect)

    r1 << 'hello'
    r2 << 'world'
    r1 << '123'
    expect(l2.readpartial(10)).to eql('world')
    expect(l1.readpartial(10)).to eql('hello123')

    ns, _, _ = FakeIO.server_pair(:c, :ss)
    expect(ns).to_not eql(s1)
    expect(ns.local_address.inspect).to_not eql(s1.local_address.inspect)
  end

  it 'should hack msg read/write' do
    r1, l1 = FakeIO.pair(:a)
    r2, l2 = FakeIO.pair(:b)
    l1.reply_data = proc { |msg, io| io << "<#{msg}" }
    l2.reply_data = [['asdf', 1024], ['123', 0], ['end']]
    r1 << '123'
    r2 << '111'
    r2 << '222'
    r2 << '333'
    expect(r1.wdata).to eql(['123'])
    expect {
      r1.readpartial(1024)
    }.to change(r1, :rdata).from([]).to(['<123'])
    expect(l1.rdata).to eql(['123'])
    expect(l1.wdata).to eql(['<123'])

    expect(r2.wdata).to eql(['111', '222', '333'])
    expect(r2.readpartial(1024)).to eql('asdf123end')
    expect(l2.wdata).to eql(['asdf', '123', 'end'])
    expect(l2.rdata).to eql(['111', '', '222333'])
  end

  it 'should support ssl' do
    FakeIO.hijack_socket!(binding)
    r1, l1 = FakeIO.pair(:a)
    l1.reply_data = proc { |msg, io| io << "<- #{msg}" }

    rs = OpenSSL::SSL::SSLSocket.new(r1.to_io, Xjz::Resolver::SSL.ssl_ctx)
    ls = OpenSSL::SSL::SSLSocket.new(l1.to_io)
    Thread.new { rs.accept }
    Xjz::IOHelper.ssl_connect(ls)
    rs << 'hello'

    expect(r1.wdata).to eql(['hello'])
    expect(l1.rdata).to eql(['hello'])
    expect(l1.wdata).to eql(['<- hello'])
    expect(rs.readpartial(1024)).to eql('<- hello')
    expect(r1.rdata).to eql(['<- hello'])
  end
end
