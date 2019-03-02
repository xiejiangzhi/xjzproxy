RSpec.describe Xjz::IOHelper do
  describe '.nonblock_copy_stream' do
    let(:dst) { StringIO.new('') }

    it 'should copy stream and auto close' do
      rd, wr = IO.pipe
      wr << 'hello '
      expect(subject.nonblock_copy_stream(rd, dst)).to eql(true)
      expect(dst.closed_write?).to eql(false)
      dst.rewind
      expect(dst.read).to eql('hello ')

      wr << 'world'
      expect(subject.nonblock_copy_stream(rd, dst)).to eql(true)
      expect(dst.closed_write?).to eql(false)
      dst.rewind
      expect(dst.read).to eql('hello world')

      wr.close
      expect(subject.nonblock_copy_stream(rd, dst)).to eql(false)
      expect(dst.closed_write?).to eql(true)
      dst.rewind
      expect(dst.read).to eql('hello world')
    end

    it 'should not auto close if auto eof is false' do
      rd, wr = IO.pipe
      wr << 'hello '
      wr << ''
      wr << 'world'
      wr.close
      expect(subject.nonblock_copy_stream(rd, dst, auto_eof: false)).to eql(false)
      expect(dst.closed_write?).to eql(false)
      dst.rewind
      expect(dst.read).to eql('hello world')
    end
  end

  describe '.forward_stream' do
    it 'should forward stream by hash mapping' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      rw3 = StringIO.new

      w1 << 'some data'
      Thread.new do
        sleep 0.1
        w1 << ' more data'
        sleep 0.1
        w1 << ' end data'
        w1.close
      end

      expect(subject.forward_streams(r1 => w2, r2 => rw3)).to eql(true)
      expect(w2.closed?).to eql(true)
      expect(rw3.closed_write?).to eql(true)
      rw3.rewind
      expect(rw3.read).to eql('some data more data end data')
    end

    it 'should timeout when too long have no data' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      rw3 = StringIO.new
      w1 << 'a'

      expect(subject.forward_streams({ r1 => w2, r2 => rw3 }, timeout: 0.5)).to eql(false)
      expect(w2.closed?).to eql(false)
      expect(rw3.closed_write?).to eql(false)
      rw3.rewind
      expect(rw3.read).to eql('a')
    end
  end
end
