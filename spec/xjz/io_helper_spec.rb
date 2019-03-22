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

    it 'should not auto close if undefined close_write' do
      rd, wr = IO.pipe
      wr << 'hello '
      wr << ''
      wr << 'world'
      wr.close
      om = dst.method(:respond_to?)
      allow(dst).to receive(:respond_to?) { |n| n.to_s == 'close_write' ? false : om.call(n) }
      expect(subject.nonblock_copy_stream(rd, dst)).to eql(false)
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

    it 'should stop if stop_wait_cb return true' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      rw3 = StringIO.new
      w1 << 'a'
      Thread.new { sleep 0.1; w1 << 'b'; sleep 0.5; w1 << 'c' }

      expect(subject.forward_streams(
        { r1 => w2, r2 => rw3 },
        stop_wait_cb: proc { |st| Time.now - st > 0.2 }
      )).to eql(false)
      expect(w2.closed?).to eql(false)
      expect(rw3.closed_write?).to eql(false)
      rw3.rewind
      expect(rw3.read).to eql('ab')
    end

    it 'should forward stream and not wait' do
      r1, w1 = IO.pipe
      r2, w2 = IO.pipe
      rw3 = StringIO.new
      w1 << 'some data' << ' 1' << ' 2'
      w1.close

      t = Time.now
      expect(subject.forward_streams(r1 => w2, r2 => rw3)).to eql(true)
      expect(Time.now - t).to be < 0.01
      expect(w2.closed?).to eql(true)
      expect(rw3.closed_write?).to eql(true)
      rw3.rewind
      expect(rw3.read).to eql('some data 1 2')
    end
  end
end
