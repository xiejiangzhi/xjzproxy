RSpec.describe Xjz::WriterIO do
  let(:like_io) { double('like io', '<<' => true) }
  let(:io) { Xjz::WriterIO.new like_io }

  it 'should allow IO.select & write' do
    expect(like_io).to receive('<<').with('hello').ordered
    expect(like_io).to receive('<<').with(' world').ordered
    expect(like_io).to receive('<<').with(' end').ordered
    _, ws = IO.select(nil, [io])
    ws[0].write_nonblock 'hello'
    ws[0].write ' world'
    ws[0] << ' end'
  end

  it 'should allow flush & close' do
    io.write 'hello'
    io.flush
    expect(io.closed_write?).to eql(false)
    expect(io.closed?).to eql(false)
    io.close_write
    expect(io.closed_write?).to eql(true)
    expect(io.closed?).to eql(true)
    expect { io.write 'hello' }.to raise_error(IOError, 'closed stream')
  end
end
